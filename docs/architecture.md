# Architecture

## System Overview

Bayaan is a three-tier system: an Android app, a Ktor REST API, and a Python ML service. The Android app never touches the database directly — everything flows through the backend.

```mermaid
graph TB
    subgraph Android["Android App  ·  Issa + Osama"]
        A_UI["Compose UI\n(screens, feedback)\nIssa"]
        A_REC["Audio Recorder\nOsama"]
        A_AUTH["Supabase Auth SDK"]
    end

    subgraph Backend["Ktor Backend on Railway  ·  Abdalrahman + Ramzi"]
        B_MW["Auth Middleware\nverify Supabase JWT\nRamzi"]
        B_EP["POST /audio/analyze\nAbdalrahman"]
        B_ML["ML Service Client\nAbdalrahman"]
        B_PROG["Progress Service\nread/write sessions\nRamzi"]
    end

    subgraph ML["ML Service  ·  Abdalrahman"]
        M["wav2vec2\nTajweed Classifier"]
    end

    subgraph Supabase["Supabase  ·  Ramzi owns"]
        SB_A["Supabase Auth\n(sign-in + JWTs)"]
        T1[("users")]
        T2[("sessions")]
        T3[("violations")]
    end

    A_AUTH -- "1 · sign in" --> SB_A
    SB_A -- "JWT token" --> A_AUTH
    A_REC -- "2 · audio + JWT\n(HTTP multipart)" --> B_MW
    B_MW -- "3 · verify JWT" --> SB_A
    B_MW -- "4 · authenticated request" --> B_EP
    B_EP -- "5 · audio bytes" --> B_ML
    B_ML -- "6 · run inference" --> M
    M -- "violations + confidence" --> B_ML
    B_ML -- "7 · results" --> B_EP
    B_EP -- "8 · save session" --> B_PROG
    B_PROG <-- "read / write" --> T1
    B_PROG <-- "read / write" --> T2
    B_PROG <-- "read / write" --> T3
    B_EP -- "9 · JSON response" --> A_UI
```

---

## Data Flow: Recitation Session (Step by Step)

1. **User opens app** → Supabase Auth SDK checks for a valid session. If none, shows sign-in screen.
2. **User taps Recite** → Android records audio via mic.
3. **Audio sent to backend** → Android POSTs a multipart request to `/audio/analyze`, attaching the audio file and the Supabase JWT in the `Authorization: Bearer <token>` header.
4. **Backend verifies identity** → Ktor's auth middleware validates the JWT against Supabase Auth. If invalid → 401, request stops here.
5. **Audio routed to ML** → The analyze endpoint forwards the audio bytes to the ML service.
6. **ML classifies** → The wav2vec2 model outputs a list of violations: which rule was broken, which word, and a confidence score.
7. **Results saved** → Backend writes a session record and each violation to the Supabase PostgreSQL database.
8. **Response returned** → Backend returns JSON to Android: list of violations with position markers and feedback text.
9. **Feedback rendered** → Android highlights the violated words on screen and plays voice feedback.

---

## Data Flow: First-Time Sign-In

1. Android → Supabase Auth SDK → user signs in (email/password)
2. Supabase issues a JWT + user UUID
3. Android attaches this JWT to every subsequent HTTP request
4. Ktor verifies the JWT on every protected endpoint using Supabase's JWT secret
5. On first request, Ktor creates a row in the `users` table using the UUID from the token

---

## Module Responsibilities

### `/android` — Issa + Osama

| Component | Owner | What it does |
|-----------|-------|-------------|
| Compose screens + navigation | Issa | All UI: recitation screen, progress screen, feedback overlays |
| Audio recording | Osama | Mic capture, audio encoding |
| Supabase Auth SDK | Issa | Sign-in flow, JWT retrieval, session persistence |
| HTTP client (Retrofit/Ktor client) | Osama | Sends audio + JWT to backend, receives results |
| Feedback rendering | Issa | Highlights violations, triggers TTS playback |

### `/backend` — Abdalrahman + Ramzi

| Component | Owner | What it does |
|-----------|-------|-------------|
| Supabase JWT middleware | Ramzi | Validates JWT on every protected route |
| `POST /audio/analyze` endpoint | Abdalrahman | Receives audio, calls ML, formats response |
| ML service client | Abdalrahman | Internal call to the wav2vec2 classifier |
| Database schema (PostgreSQL) | Ramzi | Tables: `users`, `sessions`, `violations` |
| Database access layer (repos) | Ramzi | Kotlin classes that read/write those tables |
| Railway deployment config | Ramzi | Environment variables, health check, deploy hooks |
| `GET /progress` endpoints | Ramzi | Returns session history and per-rule stats |

### `/ml` — Abdalrahman

| Component | Owner | What it does |
|-----------|-------|-------------|
| wav2vec2 fine-tuning | Abdalrahman | Transfer learning on QDAT dataset, Kaggle GPU |
| ONNX export | Abdalrahman | Exports trained model for inference |
| Inference server | Abdalrahman | Loads ONNX model, exposes HTTP endpoint called by backend |
| Per-rule classifiers | Abdalrahman | Binary classifier per Tajweed rule (Ghunnah, Madd) |

---

## Technology Choices

| Layer | Technology | Why |
|-------|-----------|-----|
| Android | Jetpack Compose + Kotlin | Modern Android, reactive UI |
| Backend | Ktor (Kotlin) | Lightweight, coroutine-native, same language as Android |
| Auth + Database | Supabase | One service for both — auth, PostgreSQL, and dashboard. Free tier covers MVP. |
| ML | PyTorch + wav2vec2 | Pre-trained Arabic speech representations, fine-tunable in hours on free GPU |
| ML inference format | ONNX | Runs outside PyTorch, portable |
| Deployment | Railway | Simple Ktor deployment, free tier for prototyping |
| TTS feedback | ElevenLabs | Arabic voice for recitation correction feedback |

---

## Database Schema (MVP)

These tables live inside your Supabase project. Run them in the Supabase SQL editor.

```sql
-- Created automatically by Supabase Auth for each user.
-- auth.users is managed by Supabase — do not create this table yourself.
-- We mirror the fields we need into a public profile table:

CREATE TABLE public.users (
    id          UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email       TEXT,
    created_at  TIMESTAMPTZ DEFAULT now()
);

-- One row per recitation attempt
CREATE TABLE public.sessions (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID REFERENCES public.users(id) ON DELETE CASCADE,
    surah       TEXT NOT NULL,        -- e.g. "al-fatihah"
    verse       INTEGER NOT NULL,     -- verse number (1-indexed)
    created_at  TIMESTAMPTZ DEFAULT now()
);

-- One row per detected violation in a session
CREATE TABLE public.violations (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id   UUID REFERENCES public.sessions(id) ON DELETE CASCADE,
    rule         TEXT NOT NULL,       -- "ghunnah" | "madd"
    word_index   INTEGER NOT NULL,    -- position in verse (0-indexed)
    confidence   FLOAT NOT NULL,      -- model confidence 0.0–1.0
    correct      BOOLEAN NOT NULL     -- true = rule applied correctly, false = violation
);

-- Row Level Security: users can only read their own data
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.violations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users: own rows only" ON public.users
    FOR ALL USING (auth.uid() = id);

CREATE POLICY "sessions: own rows only" ON public.sessions
    FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "violations: own sessions only" ON public.violations
    FOR ALL USING (
        session_id IN (SELECT id FROM public.sessions WHERE user_id = auth.uid())
    );
```

---

## Environment Variables

All secrets live in `.env` (never committed). See `.env.example` for the full list.

| Variable | Used by | Description |
|----------|---------|-------------|
| `SUPABASE_URL` | Backend + Android | Your Supabase project URL |
| `SUPABASE_ANON_KEY` | Android | Public anon key (safe to include in app) |
| `SUPABASE_JWT_SECRET` | Backend | Used by Ktor to verify JWTs without calling Supabase on every request |
| `ML_SERVICE_URL` | Backend | URL of the ML inference server |
| `ELEVENLABS_API_KEY` | Backend | ElevenLabs TTS for feedback audio |
| `RAILWAY_TOKEN` | CI/CD | Railway deploy token |
