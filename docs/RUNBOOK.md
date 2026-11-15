# STEMLY AI Tutor — Production Operations & Incident Runbook

This runbook establishes standardized operational workflows, health monitoring, common incident playbooks, key rotation procedures, and rollback routines for the **Stemly AI Tutor Backend** and **Streaming Protocol v2**.

---

## 1. System Overview & Health Telemetry

### 1.1 Architecture Components
- **Framework & Worker Runtime:** FastAPI running on Gunicorn with asynchronous `uvicorn.workers.UvicornWorker` (`WEB_CONCURRENCY=2-4`).
- **AI Inference Engine:** Groq Cloud LPU (`openai/gpt-oss-120b` or `llama-3.3-70b-versatile`).
- **Streaming Protocol:** Server-Sent Events (SSE) v2 with monotonic sequence IDs (`meta`, `token`, `parameters`, `followups`, `error`, `usage`, `done`).
- **Resilience Layer:** In-memory asynchronous Circuit Breaker with 5-failure trip threshold and 30s cooldown.
- **Cache Layer:** Multi-tier normalized query hash cache (<15ms stream replay).
- **Session Memory:** Sliding context window with token budgeting and asynchronous pedagogical summarization (MongoDB Atlas + In-Memory fallback).

### 1.2 Probing & Monitoring Endpoints

| Endpoint | Method | Expected Status | Purpose | Action on Failure |
| :--- | :--- | :--- | :--- | :--- |
| `/healthz` | GET | `200 {"status": "healthy"}` | Liveness check (K8s/Cloud Run) | Restart container |
| `/readyz` | GET | `200 {"status": "ready"}` | Readiness check (DB & Config) | Inspect MongoDB and API keys |
| `/chat/metrics` | GET | `200 { ... }` | Telemetry, TTFT percentiles, cost, breaker state | Inspect latency spikes or open circuit |

---

## 2. Incident Playbooks & Troubleshooting

### Incident 1: Circuit Breaker Trips to `OPEN` (Groq Upstream Outage)
- **Symptoms**:
  - `GET /chat/metrics` reports `"circuit_breaker_state": "OPEN"`.
  - Chat responses respond in **<0.05ms** with degraded offline pedagogical guidance (`degraded: true`).
- **Root Cause**:
  - 5 consecutive upstream timeouts or 5xx/429 errors from Groq API within a rolling window.
- **Diagnosis**:
  - Run `curl -s https://api.stemly.app/chat/metrics | jq .`
  - Check [Groq System Status](https://status.groq.com/).
- **Mitigation & Recovery**:
  1. The system **automatically recovers**: after `CIRCUIT_BREAKER_COOLDOWN_SECONDS` (30s), the breaker enters `HALF_OPEN` and sends a single probe request.
  2. If the probe succeeds, the breaker resets to `CLOSED`.
  3. If Groq remains down, traffic safely stays in degraded fallback mode without crashing the service or exhausting threads.

---

### Incident 2: Client Reports "Laggy / All-At-Once" Stream Output (Proxy Buffering)
- **Symptoms**:
  - The student does not see incremental token typing; the entire message pops up all at once after 2-3 seconds.
- **Root Cause**:
  - An intermediate reverse proxy (e.g. Nginx, Cloudflare, Traefik, ALB) is buffering the HTTP response instead of streaming chunks immediately.
- **Mitigation & Fix**:
  - Ensure backend headers are active:
    - `Cache-Control: no-cache`
    - `X-Accel-Buffering: no`
    - `Content-Encoding: identity`
  - In Nginx configuration, verify:
    ```nginx
    proxy_set_header Connection '';
    proxy_http_version 1.1;
    chunked_transfer_encoding on;
    proxy_buffering off;
    proxy_cache off;
    ```
  - In Cloudflare, ensure **Brotli** or **Gzip** auto-compression is disabled for `text/event-stream` mime types.

---

### Incident 3: Transient Network 409 Conflict (`Idempotency-Key`)
- **Symptoms**:
  - Mobile client logs `409 Conflict: Duplicate in-flight generation detected`.
- **Root Cause**:
  - Mobile device lost connection momentarily and re-sent the identical `Idempotency-Key` while the server was actively streaming the first request.
- **Mitigation**:
  - Expected behavior. The Flutter client should wait for the active stream or generate a fresh UUID/nonce for a new user turn.

---

### Incident 4: Database Outage / MongoDB Disconnection
- **Symptoms**:
  - Logs report `MongoNetworkError` or `ServerSelectionTimeoutError`.
- **Mitigation**:
  - The chat session layer automatically falls back to the high-performance in-memory TTL repository (`backend/database/chat_history.py`).
  - Chat conversations continue uninterrupted for all active sessions.

---

## 3. Zero-Downtime Credential Rotation

### 3.1 Groq API Key Rotation (`GROQ_TEXT_API_KEY`, `GROQ_VISION_API_KEY`)
1. Generate new keys in the [Groq Console](https://console.groq.com/keys).
2. Update the environment variables in Google Cloud Secret Manager / Docker environment:
   ```bash
   gcloud secrets versions add GROQ_TEXT_API_KEY --data-file=new_key.txt
   ```
3. Trigger a rolling deployment of the backend:
   ```bash
   gcloud run services update stemly-backend --region=us-central1
   ```
4. Confirm `GET /readyz` responds with `200 OK`.
5. Decommission the old keys in Groq Console after 15 minutes.

---

## 4. Rollback Playbook (<60 Seconds)

If a critical bug or regression is detected in production:

### 4.1 Cloud Run Instant Revision Rollback
```bash
# List previous revisions
gcloud run revisions list --service=stemly-backend --region=us-central1

# Direct 100% of traffic to previous known healthy revision
gcloud run services update-traffic stemly-backend \
  --to-revisions=stemly-backend-00042-xyz=100 \
  --region=us-central1
```

### 4.2 Git Emergency Rollback
```bash
# Revert deployment commit
git revert --no-edit HEAD
git push origin master
```
The GitHub Actions workflow (`.github/workflows/backend-ci.yml`) will run all linting, typing, and pytest suites automatically before container promotion.
