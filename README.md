# Bayaan — AI-Powered Quran Recitation Coach

Bayaan listens to your Quran recitation and gives you real-time Tajweed feedback through voice. Built for students who want to improve their recitation without always having a teacher present.

---

## Overview

Bayaan combines speech recognition (Groq Whisper), a fine-tuned wav2vec2 Tajweed classifier, and an LLM-driven explanation layer to detect Tajweed errors (e.g., incorrect Madd, missed Ghunnah) as you recite. Feedback is delivered immediately through voice (ElevenLabs TTS) and visual cues in the app.

**Stack:** Kotlin / Jetpack Compose (Android) · Ktor + Supabase Postgres (Backend) · Python / PyTorch (ML) · Firebase Auth · Railway

---

## Team

| Name        | Role                              |
| ----------- | --------------------------------- |
| Abdalrahman | AI & Backend Lead                 |
| Issa        | Android — Screens & Navigation    |
| Ramzi       | Backend + Infra                   |
| Osama       | Android — Voice & Core Recitation |

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
# Fill in only the keys your module needs.
```

### Onboarding (any team member)

```bash
bash scripts/setup.sh
```

The script asks which role you have and prints the next commands for your module.

---

## Branch model

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
