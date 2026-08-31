# Bayaan

An AI-powered Quran recitation coach and Arabic learning companion. Recite an ayah to receive instant, per-character Tajweed and pronunciation feedback directly on the Uthmani script, compare your recitation against master reciters (e.g. Al-Husary), practice interactive Tajweed quizzes, and progress through structured Arabic foundation lessons.

---

## Current Status & Overview

Bayaan is a complete end-to-end platform featuring a **Flutter** client (with a native **Jetpack Compose** legacy reference), a **Ktor** backend API proxy, a **Modal GPU** ML recitation engine (powered by *quran-muaalem*), and a **Supabase** Postgres + Auth datastore.

```
┌──────────────────────────────────────────────────────────┐
│                   Flutter Client App                     │
│  (Home · Surahs / 604p Mushaf · Stats · Settings · Quiz) │
└────────────────────────────┬─────────────────────────────┘
                             │ JWT + Audio (WAV)
                             ▼
┌──────────────────────────────────────────────────────────┐
│                Ktor Backend API (Render)                 │
│       • JWKS/ES256 Token Verification                    │
│       • REST API: /audio/analyze, /speech/grade, /learn  │
│       • Supabase Postgres Persistence                    │
└────────────────────────────┬─────────────────────────────┘
                             │ Audio + Uthmani Reference
                             ▼
┌──────────────────────────────────────────────────────────┐
│               Muaalem ML Engine (Modal GPU)              │
│       • Multi-task Wav2Vec2 + CTC Decoding               │
│       • Full Ayah & Phrase Speech Grading                │
│       • 10 Sifāt Classification Heads (Ghunnah, etc.)    │
└──────────────────────────────────────────────────────────┘
```

---

## What's Built & Working

### 1. Mobile Client (`flutter/`)
- **Dynamic Theming (`AppPalette`)**: Automatic Dark/Light mode support with bespoke Islamic aesthetics (emerald green, deep slate `#0F172A`, warm gold `#D4AF37`, and cream).
- **Recitation & Tajweed Coach**:
  - Voice recording with real-time waveform visualization.
  - Per-character mistake overlays (Madd lengths, Iqlab, Idgham, Ikhfaa, deletions, additions).
  - Letter Quality (Sifāt) analysis covering 10 phonetic heads with acoustic `[pad]` artifact filtering.
  - Celebration dialogs, streak tracking, and score animations.
- **Audio Comparison with Master Reciters**:
  - Compare recitations against Sheikh Mahmoud Khalil Al-Husary.
  - Dual synchronized waveform players and similarity scoring.
- **Full Mushaf Browser**:
  - Page-faithful 604-page Madani Mushaf with Uthmani script (`AmiriQuran` font).
  - Surah index with search, filters (All / Favorites / Recent), and quick jump.
- **Learn Arabic Track**:
  - Adaptive placement test to determine skill level.
  - Visual curriculum roadmap with interactive nodes, unit progress, and spaced repetition.
  - Multi-format exercises (listen-and-pick, echo practice, discrimination).
- **Quizzes & Tests**:
  - Tajweed tests, Quran trivia, and Islamic general knowledge.
  - Gamified score tracking, streaks, and explanations.
- **Settings & Profile**:
  - Multi-account manager with instant switcher.
  - Customization for Madd recitation styles (Hafs lengths), theme preferences, and offline caching.
  - Supabase Auth (Email + Google OAuth) with guest mode fallback.

### 2. Backend API (`backend/`)
- **Framework**: Kotlin with Ktor, Netty, and Exposed ORM.
- **Authentication**: Zero-roundtrip JWT verification using Supabase JWKS (ES256).
- **Core Endpoints**:
  - `POST /audio/analyze`: Ayah recitation analysis proxying Modal GPU with session & mistake persistence.
  - `POST /speech/grade`: Short phrase and syllable speech grading for Arabic track lessons.
  - `GET /learn/path`, `POST /learn/complete`, `GET /learn/reviews`, `POST /learn/placement`: Full learning track progression and spaced repetition.
  - `GET /progress/summary`, `GET /progress/sessions`: Historical statistics and weak-rule analytics.
- **Database**: Supabase Postgres with connection pooling (HikariCP) and migration scripts (`sql/`).
- **Hosting**: Render Docker deployment.

### 3. ML Recitation Engine (`ml/`)
- **Engine**: Pretrained `quran-muaalem` model on serverless GPU (Modal L4).
- **Endpoints**:
  - `POST /correct`: Ayah analysis against Quran database.
  - `POST /grade-text`: Arbitrary Uthmani text grading.
  - `GET /healthz`: Liveness probe.
- **Sifāt Heads**: 10 phonetic attribute heads (Qalqalah, Ghunnah, Tafkheem/Tarqeeq, Hams/Jahr, Shiddah/Rakhawah, Itbaq, Safeer, Tikraar, Tafashie, Istitala).
- **Acoustic Sanitization**: Filters CTC blank/padding tokens (`[pad]`) to prevent unaligned frames from producing false letter-quality errors.

---

## Repository Structure

```
bayaan/
├── flutter/          # Primary Flutter mobile app (iOS & Android)
├── backend/          # Ktor API proxy & database backend
├── ml/               # Modal serverless GPU deployment script for Muaalem
├── supabase/         # Supabase Edge Functions & SQL migrations
├── android/          # Native Jetpack Compose Android client (reference)
├── docs/             # Architecture, API specifications, and Tajweed definitions
└── scripts/          # Developer tooling & build scripts
```

---

## Quick Start

### 1. Flutter Mobile App
```bash
cd flutter
flutter pub get
flutter run
```
*Run tests:* `flutter test`

### 2. Backend (Ktor)
```bash
cd backend
# Set SUPABASE_DB_URL and SUPABASE_PROJECT_REF in .env
./gradlew run
```
*Run tests:* `./gradlew test`

### 3. ML Service (Modal)
```bash
cd ml
source .venv/bin/activate
modal deploy muaalem_modal.py
```

---

## Documentation

- [Codebase Map](docs/CODEBASE_MAP.md) — Architectural overview and data flow.
- [API Specification](docs/api-spec.md) — Endpoint contracts, request/response schemas, and error codes.
- [Tajweed Rule Definitions](docs/tajweed-rules.md) — Phonetic specifications and detected rules.
- [Graduation Report](docs/GRADUATION_REPORT.md) — Full technical project report.
- [Team Plan](docs/TEAM_PLAN.md) — Roles and working model.

---

## License

Private / Academic project. Quranic scripts and fonts are licensed under their respective open and KFGQPC showcase permissions.
