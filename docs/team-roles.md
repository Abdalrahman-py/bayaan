# Team Roles & Ownership

> ⚠️ **Partly outdated (pre-pivot).** The ownership table is still right, but the per-person duties that mention wav2vec2 training, ONNX, the `violations` table, and the Whisper/LLM/TTS pipeline are dead — see [`quran-muaalem-decision.md`](./quran-muaalem-decision.md) (2026-06-23). Recitation checking is now the off-the-shelf `obadx/quran-muaalem` engine.

## Who Owns What

| Name | Module | Primary Responsibilities |
|------|--------|--------------------------|
| Abdalrahman | `/backend` + `/ml` | Backend API endpoints, ML classifier, overall architecture |
| Ramzi | `/backend` | Supabase JWT middleware, database schema, Railway deployment |
| Issa | `/android` | Compose UI screens, navigation, Supabase Auth SDK integration |
| Osama | `/android` | Audio recording, HTTP client, recitation core loop |

---

## Abdalrahman

**Backend:** audio ingestion endpoint (`POST /audio/analyze`), ML service client inside Ktor, response formatting.

**ML:** wav2vec2 model training on QDAT dataset, ONNX export, inference server that the backend calls.

**Oversees:** overall system design, cross-module integration, making sure Android and Backend agree on the API contract.

---

## Ramzi

**This section answers the question: "What is my work specifically?"**

Your work is the infrastructure layer that makes the entire backend secure and persistent. Without it, the API can't verify who's calling it, can't save any data, and can't be deployed.

### Supabase JWT Middleware

Every protected endpoint in Ktor (everything except `/health` and `/surahs`) requires a valid Supabase JWT in the `Authorization` header. You implement the Ktor plugin that:
1. Reads the `Authorization: Bearer <token>` header
2. Verifies the JWT signature using `SUPABASE_JWT_SECRET` (no network call needed — it's a standard HS256 JWT)
3. Extracts the user's UUID and attaches it to the request context
4. Returns 401 if the token is missing, expired, or invalid

The Android app gets this token from Supabase Auth SDK and attaches it to every request. Your middleware is the gatekeeper.

### Database Schema (PostgreSQL via Supabase)

You design and manage the three core tables in PostgreSQL:
- `users` — one row per Supabase Auth user, created on first sign-in
- `sessions` — one row per recitation attempt (which surah, which verse, when)
- `violations` — one row per detected Tajweed mistake in a session

The full schema is in `docs/architecture.md`. You run migrations using either raw SQL in Supabase's dashboard or a migration tool (TBD with Abdalrahman).

### Database Access Layer (Kotlin)

You write the Kotlin repository classes that read and write those tables. These are called by Abdalrahman's endpoint code. Pattern: one repository class per table (`UserRepository`, `SessionRepository`, `ViolationRepository`), each injected as a dependency.

### `POST /auth/sync` Endpoint

When a user signs in for the first time on Android, the app calls this endpoint. You implement it: verify the JWT, extract the Supabase UUID, insert into `public.users` if not already there, return `created: true/false`.

### `GET /progress` Endpoints

You own the three progress endpoints (`/progress`, `/progress/sessions`, `/progress/sessions/{id}`). These query the sessions and violations tables and return structured stats.

### Railway Deployment

You manage the deployment of the Ktor backend to Railway:
- Set up environment variables (SUPABASE_URL, SUPABASE_JWT_SECRET, ML_SERVICE_URL, etc.)
- Configure the health check (`GET /health`)
- Handle deploy hooks and rollbacks if needed

---

## Issa

Compose UI and navigation. You own every screen the user sees: the recitation screen, the progress screen, feedback overlays, and the sign-in screen. You also integrate the Supabase Auth SDK on the Android side — the sign-in flow, getting the JWT token, and passing it to Osama's HTTP client.

---

## Osama

Audio recording and the core recitation loop. You own the mic capture pipeline, audio encoding (WAV/M4A), and the HTTP client that POSTs audio + JWT to `POST /audio/analyze`. You also handle the response from the backend and pass violation data up to Issa's UI layer to render.

---

## How the Modules Connect

```
Android (Issa + Osama)
  ↕  HTTP (audio + JWT)
Backend (Abdalrahman + Ramzi)
  ↕  internal call
ML (Abdalrahman)
```

The Android team and the Backend team agree on the API contract in `docs/api-spec.md`. If you need to change an endpoint shape, open a PR with the doc change first so both sides can update together.

---

## Communication

- Questions about API shape → open a GitHub issue or discuss with Abdalrahman
- Questions about database schema → Ramzi owns it, but loop in Abdalrahman for anything that touches the API response
- Questions about ML model output format → Abdalrahman, since the backend parses that output

---

## Branching

| Who | Branch pattern | PR target |
|-----|---------------|-----------|
| Abdalrahman (backend) | `backend/feature-name` | `dev` |
| Ramzi | `backend/feature-name` | `dev` |
| Issa | `android/feature-name` | `dev` |
| Osama | `android/feature-name` | `dev` |
| Abdalrahman (ML) | `ml/feature-name` | `dev` |

Never push directly to `main`. All PRs merge to `dev` first.
