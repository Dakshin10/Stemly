# Google Play Store Release & Compliance Checklist

This document details the complete end-to-end release process, Google Play Policy compliance declarations, permissions audit, and Data Safety requirements for **STEMLY** (`com.stemly.app`).

---

## 1. Release Build Instructions

### Prerequisites
- Java JDK 17+
- Android SDK Platform 34 (API 34)
- Production Keystore configured in `stemly_app/android/key.properties` (see [`key.properties.example`](file:///d:/Hachaton_projects/Stemly_MojivaraCoders/Stemly/stemly_app/android/key.properties.example)).

### Generate Release App Bundle (AAB) with Obfuscation
Run the following command from the `stemly_app` directory:

```bash
flutter build appbundle \
  -t lib/main_prod.dart \
  --flavor prod \
  --release \
  --obfuscate \
  --split-debug-info=build/app/outputs/symbols \
  --dart-define=API_BASE_URL=https://stemly-backend-hash-uc.a.run.app \
  --dart-define=SENTRY_DSN=https://YOUR_SENTRY_DSN@o0.ingest.sentry.io/0
```

### Build Artifacts
- **App Bundle:** `stemly_app/build/app/outputs/bundle/prodRelease/app-prod-release.aab`
- **Debug Symbols:** `stemly_app/build/app/outputs/symbols/` (Upload to Google Play Console and Sentry for stack trace de-obfuscation).

---

## 2. Privacy Policy & Disclosures

### Public URL Requirement
Google Play requires a dedicated, publicly accessible URL that does not require login or payment to view:
- **Production URL:** `https://stemly.app/privacy` (or your verified domain).
- **In-App Navigation:** Verified accessible from:
  - Account Screen: [`account_screen.dart`](file:///d:/Hachaton_projects/Stemly_MojivaraCoders/Stemly/stemly_app/lib/screens/account_screen.dart)
  - Settings Screen: [`settings_screen.dart`](file:///d:/Hachaton_projects/Stemly_MojivaraCoders/Stemly/stemly_app/lib/screens/settings_screen.dart)
  - Authentication Screen: [`login_screen.dart`](file:///d:/Hachaton_projects/Stemly_MojivaraCoders/Stemly/stemly_app/lib/screens/login_screen.dart)
  - Dedicated View: [`privacy_policy_screen.dart`](file:///d:/Hachaton_projects/Stemly_MojivaraCoders/Stemly/stemly_app/lib/screens/privacy_policy_screen.dart)

### Required Policy Disclosures
1. **Developer Identity:** MojivaraCoders / Stemly Team.
2. **Data Collected:**
   - Account identifier (Firebase UID, email address).
   - Scanned homework and problem images (processed transiently for OCR and STEM reasoning).
   - Study notes, quiz progress, and parameter states.
   - Diagnostic crash logs and performance metadata (via Sentry SDK).
3. **Third-Party Service Providers:**
   - Firebase Authentication (Google Cloud Identity).
   - Groq AI Cloud (inference processing only, zero data training retention).
   - MongoDB Atlas (encrypted database at rest).
   - Sentry.io (application stability monitoring, PII scrubbed).
4. **Data Retention & Deletion:**
   - Transparent timelines: images are processed transiently in-memory; notes and quizzes remain until user initiates deletion.

---

## 3. Account and Data Deletion Compliance

Google Play requires both **in-app** and **web-based** paths for users to delete their account and associated data.

### In-App Deletion Path
- Location: **Account Screen** > **"Delete Account & All Data"**
- Flow: Triggers a confirmation dialog (`Are you sure? This cannot be undone.`).
- Backend Route: `DELETE /auth/me/data` in [`auth.py`](file:///d:/Hachaton_projects/Stemly_MojivaraCoders/Stemly/backend/auth.py).
- Effect:
  1. Deletes all user documents in MongoDB collections: `scans`, `notes`, `quizzes`, `history`, `daily_usage`.
  2. Clears local device storage: `HistoryStore.clearAll()`.
  3. Deletes Firebase Auth user record and signs out.

### Web-Based Deletion Request URL
- Play Console requires a web form for users who have uninstalled the app:
  - **URL:** `https://stemly.app/request-deletion`
  - Response time commitment: Processed within 7 business days.

---

## 4. Permissions Audit

Stemly strictly adheres to the principle of least privilege:

| Permission | Android Level | Purpose / Rationale | User-Facing Explanation |
| :--- | :--- | :--- | :--- |
| `android.permission.CAMERA` | Dangerous (Runtime) | Capture textbook questions, whiteboard diagrams, and formulas. | Dialog shown before opening camera viewfinder. |
| `android.permission.READ_MEDIA_IMAGES` | Dangerous (Runtime, API 33+) | Select existing STEM problem images from photo gallery. | Scoped to photos only (no video/audio access). |
| `android.permission.READ_EXTERNAL_STORAGE` | Dangerous (API ≤ 32) | Select problem images on legacy Android devices. | Used only with `maxSdkVersion=32`. |
| `android.permission.INTERNET` | Normal | Connect to backend API, Firebase Auth, and Sentry telemetry. | Declared in manifest. |
| `android.permission.ACCESS_NETWORK_STATE` | Normal | Detect offline state to enable cached notes and visualizers. | Declared in manifest. |

### Permissions Explicitly Excluded
- ❌ NO Location permissions (`ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`).
- ❌ NO Audio or Microphone permissions (`RECORD_AUDIO`).
- ❌ NO Background Execution permissions (`REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`).
- ❌ NO Contact or Phone State permissions.

---

## 5. Google Play Console "Data Safety" Form Guide

When filling out the Play Console Data Safety questionnaire, declare the following:

### Section 1: Data Collection & Sharing
- **Does your app collect or share any of the required user data types?** -> **Yes**
- **Is all of the user data collected by your app encrypted in transit?** -> **Yes** (HTTPS / TLS 1.3 enforced everywhere).
- **Do you provide a way for users to request that their data be deleted?** -> **Yes** (Provide URL `https://stemly.app/request-deletion`).

### Section 2: Data Types Breakdown

#### Personal Info
- **Email Address:** Collected for Account Management. Encrypted in transit. User can delete.
- **User IDs (Firebase UID):** Collected for App Functionality and Account Management. Encrypted in transit. User can delete.

#### Photos and Videos
- **Photos:** Collected for App Functionality (analyzing math/science questions). Processed transiently in-memory and deleted after analysis. Not shared with third parties for advertising.

#### App Activity & Performance
- **App Interactions:** Collected for analytics/rate-limiting (daily query bounds).
- **Crash Logs:** Collected via Sentry for App Health and Diagnostics. Scrubbed of authentication tokens and photos.
- **Diagnostics:** Latency and fallback rate metrics.

---

## 6. Pre-Launch Technical Checklist

- [ ] **Android 14/15 Target SDK:** `compileSdk = 35`, `targetSdk = 35` in [`build.gradle.kts`](file:///d:/Hachaton_projects/Stemly_MojivaraCoders/Stemly/stemly_app/android/app/build.gradle.kts).
- [ ] **64-Bit Compliance:** Native libraries built for `arm64-v8a` and `x86_64`.
- [ ] **Code Obfuscation:** R8 enabled in release builds with [`proguard-rules.pro`](file:///d:/Hachaton_projects/Stemly_MojivaraCoders/Stemly/stemly_app/android/app/proguard-rules.pro).
- [ ] **Sentry Symbol Upload:** ProGuard mapping files uploaded to Sentry to preserve stack trace line numbers.
- [ ] **Network Security Config:** Cleartext HTTP traffic blocked in release builds (`android:usesCleartextTraffic="false"`).
- [ ] **Google Play App Signing:** Upload key signed and registered with Play App Signing.
- [ ] **Testing Track:** Release to Internal Testing track first, test on at least 3 distinct physical devices before promoting to Production.
