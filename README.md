<p align="center">
  <h1 align="center">STEMLY</h1>
  <p align="center"><strong>Scan. Visualise. Learn.</strong></p>
  <p align="center">
    An AI-powered multi-modal STEM learning platform that transforms textbook problems and diagrams into real-time interactive simulations, structured study notes, socratic AI tutoring, and adaptive quizzes.
  </p>
</p>

<p align="center">
  <a href="https://github.com/SH-Nihil-Mukkesh-25/Stemly/actions/workflows/flutter-ci.yml"><img src="https://github.com/SH-Nihil-Mukkesh-25/Stemly/actions/workflows/flutter-ci.yml/badge.svg" alt="Flutter CI"></a>
  <a href="https://github.com/SH-Nihil-Mukkesh-25/Stemly/actions/workflows/backend-ci.yml"><img src="https://github.com/SH-Nihil-Mukkesh-25/Stemly/actions/workflows/backend-ci.yml/badge.svg" alt="Backend CI"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-green.svg" alt="License: MIT"></a>
  <img src="https://img.shields.io/badge/Flutter%20Tests-69%20Passing-brightgreen.svg" alt="Flutter Tests: 69 Passing">
  <img src="https://img.shields.io/badge/Backend%20Tests-152%20Passing-brightgreen.svg" alt="Backend Tests: 152 Passing">
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white" alt="Flutter 3.x">
  <img src="https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white" alt="Dart 3.x">
  <img src="https://img.shields.io/badge/Python-3.12+-3776AB?logo=python&logoColor=white" alt="Python 3.12+">
  <img src="https://img.shields.io/badge/uv-Astral-DE5FE9?logo=astral&logoColor=white" alt="uv">
  <img src="https://img.shields.io/badge/FastAPI-009688?logo=fastapi&logoColor=white" alt="FastAPI">
  <img src="https://img.shields.io/badge/Groq_AI-F55036?logo=groq&logoColor=white" alt="Groq AI">
  <img src="https://img.shields.io/badge/Google_Gemini-4285F4?logo=google&logoColor=white" alt="Google Gemini">
  <img src="https://img.shields.io/badge/Firebase_Auth-FFCA28?logo=firebase&logoColor=black" alt="Firebase Auth">
  <img src="https://img.shields.io/badge/MongoDB_Atlas-47A248?logo=mongodb&logoColor=white" alt="MongoDB Atlas">
</p>

---

## Table of Contents

- [The Educational Challenge](#the-educational-challenge)
- [The STEMLY Solution](#the-stemly-solution)
- [Interactive UI Showcase](#interactive-ui-showcase)
- [Core Features](#core-features)
  - [1. AI Universal Visualiser Engine (60–120 FPS)](#1-ai-universal-visualiser-engine-60120-fps)
  - [2. AI Structured Study Notes](#2-ai-structured-study-notes)
  - [3. Socratic AI Tutor & Streaming Protocol v2](#3-socratic-ai-tutor--streaming-protocol-v2)
  - [4. Smart Adaptive Quizzes (Up to 20 Questions)](#4-smart-adaptive-quizzes-up-to-20-questions)
  - [5. Apple HIG In-App Splash Screen](#5-apple-hig-in-app-splash-screen)
  - [6. Apple HIG Design System & Dark Mode Default](#6-apple-hig-design-system--dark-mode-default)
  - [7. Enterprise Multi-Tenant Isolation & Cloud Sync](#7-enterprise-multi-tenant-isolation--cloud-sync)
  - [8. Complete Authentication & Guest Mode Suite](#8-complete-authentication--guest-mode-suite)
- [System Architecture](#system-architecture)
- [API Overview](#api-overview)
- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Backend Setup](#backend-setup)
  - [Mobile App Setup (Flutter)](#mobile-app-setup-flutter)
  - [Environment Variables](#environment-variables)
- [Testing & Quality Assurance](#testing--quality-assurance)
- [Project Structure](#project-structure)
- [Documentation Index](#documentation-index)
- [Team & Acknowledgments](#team--acknowledgments)
- [License](#license)

---

## The Educational Challenge

STEM students frequently struggle with visualizing abstract physical laws and mathematical concepts from static textbooks and 2D chalkboard sketches:
- **Theory vs. Intuition Gap**: Memorizing equations such as $y(t) = v_0 t - \frac{1}{2}gt^2$ does not build intuitive mental models of projectile apexes, air drag limits, or harmonic phase spaces.
- **Passive Learning**: Traditional video explanations are non-interactive—learners cannot dynamically adjust variables like velocity, launch angle, friction, spring constants, or refractive indices to witness cause-and-effect.
- **Fragmented Tooling**: Students juggle disjoint apps for scanning, note taking, graphing calculators, formula sheets, and tutors without unified session continuity.

---

## The STEMLY Solution

With **STEMLY**, a student simply snaps a photo of any handwritten equation, textbook problem, or physics diagram. The platform orchestrates on-device OCR, multi-modal vision LLMs, and real-time canvas rendering into four unified pillars:

1. **AI Visualiser**: Instantly synthesizes 60–120 FPS parameter-driven interactive physics simulations with live time-series graphs ($x\text{-}t$, $v\text{-}t$, $a\text{-}t$) and natural language adjustments.
2. **AI Study Notes**: Generates complete conceptual breakdowns, mathematical derivations with LaTeX KaTeX rendering, worked examples, and common pitfalls.
3. **Socratic AI Tutor**: A guided conversational assistant that fosters critical thinking step-by-step with dynamic follow-ups and simulation tool calling rather than spoiling direct answers.
4. **Smart Diagnostic Quizzes**: Automatically constructs conceptual multiple-choice checks (up to 20 questions) with 3 selectable difficulty levels and diagnostic feedback.

---

## Interactive UI Showcase

<div align="center">

| Home Dashboard | Live Universal Visualiser | AI Structured Study Notes |
|:---:|:---:|:---:|
| <img src="screenShots/homescreen.png" width="240" alt="Home Dashboard"/> | <img src="screenShots/visualiser_screen.gif" width="240" alt="Live Interactive Visualiser"/> | <img src="screenShots/notes_screen.gif" width="240" alt="Comprehensive AI Notes with LaTeX"/> |

| Adaptive Quizzes (Up to 20 Qs) | Multi-Tenant History | Account & Data Privacy |
|:---:|:---:|:---:|
| <img src="screenShots/quizscreen.png" width="240" alt="Quiz Setup & Difficulty Selector"/> | <img src="screenShots/HistoryScreen.png" width="240" alt="History Dashboard"/> | <img src="screenShots/AccountScreen.png" width="240" alt="Account Management Screen"/> |

| Sign In (Apple HIG) | Create Account | Settings & Appearance |
|:---:|:---:|:---:|
| <img src="screenShots/signin.png" width="240" alt="Sign In Screen"/> | <img src="screenShots/signup.png" width="240" alt="Create Account Screen"/> | <img src="screenShots/settings.gif" width="240" alt="Settings & Dark Mode Demo"/> |

</div>

---

## Core Features

### 1. AI Universal Visualiser Engine (60–120 FPS)

Not a pre-recorded animation or canned video—STEMLY generates live, computational visual models with interactive parameter controls:

- **Interactive Sliders**: Tweak velocity, launch angle, mass, gravitational acceleration, air resistance, spring constant, or index of refraction in real time.
- **Natural Language Control**: Prompt the simulation with instructions like *"What if gravity was zero?"* or *"Double the friction"* and watch parameters reconfigure dynamically via AI parameter sanitization.
- **Real-Time Kinematic Graphs**: Live synchronized plots for position-time ($x$-$t$), velocity-time ($v$-$t$), and acceleration-time ($a$-$t$).
- **10+ Native Simulation Templates**:
  - **Projectile Motion**: Multi-trajectory parabolic paths with live apex height ($h_{\max}$), flight time ($t_{\text{flight}}$), and range indicators.
  - **Simple Harmonic Motion (SHM)**: Mass-spring and pendulum oscillators with phase space portraits and damping factors.
  - **Ray Optics & Refraction**: Convex/concave lenses, focal planes, Snell's Law refractions, and real/virtual image projections.
  - **Kinematics & Free Fall**: Uniform and accelerated rectilinear motion with live kinematic telemetry.
  - **Inclined Plane & Friction**: Normal forces, gravitational components ($mg\sin\theta$, $mg\cos\theta$), and static/kinetic friction transitions.
  - **Pulley Systems & Tension**: Atwood machines with coupled accelerations and string tension vectors.
  - **Elastic & Inelastic Collisions**: Momentum and kinetic energy conservation analysis in 1D and 2D.
  - **Bohr Atom Multi-Shell Model**: Electron configurations, principal quantum numbers ($n=1, 2, 3, 4$), and shell orbits up to Calcium ($Z=20$).
  - **Equation Plotter & AST Visualizer**: Safe mathematical function plotting with asymptote and discontinuity protections ($1/x$, $\sqrt{x}$).
  - **PhET Interactive Simulation Sandbox**: Secure bridge to validated PhET Colorado simulations.

### 2. AI Structured Study Notes

- **Concept Breakdowns**: Core principles explained in accessible, intuitive prose.
- **LaTeX Math Rendering**: Beautiful typography for equations using KaTeX.
- **Step-by-Step Derivations**: Complete solutions showing intermediate algebraic steps.
- **Variable Tables**: Explicit definitions, SI units, and dimensional notations for every governing variable.
- **Common Pitfalls & Mistakes**: Highlights frequent exam traps and misconceptions.
- **Persistent Offline Storage**: Notes cached locally via schema v3 for instant revision without internet access.

### 3. Socratic AI Tutor & Streaming Protocol v2

- **Socratic Pedagogy**: Guides learners through probing questions, conceptual hints, and boundary checks rather than outputting immediate answers.
- **Scanned Context Grounding**: The AI tutor reads the exact problem image, extracted text, and active simulation parameters.
- **Tool Calling & Live Updates**: The tutor can autonomously invoke `update_simulation` to adjust canvas parameters or `suggest_followups` to provide 3 dynamic next questions.
- **Low-Latency Streaming Protocol v2**: Token-by-token Server-Sent Events (SSE) streaming with typed envelopes (`StreamEventEnvelope`).
- **Multi-Tier Resilience**: Seamless fallback between Groq, Google Gemini 1.5/2.0, and local emergency agents via an automatic Circuit Breaker.

### 4. Smart Adaptive Quizzes (Up to 20 Questions)

- **Configurable Question Limit**: Seamlessly configure from 3 up to **20 questions** per quiz session via an interactive slider.
- **3-Tier Difficulty Modes**:
  - **Easy**: Emphasizes fundamental definitions, conceptual relationships, and simple formula checks.
  - **Medium**: Balances conceptual understanding with standard multi-step numerical problem solving.
  - **Hard**: Challenges students with advanced edge cases, boundary conditions, and mathematical derivations.
- **Dynamic Model Escalation**: Requests with $\le 10$ questions utilize `openai/gpt-oss-20b` for 3–5s generation; requests with $11$ to $20$ questions automatically route to `openai/gpt-oss-120b` with concise formatting to guarantee complete JSON generation.
- **Emergency Zero-Connectivity Fallback**: Local curated STEM question bank with question padding guarantees quizzes always generate even in total offline/network failure.
- **Diagnostic Feedback**: Instant post-submission scoring with pedagogical explanations for why correct options hold and why distractors fail.

### 5. Apple HIG In-App Splash Screen

Redesigned strictly following Apple's Human Interface Guidelines:
- **Calm 1.2s Entrance Sequence**:
  1. Centered glass tile with glowing accent border.
  2. Thin orange scan line sweeps top to bottom once across the viewfinder brackets ($600\text{ ms}$, `Curves.easeOutCubic`).
  3. Single parabolic arc (projectile trajectory) draws outward from the tile's right edge ending in an orange dot.
  4. "STEMLY" wordmark fades and rises $8\text{ pt}$ into place, followed $80\text{ ms}$ later by the tagline *"Scan, visualise, learn."*
- **Deferred Progress Indicator**: Shows nothing for the first $400\text{ ms}$. If initialization finishes quickly, the user never sees a spinner; if slow, a subtle indeterminate loader fades in with label *"Loading"*.
- **Cancellable Exit**: Cross-fades over $240\text{ ms}$ the moment initialization completes without holding the user for an artificial timer.
- **Accessibility & Reduce Motion**: When `disableAnimationsOf` is true, skips all transitions and displays a static frame with a gentle $150\text{ ms}$ fade. Fully labeled with `Semantics`.

### 6. Apple HIG Design System & Dark Mode Default

- **Default Dark Mode**: Deep pure black (`#000000`) for OLED power efficiency, paired with `#1C1C1E` and `#2C2C2E` neutral surfaces.
- **80–85% Neutral Palette**: High-contrast typography with zero blue palette violations.
- **Vibrant Orange Accents**: Whitelisted `#FF8A3D` (Dark) and `#FF6B00` (Light) accents for primary interactive controls (15–20% visual weight).
- **Apple Motion**: 240–260ms smooth transitions utilizing `Curves.easeOutCubic` and sliding pill indicators (`AppSegmentedControl`).
- **Full Accessibility**: Compliant with 200% dynamic type scale and WCAG AAA contrast ratios.

### 7. Enterprise Multi-Tenant Isolation & Cloud Sync

Enterprise-grade user data isolation guarantees that **User A never sees User B's scans or notes**:

- **Database-Level Isolation**: All MongoDB Atlas collections (`scans`, `notes`, `chat_sessions`, `visualiser`, `usage_counters`) enforce authenticated UID indexing (`user_id`).
- **IDOR Protection**: Backend routers verify token ownership before executing reads, updates, or deletes.
- **Local Storage Schema v3**: Scoped cache keys (`stemly_history_v3_${uid}` and `stemly_notes_v3_${uid}`).
- **Zero-Residue Sign-Out**: Memory and local cache are flushed upon sign-out.
- **Cloud Rehydration**: Scans and notes sync automatically from MongoDB Atlas on login.
- **Resilient Connection Pooling**: Configured with `serverSelectionTimeoutMS: 2500`, `connectTimeoutMS: 3000`, and `socketTimeoutMS: 5000` to prevent hanging requests.

### 8. Complete Authentication & Guest Mode Suite

- **Email & Password Authentication**:
  - Full Name collection (powers the *"Hi, {Name}"* home greeting).
  - Live email format validation.
  - Password field with show/hide toggle.
  - Confirm password verification.
  - Forgot password password-reset link distribution via Firebase Auth.
  - User-friendly error messaging for common auth exceptions.
- **Continue with Google**: One-tap sign-in with authentic multi-colored Google "G" logo.
- **Sign in with Apple**: Native iOS and cross-platform credential integration.
- **Continue as Guest**: Zero-friction exploration without upfront registration; seamlessly generates simulations, notes, and quizzes using the dev/guest bypass protocol.

---

## System Architecture

```mermaid
graph TD
    subgraph Client ["Flutter Mobile Application (stemly_app)"]
        UI["Flutter UI (Apple HIG & Dark Mode Default)"]
        AUTH_CLIENT["FirebaseAuthService (Token & Guest Manager)"]
        CACHE["OfflineStorage (Schema v3 & SharedPreferences)"]
        VIS_ENGINE["Universal Visualiser Engine (60-120 FPS CustomPainter)"]
        OCR_CLIENT["Google ML Kit OCR (On-Device Text Extraction)"]
    end

    subgraph Backend ["FastAPI Cloud Engine (backend)"]
        ROUTER["FastAPI Application Router (/scan, /notes, /visualiser, /quiz, /chat)"]
        AUTH_MW["Firebase Auth Middleware (Bearer JWT & Guest Bypass)"]
        LIMITER["Usage Limiter & Rate Limiter (SlowAPI & Daily Quota)"]
        CIRCUIT["Circuit Breaker & Fallback Chain"]
        OBS["Sentry APM & Observability"]
    end

    subgraph AI_Services ["Unified AI Inference Layer (services/agents)"]
        VISION["Groq Vision (Llama 3.2 11B Vision Preview)"]
        TEXT_FAST["Groq Fast LLM (GPT-OSS 20b for Notes & Quizzes <=10)"]
        TEXT_HIGH["Groq High-Capacity LLM (GPT-OSS 120b for Quizzes 11-20)"]
        GEMINI["Google Gemini 1.5 / 2.0 Failover"]
        FALLBACK["Deterministic Emergency STEM Engine"]
    end

    subgraph Data_Storage ["Persistent Cloud Infrastructure"]
        FB_AUTH["Firebase Authentication"]
        MONGO[("MongoDB Atlas (Motor Async Connection Pool)")]
        MEM_CACHE["In-Memory LRU Cache Tier (500 Entries)"]
    end

    UI --> AUTH_CLIENT
    UI --> CACHE
    UI --> VIS_ENGINE
    UI --> OCR_CLIENT

    AUTH_CLIENT -->|Bearer JWT or Guest Token| AUTH_MW
    UI -->|REST & SSE Stream Requests| ROUTER

    ROUTER --> AUTH_MW
    AUTH_MW -->|Verify UID| FB_AUTH
    ROUTER --> LIMITER
    ROUTER --> CIRCUIT

    CIRCUIT --> VISION
    CIRCUIT --> TEXT_FAST
    CIRCUIT --> TEXT_HIGH
    CIRCUIT --> GEMINI
    CIRCUIT --> FALLBACK

    ROUTER --> MONGO
    ROUTER --> MEM_CACHE
    ROUTER --> OBS
```

### Technology Matrix

| Layer | Technologies & Tools |
| :--- | :--- |
| **Mobile Client** | Flutter 3.x, Dart 3.x, Provider, CustomPainter (60–120 FPS), Google ML Kit OCR, KaTeX |
| **Backend API** | FastAPI, Python 3.12, Uvicorn, Astral `uv`, Pydantic v2, Motor (Async MongoDB) |
| **AI Inference** | Groq Llama 3.2 11B Vision, Groq GPT-OSS 120B/20B, Google Gemini 1.5/2.0, Whisper Large v3 |
| **Semantic Caching**| In-memory LRU tier + MongoDB persistent collection with 7-day TTL index |
| **Database** | MongoDB Atlas with composite compound indexes (`user_id`, `created_at`) & fast timeouts |
| **Identity & Security** | Firebase Auth (JWT Bearer tokens), Guest mode bypass, strict IDOR checks, GDPR account wipe |
| **Monitoring & QA** | Sentry APM with PII scrubbing, Pytest (152 tests), Flutter Widget Test Suite (69 tests) |

---

## API Overview

The backend exposes clean REST endpoints documented with OpenAPI/Swagger at `/docs`:

| Endpoint | Method | Auth | Description |
| :--- | :---: | :---: | :--- |
| `/scan/upload` | `POST` | Optional | Upload and process diagram/problem image via Vision LLM |
| `/scan/history` | `GET` | Required | Retrieve paginated scan history scoped strictly to authenticated user |
| `/scan/{scan_id}` | `GET` | Required | Retrieve single scan details with IDOR validation |
| `/scan/{scan_id}` | `DELETE` | Required | Delete scan record and associated artifacts |
| `/notes/generate` | `POST` | Optional | Generate structured LaTeX study notes from scanned concept |
| `/notes` | `GET` | Required | Retrieve user's paginated notes collection |
| `/visualiser/generate`| `POST` | Optional | Synthesize simulation parameters and template matching |
| `/visualiser/update` | `POST` | Optional | Process natural language modifications to simulation state |
| `/chat/stream` | `POST` | Optional | Streaming Socratic tutor chat session (Protocol v2) |
| `/quiz/generate` | `GET` | Required | Generate MCQs (`topic`, `count` up to 20, `difficulty: easy\|medium\|hard`) |
| `/quiz/submit` | `POST` | Required | Submit quiz responses for instant evaluation and score calculation |
| `/auth/me` | `GET` | Required | Retrieve current user profile and sync telemetry |
| `/auth/me/data` | `DELETE` | Required | GDPR compliant account wipe (scans, notes, chat sessions) |
| `/health` | `GET` | None | Service liveness, database connectivity, and circuit breaker status |

---

## Getting Started

### Prerequisites

Ensure the following tools are installed on your machine:
- **Flutter SDK**: 3.24+ ([Install Flutter](https://docs.flutter.dev/get-started/install))
- **Dart SDK**: 3.5+
- **Python**: 3.10+ (Python 3.12 recommended)
- **Astral uv**: Fast Python package manager ([Install uv](https://docs.astral.sh/uv/getting-started/installation/))
- **Git**

### Backend Setup

1. **Clone the repository**:
   ```bash
   git clone https://github.com/SH-Nihil-Mukkesh-25/Stemly.git
   cd Stemly/backend
   ```

2. **Install dependencies with Astral `uv`**:
   ```bash
   uv sync --extra dev
   ```

3. **Configure environment variables**:
   ```bash
   cp .env.example .env
   # Edit .env with your credentials (see table below)
   ```

4. **Launch the FastAPI development server**:
   ```bash
   uv run uvicorn main:app --host 0.0.0.0 --port 8080 --reload
   ```
   The backend will be live at `http://localhost:8080` (API documentation at `http://localhost:8080/docs`).

### Mobile App Setup (Flutter)

1. **Navigate to the Flutter directory**:
   ```bash
   cd ../stemly_app
   ```

2. **Install Flutter packages**:
   ```bash
   flutter pub get
   ```

3. **Run on an active device or emulator**:
   ```bash
   flutter run
   ```
   *(For Android Emulator, backend defaults to `http://10.0.2.2:8080`; for physical devices, provide `--dart-define=API_BASE_URL=http://YOUR_LAN_IP:8080`)*.

### Environment Variables

Configure these keys in `backend/.env`:

| Key | Required | Purpose |
| :--- | :---: | :--- |
| `GROQ_TEXT_API_KEY` | **Yes** | Groq API key for text reasoning, notes, and quiz generation |
| `GROQ_VISION_API_KEY`| **Yes** | Groq API key for Llama 3.2 Vision problem identification |
| `GROQ_FAST_MODEL` | Optional | Fast model ID (`openai/gpt-oss-20b`) |
| `GROQ_TEXT_MODEL` | Optional | High-capacity model ID (`openai/gpt-oss-120b`) |
| `GEMINI_API_KEY` | Optional | Multimodal failover and Socratic tutoring provider |
| `MONGO_URI` | **Yes** | MongoDB Atlas connection string for persistent storage |
| `FIREBASE_CREDENTIALS_FILE`| Optional | Path to Firebase Admin service account JSON |
| `ALLOW_DEV_AUTH_BYPASS`| Optional | Set to `true` to enable guest and mock token testing |
| `DAILY_LLM_QUOTA` | Optional | Maximum daily LLM invocations per user (default: 50) |
| `ENVIRONMENT` | Optional | Set to `development` or `production` |

---

## Testing & Quality Assurance

Both the mobile application and backend service enforce automated test suites:

### 1. Flutter Test Suite (69 Tests)
Validates Apple HIG token compliance, zero-blue palette rules, 200% dynamic text scale, offline storage schema migrations, mathematical AST expression plotting, simulation factory resolution, and splash screen entrance behavior:
```bash
cd stemly_app
flutter test
```
*Result: 69 / 69 passed (100%).*

### 2. Backend Test Suite (152 Tests)
Validates safety guardrails, prompt injection sanitization, circuit breaker triggers, LangSmith evaluations, multi-tenant UID isolation, and IDOR protection:
```bash
cd backend
uv run pytest
```
*Result: 152 / 152 passed (100%).*

---

## Project Structure

```
Stemly/
├── .github/
│   └── workflows/                # GitHub Actions CI for Flutter & Backend
├── screenShots/                  # High-resolution screenshots and live demo GIFs
├── docs/
│   ├── API.md                    # Detailed REST endpoint reference
│   ├── ARCHITECTURE.md           # System design & data flow specifications
│   ├── CHAT_PROTOCOL.md          # Socratic streaming protocol reference
│   ├── DEVELOPMENT.md            # Contributor guidelines & setup
│   ├── FAQ.md                    # Frequently asked questions
│   └── ROADMAP.md                # Development milestones & roadmap
│
├── backend/                      # FastAPI Python Engine
│   ├── auth/                     # Firebase Auth middleware, guest mode & user routing
│   ├── core/                     # Circuit breaker, rate limiting, usage limiter, guardrails
│   ├── database/                 # MongoDB Atlas async client, connection pool & models
│   ├── models/                   # Pydantic schemas (quiz, scan, notes, visualiser, chat)
│   ├── prompts/                  # AI system prompts (vision, socratic, notes, quizzes)
│   ├── routers/                  # API routes (/scan, /notes, /visualiser, /quiz, /chat)
│   ├── services/
│   │   └── agents/               # Unified AI Agent Engine (text, vision, cache, fallback)
│   ├── tests/                    # 152 Pytest unit & integration tests
│   ├── main.py                   # FastAPI server entrypoint
│   └── pyproject.toml            # uv project specification
│
└── stemly_app/                   # Flutter Mobile Client
    ├── assets/
    │   └── icons/                # High-res vectors & Google branding assets
    ├── lib/
    │   ├── core/                 # Flavor configurations, config & utilities
    │   ├── data/                 # API client & offline storage (v3)
    │   ├── models/               # Client-side data models
    │   ├── presentation/         # HIG components, buttons, segmented controls
    │   ├── quiz/                 # Interactive quiz player & score views
    │   ├── screens/              # Top-level application views (Scan, Notes, Auth, Splash)
    │   ├── services/             # Firebase Auth & API service providers
    │   ├── storage/              # Multi-tenant history store
    │   ├── theme/                # HIG design tokens, dark palette, typography
    │   ├── visualiser/           # 10+ Canvas physics simulation engines
    │   └── main.dart             # Application initialization
    └── test/                     # 69 Flutter widget & regression tests
```

---

## Documentation Index

- **[System Architecture](ARCHITECTURE.md)**: Deep dive into the scan-to-simulation pipeline, AI agents, and data models.
- **[REST API Reference](docs/API.md)**: Full request/response schemas and example cURL commands.
- **[Setup & Deployment Guide](docs/SETUP_GUIDE.md)**: Platform guides, Android APK builds, and Docker deployments.
- **[Socratic Chat Protocol](docs/CHAT_PROTOCOL.md)**: Protocol v2 specs for streaming tokens and tool calling.
- **[Development Guide](docs/DEVELOPMENT.md)**: Coding standards, adding new physics simulations, and Git workflows.
- **[Product Roadmap](docs/ROADMAP.md)**: Future milestones (circuits, chemistry, multi-language, AR).

---

## Team & Acknowledgments

STEMLY was engineered by **Team Mugiwara Coders** from Amrita Vishwa Vidyapeetham, Coimbatore:

| Team Member | Role | GitHub |
| :--- | :--- | :--- |
| **P Dakshin Raj** | AI Architecture & Full-Stack Development | [@Dakshin10](https://github.com/Dakshin10) |
| **SH Nihil Mukkesh** | Mobile Lead & Flutter Engineering | [@SH-Nihil-Mukkesh-25](https://github.com/SH-Nihil-Mukkesh-25) |
| **SHRE RAAM P J** | Backend Services & Cloud Infrastructure | [@SHRE-RAAM-P-J](https://github.com/SHRE-RAAM-P-J) |
| **Vibin Ragav S** | UI/UX & Interactive Simulations | [@VibinR-code](https://github.com/VibinR-code) |

---

## License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.

<div align="center">
  <sub>Built with ❤️ by Team Mugiwara Coders. Transforming STEM education, one scan at a time.</sub>
</div>
