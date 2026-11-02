# PRODUCTION GRADE AUDIT REPORT: STEMLY

**Date:** 2026-11-02  
**Target Architecture:** Production Grade  
**Components:** FastAPI Backend (`backend/`) & Flutter Mobile Client (`stemly_app/`)  
**Scope:** Architectural Integrity, Security Posture, Async Concurrency, Resilience, API Quality, Code Hygiene, Testing Coverage.

---

## 1. LLM & External API Call Matrix

| File & Function | Provider & Endpoint | Model | Timeout | Error Handling & Resilience | Critical Flaws / Technical Debt |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `backend/routers/chat.py`<br>`handle_unified_chat()` | **Ollama / Gemini Mismatch**<br>`f"{OLLAMA_BASE_URL}/api/generate"` | `gemini-2.5-flash` (`LOCAL_MODEL`) | 120s | Catches broad `Exception`, prints to stdout, returns generic error dict. | **Broken endpoint:** `OLLAMA_BASE_URL` in `config.py` is configured to `https://generativelanguage.googleapis.com/v1beta`. Calling `/api/generate` on Gemini produces immediate 404/500 errors. Synchronous `requests.post` blocks event loop. |
| `backend/services/ai_chat.py`<br>`process_visualiser_chat()` | **Google Gemini**<br>`generativelanguage.googleapis.com/.../generateContent` | `gemini-2.5-flash` (`GEMINI_MODEL`) | 60s | 3 retry attempts with exponential backoff (`2^attempt + 1`). Rotates to `GEMINI_FALLBACK_API_KEY` on 401/403/429. | Synchronous `requests.post` and `time.sleep` block the async worker. System prompt injected via raw string interpolation without injection sanitization. |
| `backend/services/ai_detector.py`<br>`_query_gemini_text()` | **Google Gemini**<br>`generativelanguage.googleapis.com/.../generateContent` | `gemini-2.5-flash` (`GEMINI_MODEL`) | 30s | `_gemini_request_with_retry` (3 retries, exponential backoff, key fallback). Falls back to regex keyword heuristic on failure. | Blocking synchronous HTTP calls inside async function. Regex fallback triggers easily on network hiccups, returning low-confidence classification. |
| `backend/services/ai_detector.py`<br>`_query_gemini_vision()` | **Google Gemini Vision**<br>`generativelanguage.googleapis.com/.../generateContent` | `gemini-2.5-flash` (`GEMINI_MODEL`) | 60s | Synchronously reads local image, base64 encodes it, attempts 3 retries with key fallback, defaults to regex fallback on failure. | Synchronous file read `open(image_path, "rb")` and `requests.post` block event loop. Uploaded images read entirely into memory. |
| `backend/services/ai_notes.py`<br>`_call_gemini_api_sync()` | **Google Gemini**<br>`generativelanguage.googleapis.com/.../generateContent` | `gemini-2.5-flash` (`GEMINI_MODEL`) | 120s (generation)<br>60s (follow-up) | Executed via `run_in_threadpool`. 3 retries on 429/401/403, key rotation. Returns empty fallback `NotesResponse` on failure. | Offloading sync `requests` to threadpool consumes OS worker threads rather than using native non-blocking `httpx.AsyncClient`. Causes thread pool starvation under load. |
| `backend/services/ai_quiz.py`<br>`generate_quiz_with_ai()` | **Google Gemini**<br>`generativelanguage.googleapis.com/.../generateContent` | `gemini-2.5-flash` (`GEMINI_MODEL`) | 60s | 2 retries (3 attempts), switches to fallback key on 400/401/403/429. Falls back to static dictionary (`SAMPLE_QUIZZES`). | Blocking `requests.post` and `time.sleep` in async function. 300+ lines of hardcoded fallback quiz questions bundled directly inside Python file. |
| `backend/services/ai_visualiser.py`<br>`adjust_parameters_with_ai()` | **Google Gemini**<br>`generativelanguage.googleapis.com/.../generateContent` | `gemini-2.5-flash` (`GEMINI_MODEL`) | 60s | 3 retries on 429 with exponential backoff. Returns empty updates dict on failure. | Blocking `requests.post` and `time.sleep` in async function. Does NOT support fallback API key rotation. |
| `backend/services/ai_visualiser.py`<br>`generate_visualiser_image()` | **AIML API**<br>`api.aimlapi.com/v1/images/generations/` | `flux/schnell` | 30s | Broad `try/except Exception` returning `None`. | Synchronous `requests.post`. No retries, no fallback provider, silent failure degrades user experience without actionable client error. |
| `backend/auth/firebase.py`<br>`verify_firebase_token()` | **Firebase Auth Admin SDK** | N/A | Default Google SDK timeout | Catches `FirebaseError` and `ValueError`. | Synchronous cryptographic signature verification and Google public key fetching executed in main thread during request dependency resolution. |
| `stemly_app/lib/services/groq_service.dart`<br>`sendMessage()` | **Direct Client-to-LLM**<br>(Grok, Gemini, OpenRouter, OpenAI, Groq) | Dynamic (`grok-beta`, `gemini-2.5-flash`, `gpt-4o-mini`, etc.) | 30s | Generic try/catch wrapping exceptions in string error messages. | **Architectural Violation:** Mobile app directly talks to external AI APIs bypassing backend. Leaks API architecture, requires API keys on device, bypasses server validation and rate limiting. |
| `stemly_app/lib/services/firebase_auth_service.dart` | **Firebase Auth SDK** (Google Identity) | N/A | Default platform timeout | Catches `FirebaseAuthException`. | ID token cached in secure storage but never refreshed proactively before expiration on long user sessions. |

---

## 2. API Key Storage & Handling Audit

### Backend
- **Environment Ingestion (`config.py` & `auth/firebase.py`):**
  - Read via `os.getenv`: `GOOGLE_API_KEY`, `GEMINI_API_KEY`, `GEMINI_FALLBACK_API_KEY`, `AIML_API_KEY`, `OPENROUTER_API_KEY`, `OPENROUTER_API_KEY_LEGACY`, `MONGO_URI`, `FIREBASE_CREDENTIALS_FILE`, `FIREBASE_CREDENTIALS_JSON`.
  - Missing strict validation: `config.py` does not use `pydantic-settings` to enforce required keys on startup; application starts successfully even with critical keys missing, failing only at runtime during request handling.
- **Client Header Ingestion (`X-AI-API-Key` & `x-groq-api-key`):**
  - Accepted dynamically across `/scan/upload`, `/notes/generate`, `/notes/ask`, `/quiz/generate`, `/chat/ask`, `/visualiser/update`, `/visualiser/chat`.
  - Insecure / Brittle Validation: Multiple backend services (`ai_notes.py`, `ai_quiz.py`, `ai_detector.py`, `ai_visualiser.py`) contain the hardcoded check:
    ```python
    gemini_key = api_key if (api_key and api_key.startswith("AIza")) else GEMINI_API_KEY
    ```
    This silently discards valid non-Gemini keys (e.g. OpenAI, Groq, OpenRouter) sent by clients without returning an error.
- **Serverless File Exposure Risk:**
  - `FIREBASE_CREDENTIALS_FILE` points to local filesystem path. If deployed to ephemeral serverless containers (Vercel/Lambda) or container images without secret mounting, initialization crashes.

### Flutter Client (`stemly_app`)
- **Hardcoded Secret Artifacts in Version Control:**
  - `stemly_app/lib/firebase_options.dart`: Hardcoded API keys (`AIzaSyDNoxzV...`) across Web, Android, iOS, macOS, Windows configurations committed directly to source control.
  - `stemly_app/android/app/google-services.json`: Hardcoded Google OAuth client IDs, project numbers, and Firebase API keys stored in client build directories.
- **Device Secure Storage:**
  - `lib/services/groq_service.dart`: Prompts user for API key and stores it unencrypted in application memory, persisted via `FlutterSecureStorage` under key `"groq_api_key"`.
  - `lib/services/firebase_auth_service.dart`: Caches Firebase user JWT ID token in `FlutterSecureStorage` under key `"stemly_id_token"`.
- **Decentralized Header Injection:**
  - `scan_result_screen.dart`, `history_detail_screen.dart`, and `main_screen.dart` each independently read from `GroqService().getApiKey()` and manually attach `X-AI-API-Key` headers on raw `http.post` calls instead of utilizing a unified authenticated HTTP interceptor.

---

## 3. Endpoint Audit: Auth, Validation, Rate Limiting & Response Schemas

| Route & Method | Auth Enforced? | Input Validation Status | Rate Limiting | Response Schema (`response_model`) | Deficiencies & Risks |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `GET /` | No | None | None | None | Returns raw untyped dictionary. |
| `GET /auth/verify` | Yes (`require_firebase_user`) | Token in header | None | None | Missing response schema; returns raw user state dictionary. |
| `POST /scan/upload` | Yes (`require_firebase_user`) | **Critical Flaw** | None | None | Accepts raw `UploadFile` without file size cap or MIME validation in router. Calls dead `scan_service.py` that writes unvalidated bytes to disk. |
| `GET /scan/history` | Yes (`require_firebase_user`) | None | None | None | No pagination parameters (`limit`, `offset`). Could return thousands of documents for active users. |
| `GET /scan/ping` | **Broken Auth** | None | None | None | Health check route is blocked behind `require_firebase_user` because router-level dependency was applied globally! |
| `POST /notes/generate` | Yes (`require_firebase_user`) | Partial (`NotesGenerateRequest`) | None | **Missing** | `topic` and `variables` lack string length and item count constraints. Returns raw dict instead of declared `NotesResponse`. |
| `POST /notes/ask` | Yes (`require_firebase_user`) | Partial (`NotesFollowUpRequest`) | None | None | `previous_notes` accepts arbitrary unvalidated `Dict`. User prompt has no length limits. |
| `GET /quiz/topics` | **NO AUTH** | None | None | None | Unprotected public endpoint. Returns raw list without Pydantic schema model. |
| `GET /quiz/questions/{topic_id}` | **NO AUTH** | **Flawed** | None | None | Unprotected public endpoint. `topic_id: int` has no range validation; `count: int = Query(10)` has no upper bound constraint. |
| `POST /quiz/submit` | **NO AUTH** | **NONE** | None | None | Signature is `def submit_static_quiz(payload):` with zero type hints, zero Pydantic validation. Accepts arbitrary unvalidated JSON payload. |
| `GET /quiz/generate` | Yes (`require_firebase_user`) | **Flawed** | None | None | `count: int = Query(5)` lacks upper bound (`le=20`). An attacker can request `count=10000` to trigger severe LLM token exhaustion and billing spikes. |
| `POST /chat/ask` | Yes (`require_firebase_user`) | Partial (`ChatRequest`) | None | None | `message` has no character limits. Completely non-functional due to Ollama/Gemini endpoint misconfiguration. |
| `GET /visualiser/list` | Yes (`require_firebase_user`) | None | None | None | Returns raw in-memory dictionary. Missing response model. |
| `POST /visualiser/generate` | Yes (`require_firebase_user`) | Partial (`VisualiserGenerateRequest`) | None | None | **Shadowed Route:** Exact same path defined in both `routers/visualiser.py` and `routers/visualiser_engine.py`. |
| `POST /visualiser/update` | Yes (`require_firebase_user`) | Weak | None | None | Parameters dictionary accepts arbitrary untyped nested data. |
| `POST /visualiser/chat` | Yes (`require_firebase_user`) | Weak | None | None | Prompt has no character limits. Returns raw dict. |
| `POST /visualiser/save` | Yes (`require_firebase_user`) | Partial (`VisualiserSaveRequest`) | None | None | Missing response schema. |
| `GET /visualiser/states` | Yes (`require_firebase_user`) | None | None | None | Missing pagination. Returns raw MongoDB document array. |
| `GET /visualiser/templates` | Yes (`require_firebase_user`) | None | None | None | Synchronous file loader reading local disk on every request. |
| `GET /visualiser/template/{id}`| Yes (`require_firebase_user`) | None | None | None | `template_id` string has no regex/sanitization; vulnerable to path traversal if used directly in template loading. |
| `POST /visualiser/update-parameters` | Yes (`require_firebase_user`) | Partial | None | None | Missing response model. |
| `GET /visualiser/phet/search` | Yes (`require_firebase_user`) | Weak | None | None | Unbounded `topic: str` parameter. |

---

## 4. Blocking Calls Inside Async Handlers

FastAPI executes `async def` endpoints directly on the main event loop thread. Synchronous I/O operations inside `async def` block all concurrent incoming requests, destroying throughput:

1. **`backend/auth/auth_middleware.py:33`**:
   `user_info = verify_firebase_token(id_token)` inside `async def require_firebase_user()`.
   *Impact:* Executes synchronous cryptographic verification and HTTP calls to Google servers on every authenticated request, blocking the main event loop thread.
2. **`backend/routers/chat.py:44`**:
   `response = requests.post(f"{OLLAMA_BASE_URL}/api/generate", ...)` inside `async def handle_unified_chat()`.
   *Impact:* Blocks the entire worker process for up to 120 seconds per chat request.
3. **`backend/services/ai_chat.py:100, 107, 126`**:
   `requests.post(url, json=payload, ...)` and `time.sleep(wait_time)` inside `async def process_visualiser_chat()`.
   *Impact:* 60-second blocking HTTP call and blocking thread sleep during 429 backoff.
4. **`backend/services/ai_detector.py:73, 104, 187, 235`**:
   `requests.post(...)`, `time.sleep(wait_time)`, and `with open(image_path, "rb") as image_file:` inside `async def _query_gemini_text()`, `async def _query_gemini_vision()`, and `async def detect_topic()`.
   *Impact:* Blocking file system disk reads and blocking synchronous HTTP calls inside asynchronous topic detection.
5. **`backend/services/ai_quiz.py:401, 426`**:
   `requests.post(url, json=payload, ...)` and `time.sleep(wait_time)` inside `async def generate_quiz_with_ai()`.
   *Impact:* Blocks worker thread for 60s + retry sleeps during quiz generation.
6. **`backend/services/ai_visualiser.py:80, 86, 108`**:
   `requests.post(url, ...)` and `time.sleep(wait_time)` inside `async def adjust_parameters_with_ai()`.
   *Impact:* Freezes backend worker process during parameter adjustments.
7. **`backend/services/storage.py:10, 42`**:
   `os.makedirs(SCANS_DIR)` and `with open(file_path, "wb") as f: f.write(contents)` inside `async def save_scan()`.
   *Impact:* Synchronous disk I/O on large image uploads inside async coroutine.
8. **`backend/services/scan_service.py:15, 25`**:
   `os.makedirs(UPLOAD_DIR)` and `shutil.copyfileobj(file.file, buffer)` inside `async def save_scan()`.
   *Impact:* Synchronous stream copying from memory/spool to disk blocks the loop.
9. **`backend/routers/visualiser_engine.py:27` & `backend/services/visualiser_loader.py:13`**:
   `os.listdir(TEMPLATES_DIR)` and `json.load(f)` executed synchronously inside `async def get_templates()`.
   *Impact:* Synchronous file directory scanning on every request.

---

## 5. Dead Code, Duplicated Logic & Hardcoded Values

### Dead Code & Ghost Files
- `backend/routers/users.py`: **0-byte empty file** mounted in `main.py` (`from routers import users; app.include_router(users.router)`).
- `backend/models/scan_models.py`: **0-byte empty file**.
- `backend/utils/id_generator.py`: **0-byte empty file**.
- `backend/utils/time_utils.py`: **0-byte empty file**.
- `backend/services/history_service.py`: In-memory temporary database service containing `DATABASE = []`, `add_history`, and `get_user_history`. Completely orphaned and unreferenced (actual history is handled by `backend/database/history_model.py`).
- `backend/services/storage.py`: Contains a robust `save_scan()` with magic-byte checks and 5MB validation, but is **never imported by any router**. `routers/scan.py` instead imports `scan_service.py`.
- `backend/routers/visualiser_loader.py`: Orphaned helper file placed inside `routers/` directory duplicating `backend/services/visualiser_loader.py`.
- `stemly_app/lib/screens/scan_result_screen_fixed.dart`: A 250-line file that is entirely commented out sitting in the active production source tree.
- Root Debug Scripts: `debug_api.py`, `debug_imports.py`, and `reproduce_path_issue.py` left in backend root directory.
- `backend/env_template.txt`: Redundant legacy template duplicating `.env.example`.

### Duplicated Logic & Route Shadowing
- **Critical Route Shadowing:** Both `backend/routers/visualiser.py` and `backend/routers/visualiser_engine.py` are mounted to prefix `"/visualiser"` in `main.py`. Both define `POST /visualiser/generate`. Whichever router is registered first in `main.py` shadows and permanently hides the other endpoint.
- **`clean_json_output()`:** Four identical implementations of markdown code block stripping and regex JSON parsing duplicated across:
  - `backend/services/ai_chat.py`
  - `backend/services/ai_detector.py`
  - `backend/services/ai_quiz.py`
  - `backend/services/ai_visualiser.py`
- **Gemini Key Fallback & Exponential Backoff Loop:** 50+ lines of identical retry loops switching between `gemini_key` and `fallback_key` on 401/403/429 duplicated across all four AI service modules.
- **Double Simulation Engine:** `visualiser.py` maintains an in-memory dictionary `SIMULATION_TEMPLATES`, while `visualiser_engine.py` loads templates from `backend/templates/`.

### Hardcoded Constants
- `http://10.0.2.2:8080`: Hardcoded across 5 Flutter files:
  - `lib/screens/scan_result_screen.dart:51`
  - `lib/screens/history_detail_screen.dart:33`
  - `lib/screens/main_screen.dart:37`
  - `lib/visualiser/visualiser_api.dart:7`
  - `lib/services/firebase_auth_service.dart:24`
- `"https://stemly-backend.vercel.app"`: Hardcoded production backend URL in `stemly_app/lib/screens/main_screen.dart:34`.
- `"stemly_db"`: MongoDB database name hardcoded in `backend/database/db.py:30`.
- `"AIza"`: Hardcoded prefix check enforcing Google Gemini keys and breaking third-party LLM providers across 4 backend services.
- `backend/services/ai_quiz.py:12-239`: 227 lines of static hardcoded MCQs embedded directly in application logic.
- `backend/services/quiz_service.py:8-40`: Hardcoded static quiz questions embedded directly in service class.

---

## 6. Missing Tests & Testing Deficiencies

### Backend
- **Zero Real Automated Tests:** Files prefixed with `test_` (`test_aiml.py`, `test_aiml_llm.py`, `test_db_connection.py`, `test_notes.py`, `test_openrouter.py`, `test_quiz.py`, `test_visualiser.py`) are **manual scratch scripts**, not automated test suites. They execute direct live HTTP calls against external APIs, require production environment keys, lack assertions, lack teardown, and do not integrate with `pytest`.
- **Missing Test Suites:**
  - **No Unit Tests:** No unit tests with mocked LLM HTTP responses (`respx` or `unittest.mock`).
  - **No Middleware Tests:** No test coverage for Firebase JWT verification (`valid token`, `expired token`, `revoked token`, `missing Bearer prefix`).
  - **No Validation Tests:** Zero tests verifying file upload size restrictions, image format validation, or Pydantic boundary errors.
  - **No Database Isolation:** Zero database mocking; tests fail immediately if MongoDB Atlas is unreachable.
  - **No Concurrency / Async Tests:** Zero async event loop concurrency tests.

### Flutter (`stemly_app`)
- **Default Placeholder Only:** `test/widget_test.dart` is the only test file in the project (commented-out counter test).
- **Missing Service Unit Tests:** Zero unit tests for `FirebaseAuthService`, `GroqService`, or `VisualiserApi`.
- **Missing Widget & State Tests:** Zero widget tests for scanning workflow, quiz evaluation, or interactive physics canvas.
- **Missing Integration Tests:** Zero automated end-to-end user journey tests (`integration_test`).

---

## 7. Top 15 Risks Ranked by Severity (with One-Line Fixes)

1. **CRITICAL - Broken Chat Route Due to URL Mismatch (`routers/chat.py`)**  
   *Risk:* `POST /chat/ask` posts Ollama payloads to Google Gemini API URLs, causing guaranteed HTTP 404/500 errors for all users.  
   *Fix:* Standardize `chat.py` on the asynchronous Gemini API client or dedicated Ollama client based on configuration.

2. **CRITICAL - Route Collision & Shadowing in Visualiser (`visualiser.py` vs `visualiser_engine.py`)**  
   *Risk:* Duplicate route registrations on `/visualiser` cause silent shadowing and unpredictable routing behavior in production.  
   *Fix:* Merge `routers/visualiser.py` and `routers/visualiser_engine.py` into a single canonical router with unified endpoints.

3. **CRITICAL - Event Loop Freezing from Synchronous I/O in Async Coroutines**  
   *Risk:* Synchronous `requests.post`, `time.sleep`, and file I/O inside `async def` freeze the main thread, stalling all concurrent users.  
   *Fix:* Migrate all HTTP operations to `httpx.AsyncClient` and replace `time.sleep` with `asyncio.sleep`.

4. **CRITICAL - Complete Absence of API Rate Limiting**  
   *Risk:* Uncapped endpoints (`/notes/generate`, `/quiz/generate`, `/chat/ask`) allow trivial DoS attacks and runaway LLM billing.  
   *Fix:* Apply `slowapi` rate limiting middleware (e.g., 10 requests/minute per UID/IP) across all AI routes.

5. **HIGH - Unrestricted & Unvalidated File Uploads in `routers/scan.py`**  
   *Risk:* Uses unvalidated `scan_service.py` which blindly streams uploaded files to disk without MIME or size verification, enabling disk fill and malware uploads.  
   *Fix:* Validate file magic bytes and enforce a 5MB limit using `storage.py` before streaming to cloud storage.

6. **HIGH - Unprotected Public Quiz Endpoints (`routers/quiz_router.py`)**  
   *Risk:* `/quiz/topics`, `/quiz/questions`, and `/quiz/submit` have no authentication or schema validation, allowing unauthorized data scraping and corruption.  
   *Fix:* Add `dependencies=[Depends(require_firebase_user)]` and Pydantic request models to all quiz routes.

7. **HIGH - Ephemeral Disk Failures in Serverless / Container Environments**  
   *Risk:* Writing uploaded scans and logs to local filesystem paths (`static/scans/`) crashes or loses data on Vercel, Cloud Run, or AWS Lambda.  
   *Fix:* Decouple file persistence to Cloud Object Storage (AWS S3, Google Cloud Storage, or Cloudflare R2) via presigned URLs.

8. **HIGH - Blocking Firebase JWT Verification on Every Request**  
   *Risk:* Synchronous `verify_id_token` in `auth_middleware.py` blocks the event loop thread on every single authenticated request.  
   *Fix:* Wrap token verification in `fastapi.concurrency.run_in_threadpool` or use asynchronous JWT decoding libraries.

9. **MEDIUM - Flutter App Direct External AI Calling (`lib/services/groq_service.dart`)**  
   *Risk:* Client-side calls to Grok/OpenAI bypass backend controls, expose API keys to inspection, and violate single-backend architecture.  
   *Fix:* Deprecate client-side LLM calls and route all AI prompts through authenticated backend proxy endpoints.

10. **MEDIUM - Hardcoded Backend IP & URLs Across Flutter Codebase**  
    *Risk:* Multiple hardcoded instances of `http://10.0.2.2:8080` cause connectivity failures on physical devices and staging builds.  
    *Fix:* Centralize backend base URL using compile-time environment flags (`--dart-define=API_URL=...`).

11. **MEDIUM - Hardcoded `"AIza"` Key Validation Breaking Third-Party LLMs**  
    *Risk:* Services discard valid custom API keys (OpenAI, Groq, OpenRouter) because they do not match Gemini's `"AIza"` prefix.  
    *Fix:* Parameterize provider selection and validate keys against target provider schemas instead of hardcoding Gemini's prefix.

12. **MEDIUM - Missing Response Models on FastApi Routes**  
    *Risk:* Endpoints return raw dictionaries without `response_model`, leaking internal fields and breaking OpenAPI contract generation.  
    *Fix:* Declare explicit Pydantic `response_model` schemas on all router decorators.

13. **LOW - 0-Byte Stub Files and Dead Code Clutter**  
    *Risk:* Empty files (`users.py`, `id_generator.py`, `scan_models.py`) and dead services (`history_service.py`) confuse maintainers and degrade code quality.  
    *Fix:* Delete all 0-byte stubs, unused services, and root-level scratch scripts.

14. **LOW - Absence of Automated CI/CD Test Pipeline**  
    *Risk:* No automated tests exist to verify changes before deployment, resulting in regressions reaching production unnoticed.  
    *Fix:* Implement a `pytest` suite for backend and `flutter test` for client, wired to GitHub Actions CI.

15. **LOW - In-Memory Database Fallback and Silent Failure**  
    *Risk:* Disconnected MongoDB silently degrades to unpersisted no-ops or in-memory arrays without logging alerts.  
    *Fix:* Introduce structured health checks on startup and raise explicit 503 Service Unavailable when the database is required.

---

## 8. Proposed Target Folder Structure

### Backend (`backend/`) - Clean, Minimal & Production-Grade
```
backend/
├── app/
│   ├── __init__.py
│   ├── main.py                     # FastAPI application factory, lifespan, CORS, middleware
│   ├── config.py                   # Pydantic BaseSettings (validated environment configuration)
│   ├── api/
│   │   ├── __init__.py
│   │   ├── deps.py                 # Common dependencies (auth, db, rate limiting)
│   │   └── v1/
│   │       ├── __init__.py
│   │       ├── router.py           # Unified v1 router aggregation
│   │       ├── auth.py             # User verification & sync
│   │       ├── scan.py             # Image upload, OCR, and topic detection
│   │       ├── notes.py            # AI notes generation & follow-up chat
│   │       ├── quiz.py             # Quiz generation, static MCQs, submission
│   │       ├── chat.py             # Unified AI STEM tutor chat
│   │       └── visualiser.py       # Unified simulation controller & PhET search
│   ├── core/
│   │   ├── __init__.py
│   │   ├── security.py             # Async Firebase token verification & auth handlers
│   │   ├── exceptions.py           # Custom domain & HTTP error handlers
│   │   └── rate_limiter.py         # Slowapi rate limiter configuration
│   ├── db/
│   │   ├── __init__.py
│   │   ├── mongo.py                # Async Motor client lifecycle & healthcheck
│   │   └── repositories/           # Data access layers (users, scans, notes, visualiser)
│   ├── models/                     # Strongly-typed Pydantic schemas (Request & Response)
│   │   ├── auth.py
│   │   ├── scan.py
│   │   ├── notes.py
│   │   ├── quiz.py
│   │   ├── chat.py
│   │   └── visualiser.py
│   └── services/                   # Pure business logic & external async clients
│       ├── __init__.py
│       ├── llm/
│       │   ├── __init__.py
│       │   ├── base.py             # Abstract base LLM provider interface
│       │   └── gemini.py           # Asynchronous HTTPX Gemini client (retries, key rotation)
│       ├── storage.py              # Cloud storage service (S3/GCS/R2 with local dev fallback)
│       ├── phet.py                 # PhET simulations search & catalog
│       └── simulation_loader.py    # Simulation template service
├── data/
│   ├── phet_simulations.json       # PhET catalog
│   └── templates/                  # Interactive simulation templates
├── tests/                          # Automated Pytest suite
│   ├── __init__.py
│   ├── conftest.py                 # Pytest fixtures, mock HTTP clients (respx), test auth tokens
│   ├── test_auth.py
│   ├── test_scan.py
│   ├── test_notes.py
│   ├── test_quiz.py
│   └── test_visualiser.py
├── .env.example
├── Dockerfile
├── requirements.txt
└── requirements-dev.txt
```

### Flutter Client (`stemly_app/lib/`) - Feature-First & Layered
```
stemly_app/lib/
├── core/
│   ├── config/                     # Environment configuration (via --dart-define)
│   │   └── app_config.dart
│   ├── network/                    # Centralized HTTP client, auth interceptor, error handler
│   │   ├── api_client.dart
│   │   ├── api_endpoints.dart
│   │   └── auth_interceptor.dart
│   ├── theme/                      # App theme, typography, color palettes
│   │   ├── app_theme.dart
│   │   └── app_colors.dart
│   └── utils/                      # Common UI formatters & helpers
├── data/
│   ├── models/                     # Data transfer objects with serialization
│   │   ├── scan_result.dart
│   │   ├── note_model.dart
│   │   ├── quiz_model.dart
│   │   └── simulation_model.dart
│   ├── repositories/               # Repositories mediating network calls
│   │   ├── scan_repository.dart
│   │   ├── notes_repository.dart
│   │   ├── quiz_repository.dart
│   │   └── visualiser_repository.dart
│   └── services/                   # Platform & device services
│       ├── firebase_auth_service.dart
│       └── secure_storage_service.dart
├── providers/                      # State management controllers
│   ├── auth_provider.dart
│   ├── scan_provider.dart
│   ├── notes_provider.dart
│   ├── quiz_provider.dart
│   └── visualiser_provider.dart
├── screens/                        # UI Screens grouped by feature
│   ├── auth/
│   ├── home/
│   ├── scan/
│   ├── notes/
│   ├── quiz/
│   ├── visualiser/
│   └── settings/
├── widgets/                        # Shared UI components
│   ├── custom_button.dart
│   ├── loading_indicator.dart
│   └── error_view.dart
└── main.dart                       # App entry point, Firebase init, provider tree
```
