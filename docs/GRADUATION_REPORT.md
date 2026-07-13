# Bayaan — AI-Powered Quran Recitation Coach

## Graduation Project Report

**Student:** Abdalrahman (Abdalrahman-py)  
**Program:** Mobile Development, UCAS Gaza  
**Date:** July 2026  
**Supervisor:** ________  

---

## Abstract

Bayaan is an AI-powered Quran recitation coach for Android that listens to a student's recitation and flags Tajweed and pronunciation mistakes directly on the Arabic script. The system combines a page-faithful Quran mushaf renderer (all 604 pages, RTL pager), a pretrained recitation-analysis engine deployed on serverless GPU infrastructure, a thin Ktor backend for authentication and persistence, and a guided learning track with speech grading, XP, streaks, and spaced repetition. The Arabic learning track takes a learner from zero to reading Quranic Arabic through audio-first lessons with real-time phoneme-level pronunciation feedback. This report covers the full system architecture, technical implementation, and learning methodology.

**Keywords:** Quran recitation, Tajweed, speech grading, Arabic NLP, Android, Kotlin, Jetpack Compose, Ktor, serverless GPU, Muaalem

---

## 1. Introduction

### 1.1 Problem Statement

Learning to recite the Quran correctly requires a qualified teacher who can hear mistakes in real time and correct them. For millions of Muslims worldwide — especially in Gaza and other regions with limited access to qualified instructors — this creates a significant barrier. Existing solutions fall into two categories: (1) audio playback apps with no feedback, and (2) live tutoring platforms that require human teachers and scheduling.

Bayaan addresses this gap by bringing AI-powered recitation analysis to a smartphone app. The student picks an ayah, records themselves, and the system highlights exactly which letters and which Tajweed rules were mispronounced — no teacher required.

### 1.2 Project Scope

The project delivers three integrated systems:

1. **Android app** — Jetpack Compose UI with page-faithful mushaf, recording, mistake visualization, and a guided learning track
2. **Ktor backend** — authentication (Supabase JWT), audio forwarding, progress/XP/streak persistence
3. **ML engine** — pretrained Muaalem model on Modal serverless GPU, with the novel addition of arbitrary-text grading for syllable-level pronunciation feedback

### 1.3 Contributions

- Full end-to-end recitation analysis loop on mobile
- A page-faithful QCF glyph-font mushaf renderer (all 604 pages bundled)
- Tiered speech grading: recognition exercises → echo pronunciation → full ayah analysis
- A guided Arabic curriculum (3 authored units, 17 lessons) with phoneme-level feedback
- Learning gamification: XP, streaks, spaced repetition review queue

---

## 2. Background

### 2.1 Tajweed Rules

Tajweed is the set of rules governing Quranic recitation. The system detects and surfaces the following categories:

| Category | Rules | Detection Method |
|---|---|---|
| Phoneme errors | Consonant swaps, vowel swaps, insertions, deletions | Phoneme sequence alignment (reference vs predicted) |
| Length errors | Madd (natural, connected, separated) | Expected vs predicted duration (harakat counts) |
| Letter characteristics | Ghunnah (nasalization), Qalqalah (echo-bounce), Tafkheem (heavy/light), Hams/Jahr (breath/voice), and 6 others | Multi-level CTC classification heads on the raw waveform |

The engine produces structured JSON with character-position ranges, enabling pixel-accurate highlighting on the Arabic script.

### 2.2 Related Work

- **Tarteel** — AI Quran companion with mistake detection; closed-source
- **Quranic** — Arabic learning app with recognition exercises but no speech grading
- **Pingo AI** — language tutoring with LLM-driven conversation loops; Bayaan adapts this pattern to scripted Quranic Arabic lessons
- **QCF mushaf renderers** — Quran.com and similar sites use QCF fonts; Bayaan bundles them natively for offline use

### 2.3 Technology Choices

| Component | Technology | Rationale |
|---|---|---|
| Android UI | Kotlin, Jetpack Compose, Material 3 | Modern declarative UI, RTL support, built-in animation |
| Backend | Ktor (Kotlin) | Same language as Android, thin proxy architecture |
| Auth | Supabase Auth + JWKS/ES256 verification | Drop-in email auth, local JWT verification (no per-request roundtrip) |
| Database | Supabase Postgres + Exposed ORM | Managed Postgres, HikariCP connection pool |
| ML Engine | Muaalem (wav2vec2-based) on Modal | MIT-licensed, phoneme-level + sifat classification |
| Speech Grading | Custom normalizer on engine output | Edge-insertion tolerance, minimal-pair mapping, crash recovery |
| Content Pipeline | Python scripts + JSON schemas | Validated curriculum authoring, TTS placeholder generation |

---

## 3. System Architecture

### 3.1 High-Level Architecture

```
[Android App] ──Bearer JWT + audio──▶ [Ktor Backend (Render)]
     ▲                                      │
     │                          forward audio │ verify locally (JWKS)
     │                                      ▼
     │                           [Muaalem Engine (Modal GPU)]
     │                                      │
     │    JSON: errors + sifat_errors       │
     +──────────────────────────────────────+
                                            │
                              persist session + mistakes
                                            ▼
                                [Supabase Postgres]
```

### 3.2 Three-Box Design

**Box 1 — Android:** Records 16kHz mono PCM via AudioRecord, builds WAV in-memory (no file I/O), uploads multipart to backend. Renders page-faithful mushaf using QCF v4 glyph fonts (each of the 604 pages has its own font with Private Use Area glyph codes). The lesson player drives a state machine over exercise types.

**Box 2 — Ktor Backend:** Verifies Supabase JWTs locally using the JWKS/ES256 public key (cached 24h). Forwards audio to the engine, persists results to Postgres. All learn-track endpoints (`/learn/path`, `/learn/complete`, `/learn/reviews`, `/learn/placement`) derive lesson unlock status server-side from a single global curriculum chain.

**Box 3 — Muaalem Engine:** Runs `quran-muaalem` (MIT-licensed, wav2vec2 multi-level CTC) on Modal L4 GPU. The `/correct` endpoint grades full ayat against the Quran database. The novel `/grade-text` endpoint (built for this project) grades arbitrary Uthmani text — enabling syllable-level pronunciation feedback for the Arabic learning track. Scale-to-zero keeps costs at $0 when idle (~24s cold start, ~1.7s warm).

### 3.3 Data Flow — One Recitation

1. User picks an ayah from the mushaf browser
2. Phone records mic → 16kHz mono PCM → WAV in memory
3. Phone POSTs `multipart/form-data` to `/audio/analyze` with JWT
4. Backend verifies JWT signature locally, forwards WAV to Modal
5. Engine runs phoneme alignment + sifat classification, returns structured JSON
6. Backend persists one `sessions` row + one `mistakes` row per error
7. Phone renders per-character highlights using `AnnotatedString` with character ranges from the engine

### 3.4 Speech Grading Architecture (Novel)

The Arabic learning track requires grading short syllables (e.g., بَا, بِسْمِ) — not full ayat. We introduced:

1. **Modal `/grade-text` endpoint:** Accepts arbitrary Uthmani text instead of sura/aya lookup. Same phonetizer + model pipeline as `/correct`.
2. **Ktor `POST /speech/grade`:** Forwards to Modal, then applies the grading policy normalizer:
   - Drops edge-insertion errors (breath/noise at clip boundaries)
   - Maps single minor error → `retry` verdict (never `fail`)
   - Catches decode crashes → `retry` with structured response (never 500)
   - Maps minimal pairs to specific feedback keys (`swap_sad_seen`, `swap_taa_ta`, etc.)
3. **Grading policy** validated by Spike S1: 43 clips across 2 speakers, ~90% correct-clip clean rate and 94% wrong-clip detection with exact phoneme-level localization.

---

## 4. Implementation

### 4.1 Android App

**Technology:** Kotlin, Jetpack Compose, Material 3, Ktor Client (CIO engine)

**Screens:**
- Splash → Onboarding (first launch) → Login/Signup (Supabase Auth)
- 4-tab bottom nav: Learn | Qur'an | Progress | Profile
- Drill-in: MushafPager → RecitationScreen, LessonScreen

**Key Components:**

| Component | Purpose | Lines |
|---|---|---|
| `MushafPagerScreen.kt` + `QcfRepository.kt` | Page-faithful mushaf (604 pages, QCF v4 fonts) | ~700 |
| `RecitationScreen.kt` + `RecitationViewModel.kt` | Record → upload → highlight loop | ~500 |
| `VerseText.kt` | Per-character AnnotatedString highlighting | ~200 |
| `LearnScreen.kt` | Curriculum roadmap with animated nodes | ~270 |
| `LessonScreen.kt` + `LessonViewModel.kt` | Lesson player state machine | ~550 |
| Exercise composables (6 types) | LISTEN_PICK, READ_PICK, DISCRIMINATE, ODD_ONE_OUT, ECHO, BUILD_WORD | ~550 |
| `SpeechGrade.kt` / `LearnApi.kt` | API client for all learn endpoints | ~350 |
| `ScoreRing.kt`, `Confetti.kt`, `Motion.kt` | Design system (Canvas animations) | ~240 |

**Design highlights:**
- Score ring sweeps 0→target with 700ms animation
- Particle-canvas confetti (no library) on lesson/unit completion
- Motion vocabulary: 120ms correct-pop, gentle 3px wrong-shake, nothing over 400ms
- Haptics + sound effects on every interaction state
- RTL-first typography with Amiri font, color-accented harakat

**Authentication:**
- Supabase Kotlin SDK with automatic session persistence
- AuthViewModel: `Checking → LoggedOut / LoggedIn` state machine
- Token persisted to SharedPreferences for all API calls
- Friendly error messages (wall-of-text Supabase exceptions → short human messages)

### 4.2 Backend

**Technology:** Kotlin, Ktor Server, Exposed ORM, HikariCP, Supabase Postgres

**Endpoints:**

| Route | Auth | Purpose |
|---|---|---|
| `GET /health` | No | Render liveness ping |
| `GET /surahs` | No | Static surah list |
| `POST /auth/sync` | Yes | Upsert user row (mirrors Supabase auth) |
| `POST /audio/analyze` | Yes | Forward audio to engine, persist results |
| `POST /speech/grade` | Yes | Grade arbitrary text (echo exercises) |
| `GET /learn/path` | Yes | Full curriculum tree with per-user status |
| `POST /learn/complete` | Yes | Record attempt, award XP, bump streak, seed SRS |
| `GET /learn/reviews` | Yes | Due spaced-repetition items |
| `POST /learn/reviews/{id}/result` | Yes | Grade review, re-schedule on SM-2-lite ladder |
| `POST /learn/placement` | Yes | Adaptive placement test scoring |
| `GET /progress` | Yes | Aggregate stats, mistake breakdown |
| `GET /progress/sessions` | Yes | Paginated session history |

**Database Schema:**

```
users → sessions → mistakes + sifat_mistakes
users → profiles, placement_results
       → lesson_progress (per-lesson status, best_score, attempts)
       → lesson_attempts (per-attempt audit log)
       → review_items (SM-2-lite spaced repetition: [1,3,7,21] day intervals)
       → xp_events (audit log)
```

**Auth Architecture:** Supabase JWT verified locally via JWKS/ES256. Backend fetches public keys from `https://<ref>.supabase.co/auth/v1/.well-known/jwks.json`, caches 24h, and verifies signature + issuer + audience without any per-request network roundtrip. Uses `ktor-server-auth-jwt`.

### 4.3 ML Engine

**Deployment:** `ml/muaalem_modal.py` — Modal serverless GPU (L4), Python 3.11

**Endpoints:**
- `POST /correct` — audio + sura/aya → structured phoneme/sifat errors
- `POST /grade-text` — audio + arbitrary Uthmani reference → same error structure

**Pipeline:**
1. Decode upload → 16kHz mono float32 (librosa + soundfile)
2. Phonetize reference text (quran_phonetizer, Hafs rewaya, madd attribute config)
3. Run Muaalem model → predicted phoneme sequence + 10 sifat classification heads
4. Diff reference vs predicted (explain_error + expalin_sifat)
5. Return structured JSON with character positions, expected/predicted phonemes, tajweed rules, and confidence scores

### 4.4 Content Pipeline

The curriculum is authored as versioned JSON (`content/curriculum.json` + per-lesson files), validated at build time by `scripts/build_content.py`, and bundled as Android assets. This means:

- Content changes don't require a backend deploy
- Schema validation catches errors before they reach the app
- TTS audio placeholders enable development before human recording

**Authored:** Units 1–3 (The Letters, Hearing Differences, Putting It Together) — 17 lessons with recognition + echo exercises. Reference text follows the waqf-aware convention (madd-/sukoon-final targets) validated by Spike S1.

---

## 5. Learning Track Design

### 5.1 Arabic Track (Units 1–8)

| Unit | Lessons | Focus |
|---|---|---|
| 1 — The Letters | 6 | Visual families, sound per letter with all shapes |
| 2 — Hearing the Difference | 5 | Minimal pairs (ص/س, ط/ت, ح/ه, ق/ك) |
| 3 — Putting It Together | 6 | CV syllables, short words, echo production |
| 4–6 | 14 | Harakat mastery, joined forms, reading short ayat |
| 7–8 | 11 | Real Quran reading, Tajweed introduction, graduation |

### 5.2 Exercise Types

| Type | Tier | Description |
|---|---|---|
| LISTEN_PICK | 0 | Hear a sound, tap the matching letter |
| READ_PICK | 0 | See a letter, tap the matching audio |
| DISCRIMINATE | 0 | Hear a sound, pick from 2 options |
| ODD_ONE_OUT | 0 | Tap the letter that doesn't belong |
| CONNECT | 0 | Tap the correct joined form |
| BUILD_WORD | 0 | Drag glyph pieces to form a word |
| ECHO | 1 | Hear a syllable, record yourself, get phoneme feedback |
| READ_ALOUD_SYLLABLE | 1 | Read a syllable aloud, get graded |

### 5.3 Gamification

- **XP:** Base XP per lesson (10) / checkpoint (20), bonus per first-try correct item
- **Streaks:** UTC day boundary, increments on first completion each day
- **Spaced Repetition:** SM-2-lite ladder [1, 3, 7, 21] days for missed items
- **Placement Test:** Adaptive ladder (12–18 items), starts at Unit 3 difficulty

### 5.4 Tajweed Track (Planned)

7 modules (T1–T7) covering Ghunnah, Noon Sakinah rules, Qalqalah, Madd family, Tafkheem, Sifat mastery, and Waqf. Each module: RuleIntroScreen → recite curated ayah → rule-focused result → pass after 2 clean readings. Adaptive lesson selection by weak-rule overlap. All backend infrastructure (sifat persistence, progress breakdowns) is in place; content authoring is the remaining work.

---

## 6. Testing & Verification

### 6.1 Speech Grading (Spike S1)

- 43 phone-mic clips, 2 speakers, 16kHz mono WAV
- Targets: CV syllables, minimal pairs, real words
- Results: ~90% correct clips graded clean, ~94% wrong clips flagged at the exact planted phoneme
- Crash rate: 1/43 (known upstream decode bug → handled with retry verdict)
- Waqf convention fix identified (madd-/sukoon-final targets avoid false positives)

### 6.2 Backend Tests

- JWT verification: real JWKS/ES256 with throwaway EC keypair
- Speech grade normalizer: 6 unit tests (edge insertion, minimal pair mapping, pass/retry/fail verdicts)
- Speech grade route: 4 integration tests (missing audio, decode crash, happy path, engine unreachable)

### 6.3 Device Verification

- Debug APK built and deployed to Redmi Note 10 Pro
- App launches, Supabase session loaded, login flow functional
- Curriculum loads from bundled assets on Learn tab
- Lesson player renders all exercise types with placeholder audio

---

## 7. Deployment & Infrastructure

| Service | Provider | Tier | Notes |
|---|---|---|---|
| Backend | Render | Free (Docker) | Auto-deploy from git push; sleeps after inactivity (~30s cold start) |
| Database + Auth | Supabase | Free | Managed Postgres + email auth |
| ML Engine | Modal | Pay-per-use (L4 GPU) | Scale-to-zero ($0 idle), ~24s cold start, ~1.7s warm |
| APK Distribution | Sideloaded | — | 73MB debug APK; ~113MB of QCF fonts bundled |

---

## 8. Limitations & Future Work

### 8.1 Current Limitations

- **Letter audio quality:** Placeholder 440Hz tones used for 49 letter clips; human qari recording (~250 clips) is a pending dependency
- **Beginner speech retest:** Spike S1 used native Arabic speakers; a non-native beginner retest is required before full deployment
- **QCF font license:** Showcase-only; KFGQPC permission needed for public release
- **Serverless cold starts:** Render free tier + Modal scale-to-zero = ~60s stacked cold start on first request
- **Tajweed guided lessons:** Curriculum designed but not authored; backend ready

### 8.2 Future Work

| Priority | Feature | Effort |
|---|---|---|
| P0 | Qari letter audio recording | ~1 week |
| P1 | Non-native beginner retest (Spike S1 prerequisite) | ~2 days |
| P1 | Units 4–8 lesson content | ~2 weeks |
| P2 | Tajweed T1 (Ghunnah) guided lesson | ~3 days |
| P2 | LLM tutor integration (Claude Haiku for stuck-help) | ~1 week |
| P3 | Production hardening (paid infra, Play Store, privacy policy) | ~2 weeks |
| P3 | iOS / Kotlin Multiplatform | ~2 months |

---

## 9. Conclusion

Bayaan demonstrates a complete AI-powered recitation coaching system — from page-faithful mushaf rendering to phoneme-level speech grading to a guided learning curriculum. The system architecture is intentionally thin: the intelligence lives in a rented ML model, the backend is a verifying proxy, and the curriculum is versioned static content. This keeps the system cheap to run, easy to reason about, and independently verifiable at every layer.

The novel contributions include the tiered speech grading strategy (recognition → echo → full ayah), the `/grade-text` endpoint enabling syllabus-level pronunciation feedback with zero new ML training, and the integrated learning gamification (XP, streaks, spaced repetition) that makes the experience feel like a product rather than a prototype.

---

## References

1. `quran-muaalem` — https://github.com/obadx/quran-muaalem (MIT license)
2. `quran-transcript` — https://github.com/obadx/quran-transcript
3. QCF v4 mushaf data — https://github.com/quran/quran-qcf4 (MIT license for data)
4. Supabase Auth with JWKS — https://supabase.com/docs/guides/auth/jwts
5. Modal serverless GPU — https://modal.com
6. Pingo AI language tutor — https://pingo.ai (product model reference)
