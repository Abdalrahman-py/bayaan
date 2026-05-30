# Bayaan — AI-Powered Quran Recitation Coach

Bayaan listens to your Quran recitation and gives you real-time Tajweed feedback through voice. Built for students who want to improve their recitation without always having a teacher present.

---

## Overview

Bayaan uses a combination of speech recognition, phonetic analysis, and a fine-tuned ML model to detect Tajweed errors (e.g., incorrect Madd, missed Ghunnah, wrong Qalqalah) as you recite. Feedback is delivered immediately through voice and visual cues in the app.

**Stack:** Kotlin · Jetpack Compose (Android) · Ktor (Backend) · PyTorch/wav2vec2 (ML) · Supabase (Auth + DB) · Railway

---

## Team

| Name | Module | Role |
|------|--------|------|
| Abdalrahman | `/backend` + `/ml` | Backend API, ML classifier, architecture |
| Ramzi | `/backend` | Supabase JWT middleware, database schema, Railway deployment |
| Issa | `/android` | Compose UI, navigation, Supabase Auth SDK |
| Osama | `/android` | Audio recording, HTTP client, recitation loop |

---

## Documentation

| Doc | What's in it |
|-----|-------------|
| [Architecture](docs/architecture.md) | System diagram, data flows, database schema, env vars |
| [API Spec](docs/api-spec.md) | All backend endpoints with request/response shapes |
| [Team Roles](docs/team-roles.md) | Who owns what — especially useful for new team members |
| [Tajweed Rules](docs/tajweed-rules.md) | The rules Bayaan teaches: Ghunnah + Madd, with examples |

---

## Modules

### Android (`/android`)
Jetpack Compose app. Records audio, streams it to the backend, and renders real-time Tajweed annotations. Targets Android 8.0+.

### Backend (`/backend`)
REST API handling audio ingestion, routing to the ML model, user progress tracking, and response formatting. Deployed on Railway.

### ML (`/ml`)
Tajweed classification model. Takes phoneme sequences extracted from audio and outputs rule violations with confidence scores.

---

## Getting Started

### Prerequisites
- Android Studio (Ladybug or later)
- JDK 17+ (for the Ktor backend)
- Python 3.11+ (for the ML module)
- A [Supabase](https://supabase.com) project (free tier is enough for development)
- API keys — copy `.env.example` to `.env` and fill in the values

### Clone & run

```bash
git clone https://github.com/abdalrahman-py/bayaan.git
cd bayaan
cp .env.example .env
# Fill in .env, then:
# Android → open android/ in Android Studio
# Backend → cd backend && ./gradlew run
# ML      → cd ml && pip install -r requirements.txt
```

---

## MVP Task List

These are the foundational tasks each team member needs to complete to get to a working end-to-end demo. Start from the top of your list — later tasks depend on earlier ones.

### Ramzi — Backend Infrastructure
- [ ] Create Supabase project, run the schema SQL from `docs/architecture.md`
- [ ] Set up `.env` with `SUPABASE_URL`, `SUPABASE_JWT_SECRET`, `DATABASE_URL`
- [ ] Scaffold Ktor project in `backend/src` (Application.kt, routing, DI)
- [ ] Implement Supabase JWT verification middleware
- [ ] Implement `POST /auth/sync` endpoint
- [ ] Write `UserRepository`, `SessionRepository`, `ViolationRepository`
- [ ] Implement `GET /progress` and `GET /progress/sessions` endpoints
- [ ] Deploy to Railway, confirm `/health` returns 200

### Abdalrahman — Backend API + ML
- [ ] Implement `POST /audio/analyze` endpoint (can return mock violations first)
- [ ] Set up Python inference server in `ml/` that loads an ONNX model
- [ ] Download QDAT dataset, run wav2vec2 fine-tuning on Kaggle (Ghunnah first)
- [ ] Export trained model to ONNX, wire it into the inference server
- [ ] Connect `POST /audio/analyze` to the real ML inference server
- [ ] Repeat fine-tuning for Madd rule

### Issa — Android UI
- [ ] Add Supabase Android SDK dependency, configure with project URL + anon key
- [ ] Build sign-in screen (email + password, calls Supabase Auth)
- [ ] Build recitation screen scaffold (verse display, record button, loading state)
- [ ] Build violation feedback overlay (highlights words, shows rule name)
- [ ] Build progress screen (session list, per-rule accuracy)
- [ ] Wire Supabase Auth session so JWT is attached to every HTTP request

### Osama — Android Audio + Networking
- [ ] Implement audio recording with `MediaRecorder` (output: M4A or WAV)
- [ ] Add HTTP client (Retrofit or Ktor client), configure base URL from `.env`
- [ ] Implement `POST /audio/analyze` call with audio file + JWT header
- [ ] Parse violation response and pass data to Issa's UI layer
- [ ] Test end-to-end: record → send → receive violations → render

---

## Branch Strategy

| Branch | Purpose |
|--------|---------|
| `main` | Stable, production-ready |
| `dev`  | Active development, PRs merge here first |

All changes go through a PR. See `.github/PULL_REQUEST_TEMPLATE.md`.

---

## AI-Assisted Development

Bayaan is set up as a Claude Code agentic workspace. Each module has its own `CLAUDE.md` that scopes the AI's knowledge and authority to that module.

### How to use Claude Code

1. **Clone the repo**
   ```bash
   git clone https://github.com/Abdalrahman-py/bayaan.git
   cd bayaan
   ```

2. **Open your module in Claude Code** — open ONLY your module directory, not the repo root:
   - Android team → `claude /path/to/bayaan/android`
   - Backend team → `claude /path/to/bayaan/backend`
   - ML team      → `claude /path/to/bayaan/ml`

3. **Run setup**
   ```bash
   bash scripts/setup.sh
   ```

4. **Start working** — The AI already knows what your module does, which commands are safe, and where to push work.

### Rules for AI-generated PRs

- Always use the PR template (auto-applied by GitHub)
- AI cannot approve its own PRs — a human reviewer is required
- Module boundaries are enforced: AI opened in `/android` cannot edit `/backend`
