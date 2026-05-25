# Bayaan — AI-Powered Quran Recitation Coach

Bayaan listens to your Quran recitation and gives you real-time Tajweed feedback through voice. Built for students who want to improve their recitation without always having a teacher present.

---

## Overview

Bayaan uses a combination of speech recognition, phonetic analysis, and a fine-tuned ML model to detect Tajweed errors (e.g., incorrect Madd, missed Ghunnah, wrong Qalqalah) as you recite. Feedback is delivered immediately through voice and visual cues in the app.

**Stack:** Kotlin (Android) · Node.js/Python (Backend) · PyTorch (ML) · Supabase · Firebase · Railway

---

## Team

| Name | Role |
|------|------|
| TBD  | Android |
| TBD  | Backend |
| TBD  | ML |

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
- Node.js 20+ or Python 3.11+
- A Supabase project
- API keys — copy `.env.example` to `.env` and fill in the values

### Clone & run

```bash
git clone https://github.com/abdalrahman-py/bayaan.git
cd bayaan
cp .env.example .env
# Fill in .env, then:
# Android → open android/ in Android Studio
# Backend → cd backend && npm install && npm run dev
# ML      → cd ml && pip install -r requirements.txt
```

---

## Branch Strategy

| Branch | Purpose |
|--------|---------|
| `main` | Stable, production-ready |
| `dev`  | Active development, PRs merge here first |

All changes go through a PR. See `.github/PULL_REQUEST_TEMPLATE.md`.
