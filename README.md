# Bayaan — AI-Powered Quran Recitation Coach

Bayaan listens to your Quran recitation and gives you real-time Tajweed feedback through voice. Built for students who want to improve their recitation without always having a teacher present.

---

## Overview

Bayaan combines speech recognition (Groq Whisper), a fine-tuned wav2vec2 Tajweed classifier, and an LLM-driven explanation layer to detect Tajweed errors (e.g., incorrect Madd, missed Ghunnah) as you recite. Feedback is delivered immediately through voice (ElevenLabs TTS) and visual cues in the app.

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
Jetpack Compose app. Records audio, streams it to the backend, and renders real-time Tajweed annotations. Targets Android 8.0+ (API 26+).

### Backend (`/backend`)
Ktor REST API handling audio ingestion, the full ML/LLM/TTS pipeline, and user progress tracking. Deployed on Railway.

### ML (`/ml`)
Tajweed classification model. Takes user recitation audio and outputs rule-violation flags with confidence scores.

---

## Getting started

### Prerequisites
- Android Studio (Ladybug or later)
- JDK 17+ (for the Ktor backend)
- Python 3.11+ (for the ML module)
- A [Supabase](https://supabase.com) project (free tier is enough for development)
- API keys — copy `.env.example` to `.env` and fill in the values

- **Android team:** Android Studio (Ladybug or later)
- **Backend team:** JDK 17+, Gradle 8+
- **ML team:** Python 3.11+, a Kaggle account (for GPU training)
- A Supabase project (shared — get URL/keys from the AI Lead)
- API keys: copy `.env.example` to `.env` and fill the values you need

### Clone

```bash
git clone https://github.com/Abdalrahman-py/bayaan.git
cd bayaan
cp .env.example .env
# Fill in .env, then:
# Android → open android/ in Android Studio
# Backend → cd backend && ./gradlew run
# ML      → cd ml && pip install -r requirements.txt
```

The script asks which role you have and prints the next commands for your module.

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

```
main         production. Tagged releases only.
  ▲
  │  PR
  │
dev          integration. Module branches merge here.
  ▲ ▲ ▲
  │ │ │
android  backend  ml          long-lived module branches. Owners push here.
```

**One branch per module.** Android team pushes to `android`. Backend team pushes to `backend`. ML pushes to `ml`. When work is ready to integrate: open a PR from your module branch → `dev`. Releases go `dev` → `main`.

**Never push to `main` or `dev` directly.**

Full rules, commit format, and PR process: see [`AGENTS.md`](./AGENTS.md).

---

## AI-assisted development

This repo is set up for AI coding agents (Claude Code, Cursor, Codex, Cline, Continue, Aider, etc.). Each module has its own `AGENTS.md` that scopes the AI's knowledge and authority to that module.

### How to use it

1. **Clone the repo and check out your module branch.**
   ```bash
   git clone https://github.com/Abdalrahman-py/bayaan.git
   cd bayaan
   git checkout android        # or backend, or ml
   git pull origin android
   ```

2. **Open *only your module folder* in your AI tool.**
   - Android team → open `bayaan/android/` as the workspace root
   - Backend team → open `bayaan/backend/`
   - ML team → open `bayaan/ml/`

   The agent will read `AGENTS.md` (and `CLAUDE.md` if it uses that) from the folder you opened. It will also read the root `AGENTS.md` for project-wide rules.

3. **Run setup.**
   ```bash
   bash scripts/setup.sh
   ```

4. **Start working.** The agent already knows what your module does, which commands are safe, and where to push work.

### Rules for AI-generated PRs

- The PR template auto-applies — fill it out completely.
- An AI cannot approve its own PR. A human reviewer is always required.
- Module boundaries are enforced by `AGENTS.md`. Agents working in `/android` will refuse to edit `/backend`, and so on.
- PRs target `dev`, never `main`.

---

## Project documents

- [`AGENTS.md`](./AGENTS.md) — Agent rules, branch model, commit format, PR process
- [`docs/architecture.md`](./docs/architecture.md) — System architecture
- [`docs/api-spec.md`](./docs/api-spec.md) — Backend API
- [`docs/tajweed-rules.md`](./docs/tajweed-rules.md) — Tajweed rules in scope for MVP
