# 📋 STEMLY UPGRADE QUESTIONNAIRE

> **Instructions:** Please fill in all the `[ YOUR ANSWER ]` fields below.  
> Once complete, I will respond with: **"READY FOR PHASE-WISE UPGRADE PLAN"**

---

## 1. PRODUCT OVERVIEW

| Question | My Observation (from code) | Your Confirmation / Answer |
|----------|---------------------------|---------------=-------------|
| What problem does Stemly solve? | Transform STEM diagrams/problems into interactive simulations, study notes, and quizzes | `[ ✅ Correct / Needs correction: ___ ]` |
| Primary target user (class, age, exam, domain)? | Students (unknown specifics) | `[ YOUR ANSWER ]` |
| App status? | Unknown | `[ Live / Beta / Local-only ]` |

---

## 2. CURRENT FEATURES

| Feature | Code Status | Fully Working? | Notes |
|---------|-------------|----------------|-------|
| Scan (Camera/Gallery → OCR) | ✅ Present | `[ Yes / Partial / No ]` | |
| AI Topic Detection (Gemini Vision) | ✅ Present | `[ Yes / Partial / No ]` | |
| AI Visualiser (CustomPainter) | ✅ Present | `[ Yes / Partial / No ]` | |
| AI Notes Generation | ✅ Present | `[ Yes / Partial / No ]` | |
| AI Quiz Generation | ✅ Present | `[ Yes / Partial / No ]` | |
| AI Chat/Tutor | ✅ Present | `[ Yes / Partial / No ]` | |
| History/Saved Scans | ✅ Present | `[ Yes / Partial / No ]` | |
| Firebase Auth (Google Sign-In) | ✅ Present | `[ Yes / Partial / No ]` | |

**Which features are partial/experimental?**
```
[ YOUR ANSWER ]
```

---

## 3. VISUALIZATION CAPABILITIES

| Subject | Topics I Found in Code | Any Missing Topics? | Production-Ready? |
|---------|------------------------|---------------------|-------------------|
| **Physics** | Projectile Motion, SHM, Optics (Lens), Kinematics, Free Fall | `[ YOUR ANSWER ]` | `[ Yes / No ]` |
| **Chemistry** | Atom Visualization | `[ YOUR ANSWER ]` | `[ Yes / No ]` |
| **Math** | Quadratic/Graph Plotter, Equation Plotter | `[ YOUR ANSWER ]` | `[ Yes / No ]` |
| **Generic** | PhET WebView fallback, Generic Diagram | `[ YOUR ANSWER ]` | `[ Yes / No ]` |

**Which visualizations are prototype vs production-ready?**
```
[ YOUR ANSWER ]
```

---

## 4. RENDERER & ARCHITECTURE

| Question | My Observation | Your Confirmation / Answer |
|----------|---------------|----------------------------|
| Is there a `VisualiserFactory`? | ✅ Yes (`visualiser_factory.dart`) | ✅ Confirmed |
| How are renderers selected? | String matching on `templateId` (e.g., `id.contains("projectile")`) | `[ Plans to change? Y/N ]` |
| Is the app modular or tightly coupled? | Partially modular (Services separated, screens tightly coupled) | `[ Accurate? / Corrections: ___ ]` |
| Any `VisualizationIntent` or engine/registry pattern? | Not found | `[ Exists elsewhere? Y/N ]` |

---

## 5. AI & LLM USAGE

| Service | Model I Found | Confirmed? | Notes |
|---------|---------------|------------|-------|
| Topic Detection | Gemini Vision Pro | `[ ✅ / ❌ ]` | |
| Notes Generation | Gemini (assumed) | `[ ✅ / ❌ / Other: ___ ]` | |
| Quiz Generation | Gemini (assumed) | `[ ✅ / ❌ / Other: ___ ]` | |
| Chat/Tutor | xAI / OpenAI / Groq (user-selectable) | `[ ✅ / ❌ ]` | |
| Visualiser Parameter Adjustment | Gemini | `[ ✅ / ❌ ]` | |
| Image Generation | AIML API (flux/schnell) | `[ ✅ / ❌ ]` | |

**Is AI mandatory for core flows, or can users skip AI features?**
```
[ YOUR ANSWER ]
```

---

## 6. ON-DEVICE AI

| Question | Your Answer |
|----------|-------------|
| Is Ollama / Gemma currently integrated? | `[ Yes / No / Partially ]` |
| If yes, where and how is it used? | `[ YOUR ANSWER ]` |
| If no, what platform constraints exist? | `[ Android RAM limits? Storage? CPU? Target min specs? ]` |
| Interest in on-device AI for offline mode? | `[ High / Medium / Low / Not interested ]` |

---

## 7. BACKEND

| Component | Code Status | Your Notes |
|-----------|-------------|------------|
| Framework | FastAPI ✅ | |
| Database | MongoDB Atlas ✅ | `[ Any issues? ]` |
| Auth | Firebase Auth ✅ | `[ Any issues? ]` |
| Analytics | Firebase Analytics ✅ | `[ What events tracked? ]` |
| Crashlytics | Firebase Crashlytics ✅ | `[ Any major crashes logged? ]` |
| Remote Config | Firebase Remote Config ✅ | `[ Currently used for? ]` |
| Caching | Unknown | `[ Redis / In-memory / None? ]` |
| Hosting/Deployment | Vercel config found | `[ Vercel / Self-hosted / Other? ]` |

---

## 8. PERFORMANCE & STABILITY

| Question | Your Answer |
|----------|-------------|
| Target devices (low-end / mid / high-end)? | `[ YOUR ANSWER ]` |
| Minimum Android version supported? | `[ YOUR ANSWER ]` |
| Known crashes or bottlenecks? | `[ YOUR ANSWER ]` |
| Offline support status? | `[ Full / Partial / None ]` |
| Current APK size? | `[ YOUR ANSWER ]` |

---

## 9. UX & FLOW

| Question | My Observation | Your Confirmation / Answer |
|----------|---------------|----------------------------|
| Current user journey | Splash → Login → Main (Scan/History) → ScanResult → Visualiser/Notes/Quiz | `[ ✅ Correct / Corrections: ___ ]` |
| Onboarding/Tutorial present? | Splash screen only, no tutorial | `[ ✅ / Actually has onboarding ]` |
| Manual topic selection available? | Unknown | `[ Yes / No / Planned ]` |
| Dark mode support? | Appears present | `[ ✅ Working / ❌ Broken / Partial ]` |

---

## 10. DATA & ANALYTICS

| Question | Your Answer |
|----------|-------------|
| Are users tracked (Firebase Analytics)? | `[ Yes / No ]` |
| What events are currently tracked? | `[ YOUR ANSWER ]` |
| DAU / Sessions / Retention metrics available? | `[ Yes / No / Not checked ]` |
| Feedback collection present in app? | `[ Yes / No ]` |
| Any crash reports or user complaints logged? | `[ YOUR ANSWER ]` |

---

## 11. DEPLOYMENT

| Question | Your Answer |
|----------|-------------|
| Platforms supported? | `[ Android only / Android + iOS / Web planned? ]` |
| Play Store status? | `[ Not submitted / Rejected / In review / Live ]` |
| If rejected, reason? | `[ YOUR ANSWER ]` |
| Any compliance issues known? | `[ Privacy policy / Data collection / Permissions / None ]` |
| App Store (iOS) planned? | `[ Yes / No / Later ]` |

---

## 12. MONETIZATION & FUNDING

| Question | Your Answer |
|----------|-------------|
| Monetization model planned? | `[ Free / Freemium / Subscription / Ads / None yet ]` |
| Any grants or hackathons applied/won? | `[ YOUR ANSWER ]` |
| Any incubators or accelerators applied? | `[ YOUR ANSWER ]` |
| Funding goal? | `[ Internship demo / Startup MVP / Long-term company / Academic project ]` |
| Revenue target (if any)? | `[ YOUR ANSWER ]` |

---

## 13. TEAM & TIME

| Question | My Observation (from README) | Your Update |
|----------|------------------------------|-------------|
| Team size | 4 members | `[ Still 4? / Changed to: ___ ]` |
| P Dakshin Raj | Frontend & Flutter Lead | `[ Still active? ]` |
| SH Nihil Mukkesh | Backend & AI Lead | `[ Still active? ]` |
| SHRE RAAM P J | Machine Learning | `[ Still active? ]` |
| Vibin Ragav S | UI/UX & Frontend | `[ Still active? ]` |
| Hours/week available for development? | Unknown | `[ YOUR ANSWER ]` |
| Short-term goal (next 3 months)? | Unknown | `[ YOUR ANSWER ]` |

---

## 14. ADDITIONAL CONTEXT (Optional)

**Anything else I should know before proposing the upgrade plan?**
```
[ YOUR ANSWER - Any priorities, constraints, deadlines, inspirations, competitors, etc. ]
```

---

## ✅ SUBMISSION

Once you have filled in all sections above, reply to me and I will confirm:

> **"READY FOR PHASE-WISE UPGRADE PLAN"**
