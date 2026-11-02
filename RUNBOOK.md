# STEMLY Production Operations & Incident Runbook

This runbook establishes standardized operational workflows, key rotation routines, incident response actions, and rollback playbooks for **STEMLY Backend** and **Stemly Mobile**.

---

## 1. System Overview & Health Verification

### Service Architecture
- **Backend Runtime:** Python 3.11 FastAPI with Gunicorn + Uvicorn workers running on Google Cloud Run.
- **Persistence:** MongoDB Atlas (M10+ Replica Set with auto-scaling).
- **Authentication:** Firebase Auth JWT token validation.
- **AI Acceleration:** Groq Cloud LPU API (Vision & Text models).
- **Observability:** Sentry APM + Google Cloud Monitoring.

### Health Check Endpoints
| Endpoint | Check Type | Valid Response | Failure Sign | Action |
| :--- | :--- | :--- | :--- | :--- |
| `GET /healthz` | Container Liveness | `200 {"status": "healthy"}` | Container unresponsive / OOM | Restart container |
| `GET /readyz` | System Readiness | `200 {"status": "ready", "database": "connected"}` | `503 {"status": "degraded"}` | Check Mongo Atlas connection & Groq API key configuration |

---

## 2. Key & Credential Rotation Procedures

All production secrets are stored in **Google Cloud Secret Manager** and injected into Cloud Run containers as environment variables. **Never commit secrets to git or store them in plain-text configs.**

### 2.1 Groq API Key Rotation (`GROQ_VISION_API_KEY`, `GROQ_TEXT_API_KEY`)
To rotate Groq keys with **zero downtime**:

1. **Generate New Keys:**
   Log into [Groq Console](https://console.groq.com/keys) and generate new API keys with the names `stemly-vision-prod-v2` and `stemly-text-prod-v2`.

2. **Add New Versions to Secret Manager:**
   ```bash
   # Add new version for Vision key
   echo -n "gsk_new_vision_key_here..." | gcloud secrets versions add GROQ_VISION_API_KEY --data-file=-

   # Add new version for Text key
   echo -n "gsk_new_text_key_here..." | gcloud secrets versions add GROQ_TEXT_API_KEY --data-file=-
   ```

3. **Deploy Cloud Run Revision to Pick Up Latest Secret Versions:**
   ```bash
   gcloud run services update stemly-backend \
     --update-secrets=GROQ_VISION_API_KEY=GROQ_VISION_API_KEY:latest,GROQ_TEXT_API_KEY=GROQ_TEXT_API_KEY:latest \
     --region=us-central1
   ```

4. **Verify Health:**
   ```bash
   curl -i https://stemly-backend-hash-uc.a.run.app/readyz
   ```
   Ensure response is `200 OK` and `"config": "valid"`.

5. **Revoke Old Keys:**
   Once verified in production telemetry for 15 minutes, delete the old keys from the Groq console.

---

### 2.2 Firebase Service Account Rotation (`FIREBASE_CREDENTIALS_JSON`)
1. In the [Firebase Console](https://console.firebase.google.com/), go to **Project Settings** > **Service accounts** > **Generate new private key**.
2. Upload the new JSON payload to Secret Manager:
   ```bash
   gcloud secrets versions add FIREBASE_CREDENTIALS_JSON --data-file=new-service-account.json
   ```
3. Trigger a rolling update on Cloud Run:
   ```bash
   gcloud run services update stemly-backend \
     --update-secrets=FIREBASE_CREDENTIALS_JSON=FIREBASE_CREDENTIALS_JSON:latest \
     --region=us-central1
   ```
4. Verify by attempting an authenticated request using the Flutter app.
5. In Google Cloud IAM, revoke the old service account key.

---

### 2.3 MongoDB Atlas Connection URI (`MONGO_URI`)
1. In MongoDB Atlas, create a new Database User (e.g., `stemly-prod-app-v2`) with `readWriteAnyDatabase` privileges.
2. Form the new SRV connection string with credentials encoded.
3. Update the secret:
   ```bash
   echo -n "mongodb+srv://stemly-prod-app-v2:SECURE_PASSWORD@cluster0.abcde.mongodb.net/stemly?retryWrites=true&w=majority" | \
     gcloud secrets versions add MONGO_URI --data-file=-
   ```
4. Update Cloud Run to load the latest secret:
   ```bash
   gcloud run services update stemly-backend \
     --update-secrets=MONGO_URI=MONGO_URI:latest \
     --region=us-central1
   ```
5. Check `/readyz`. Once traffic transitions cleanly, delete the old database user in MongoDB Atlas.

---

## 3. Incident Response: Groq Outages & Rate Limits (429)

### Built-in System Protections
STEMLY contains automated resilience mechanisms in [`services/llm/client.py`](file:///d:/Hachaton_projects/Stemly_MojivaraCoders/Stemly/backend/services/llm/client.py) and [`routers/scan.py`](file:///d:/Hachaton_projects/Stemly_MojivaraCoders/Stemly/backend/routers/scan.py):
1. **Exponential Backoff:** Automatic retries on HTTP 429 and 503 with jitter and `Retry-After` header adherence.
2. **Deterministic Regex Fallbacks:** If Groq fails after retries, the backend automatically extracts physics/math variables and formula structures using local heuristics, returning `degraded=true`.
3. **Client Degradation Banner:** The Flutter app displays a prominent `DegradedModeBanner` to notify the student that basic formula analysis is active while full AI explanations are temporarily limited.

### Alert Triggers & On-Call Playbook

#### Scenario A: `Groq429RateExceeded` Alert (> 5% requests returning 429)
- **Root Cause:** Exceeding Groq tier rate limits (Requests Per Minute or Tokens Per Minute).
- **Immediate Mitigation:**
  1. Check current Groq limits in [Groq Dashboard Quotas](https://console.groq.com/settings/limits).
  2. Dynamically switch to faster or higher-throughput models without restarting containers:
     ```bash
     # Switch to lower-latency instant model
     gcloud run services update stemly-backend \
       --update-env-vars=GROQ_TEXT_MODEL=llama-3.1-8b-instant \
       --region=us-central1
     ```
  3. Tighten client rate limiting temporarily in [`core/rate_limiter.py`](file:///d:/Hachaton_projects/Stemly_MojivaraCoders/Stemly/backend/core/rate_limiter.py) if unauthenticated or spam scans are detected.

#### Scenario B: Total Groq Cloud Outage (500 / 503 / DNS failures)
- **Root Cause:** Upstream Groq infrastructure disruption.
- **Verification:** Check [Groq Status](https://status.groq.com).
- **Action Plan:**
  1. The system's deterministic fallback will automatically handle scans and notes without throwing 500 errors to users.
  2. Post an in-app notice or status update via Firebase Remote Config (`service_status: degraded`).
  3. If the outage exceeds 1 hour, configure a secondary LLM provider or request priority routing.

---

## 4. Rollback Playbooks

### 4.1 Backend Rollback (Cloud Run) - Under 30 Seconds
Cloud Run preserves every immutable revision created. You can instantly revert 100% of traffic to a previous stable revision with zero downtime.

1. **List Recent Revisions:**
   ```bash
   gcloud run revisions list --service=stemly-backend --region=us-central1 --limit=5
   ```
   *Identify the last known good revision name (e.g. `stemly-backend-00042-xyz`).*

2. **Route 100% of Traffic to Previous Revision:**
   ```bash
   gcloud run services update-traffic stemly-backend \
     --to-revisions=stemly-backend-00042-xyz=100 \
     --region=us-central1
   ```

3. **Verify Rollback:**
   ```bash
   curl -i https://stemly-backend-hash-uc.a.run.app/healthz
   ```
   Check Sentry APM to confirm the error rate drops back below 0.1%.

---

### 4.2 Mobile App Rollback (Google Play Store)
Mobile app updates cannot be instantaneously pulled from user devices, but rogue updates can be immediately mitigated:

1. **Halt Staged Rollout:**
   - In **Google Play Console**, go to **Release** > **Production**.
   - Under the active release, click **Halt Rollout**.
   - This prevents any additional users from downloading the problematic version.

2. **Emergency Hotfix Release:**
   - Revert offending commit in `git`:
     ```bash
     git revert <bad-commit-hash>
     ```
   - Bump `versionCode` in `stemly_app/pubspec.yaml` (e.g., from `1.0.0+4` to `1.0.1+5`).
   - Build and upload emergency bundle:
     ```bash
     flutter build appbundle -t lib/main_prod.dart --flavor prod --release --obfuscate --split-debug-info=build/app/outputs/symbols
     ```
   - Request expedited review in Play Console.

3. **Server-Side Mitigation (Kill-Switch):**
   - If the bug is caused by a backend contract change, the backend router should temporarily support legacy response schemas to keep older client versions functioning.

---

## 5. Escalation Contacts & Dashboard Links

| Resource | Purpose | Link |
| :--- | :--- | :--- |
| **Sentry APM** | Real-time crash reports and telemetry | [Sentry Project Dashboard](https://sentry.io/organizations/stemly/projects/backend/) |
| **Google Cloud Console** | Cloud Run CPU, Memory, Latency & Logs | [Cloud Run Service](https://console.cloud.google.com/run) |
| **MongoDB Atlas** | Database IOPS, CPU & Connection Pool | [Atlas Cluster](https://cloud.mongodb.com) |
| **Groq Status** | API availability & incident feed | [status.groq.com](https://status.groq.com) |
