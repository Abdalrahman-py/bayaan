# Bayaan — AI-Powered Quran Recitation Coach

Bayaan listens to your Quran recitation and gives you real-time Tajweed feedback through voice. Built for students who want to improve their recitation without always having a teacher present.

---

## Overview

Bayaan uses the off-the-shelf **`obadx/quran-muaalem`** recitation engine (MIT-licensed) to detect Tajweed and recitation mistakes as you recite. You pick an ayah, record, and see mistakes flagged on the script. We build the app around the engine — we don't train our own model. See [`docs/quran-muaalem-decision.md`](docs/quran-muaalem-decision.md).

**Stack:** Kotlin · Jetpack Compose (Android) · Ktor (Backend, thin proxy) · quran-muaalem on a Modal GPU · Supabase (Auth + DB) · Railway

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
Jetpack Compose app. Records an ayah, uploads it to the backend, and highlights flagged mistakes on the script. Targets Android 8.0+ (API 26+).

### Backend (`/backend`)
Ktor REST API. Receives recorded audio, converts it to 16kHz WAV (ffmpeg), forwards it to the quran-muaalem engine, and returns the structured mistake list. Deployed on Railway.

### ML (`/ml`)
Hosts the `obadx/quran-muaalem` recitation engine on a Modal GPU (`muaalem_modal.py`). No model training — the engine is used as-is.

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

## MVP (demo) scope

Per [`docs/quran-muaalem-decision.md`](docs/quran-muaalem-decision.md), the demo is **one loop**: pick an ayah → record → the engine flags mistakes → show them on the script → try again. Surahs: Al-Fatihah and Al-Bayyinah. Accounts, progress tracking, the Arabic-proficiency stage, and spoken feedback are deferred.

| Track | Next step |
|-------|-----------|
| Engine (`/ml`) | ✅ quran-muaalem deployed on Modal — `POST /correct` (see `ml/muaalem_modal.py`) |
| Backend (`/backend`) | Thin Ktor slice: `POST /audio/analyze` → ffmpeg → Modal engine → mistakes JSON |
| Android (`/android`) | Single screen: pick ayah → record → upload → highlight mistakes → retry |

> The older per-person task lists (full auth/sessions/progress backend, 6 screens, training our own model) are pre-pivot. See the `⚠️ OUTDATED` banners in `docs/` for what still applies.

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
