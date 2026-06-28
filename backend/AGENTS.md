# AGENTS.md — Backend Module

You are an AI coding agent operating inside the `/backend` directory of Bayaan. Read [`../AGENTS.md`](../AGENTS.md) first for project-wide rules — this file extends them.

---

## What this module is

A Ktor backend that handles auth, audio analysis, and persistence for the Bayaan Android app:

1. Verify the Supabase JWT sent by the Android app (`Authorization: Bearer`).
2. Accept a recorded ayah over HTTP multipart. Android sends 16kHz mono WAV directly — no server-side conversion needed.
3. Forward the audio to the Muaalem recitation engine (Modal serverless GPU).
4. Persist the session and any detected mistakes to Supabase Postgres (via Exposed + HikariCP).
5. Return the engine's JSON response to the app.

**Auth:** Supabase JWT (HS256), verified locally using `SUPABASE_JWT_SECRET`.  
**Database:** Supabase Postgres — tables `users`, `sessions`, `mistakes`. Direct JDBC connection via HikariCP.  
**ML engine:** `obadx/quran-muaalem` deployed on Modal.  

Deployed on **Render** (Docker, free tier).

---

## Owner

Solo project — Abdalrahman (@Abdalrahman-py).

---

## Tech stack

- **Language:** Kotlin
- **Framework:** Ktor (server + client)
- **Auth:** Supabase JWT verified locally (`ktor-server-auth-jwt`)
- **Database:** Exposed ORM + HikariCP → Supabase Postgres
- **External service:** Muaalem recitation engine on Modal, called over HTTP. URL defaults to the live endpoint in `Routing.kt`, overridable via `MUAALEM_URL` env var.
- **Build:** Gradle (Kotlin DSL)
- **Hosting:** Render

---

## Directory layout

```
backend/
├── src/
│   ├── main/kotlin/com/bayaan/
│   │   ├── Application.kt          Entry point — wires JWT, DB, routes
│   │   ├── Routing.kt              /health, /audio/analyze
│   │   ├── plugins/
│   │   │   └── JwtPlugin.kt        Supabase JWT verification
│   │   ├── routes/
│   │   │   └── AuthRoutes.kt       POST /auth/sync
│   │   └── data/
│   │       ├── DatabaseFactory.kt  HikariCP pool + dbQuery helper
│   │       ├── tables/             Exposed table objects (Users, Sessions, Mistakes)
│   │       └── repositories/       UserRepository, SessionRepository, MistakeRepository
│   └── test/kotlin/                Tests
├── build.gradle.kts
├── Dockerfile                      Multi-stage build (JDK build → JRE runtime)
├── AGENTS.md                       This file
└── CLAUDE.md                       Pointer to this file
```

---

## How to set up locally

```bash
cd backend
./gradlew run
```

Boots the server on `localhost:8080`. Requires three env vars — without them the server will not start:

```
SUPABASE_DB_URL=jdbc:postgresql://db.djcuxaziipgjlmdfkeqz.supabase.co:5432/postgres?user=postgres.djcuxaziipgjlmdfkeqz&password=...
SUPABASE_JWT_SECRET=<from Supabase dashboard → Settings → API → JWT Secret>
SUPABASE_PROJECT_REF=djcuxaziipgjlmdfkeqz
```

`MUAALEM_URL` is optional — the live Modal endpoint is the default.

---

## How to do the work

### Conventions

- **Validate at the boundary.** `/audio/analyze` checks for a present `audio` field and a 10MB size cap before doing anything else.
- **Never log secrets or raw audio bytes.**
- **Coroutines for everything async.** No blocking calls without `Dispatchers.IO`.
- **The engine call needs a long timeout.** Its serverless GPU can cold-start for many seconds; the client is configured with a 60s timeout for this reason — don't shorten it without checking.

### What "good" looks like

- Errors return a stable `{"error": "...", "message": "..."}` shape (see `err()` in `Routing.kt`).
- The engine's own response (success or error) is passed through unchanged when it does respond.
- The deployed service redeploys from a single Dockerfile with no manual config.

### What to avoid

- Don't block the event loop (`Thread.sleep`, blocking IO without a dispatcher).
- Don't store raw audio — it's processed in-memory per request and discarded.
- Don't store raw audio — it's processed in-memory per request and discarded.

---

## How to submit work

```bash
git add backend/
git commit -m "feat(backend): <description>"
```

### Before every commit

```bash
./gradlew build
./gradlew test
git diff --cached | grep -iE "key|secret|password|token"   # must be empty
```

### Commit format

`type(backend): description` — imperative, under 72 chars.

Valid types: `feat`, `fix`, `chore`, `refactor`, `test`, `docs`.

```
feat(backend): add request size limit to /audio/analyze
fix(backend): handle empty audio payload
chore(backend): bump Ktor version
```

---

## Boundaries

You may modify files inside `/backend/`. For changes to `/android/`, `/ml/`, `/docs/`, or root config, say so and let the user decide — there's no other team member to hand off to, so this is a heads-up, not a refusal.

---

## Safe commands

```bash
./gradlew build
./gradlew test
./gradlew run
git status
git diff
git log
```

Avoid `rm -rf`, `git reset --hard`, `git push --force` without explicit confirmation.

---

## Quick reference

| Action | Command |
|---|---|
| Build | `./gradlew build` |
| Test | `./gradlew test` |
| Run locally | `./gradlew run` (port 8080) |
| Commit prefix | `feat(backend):` / `fix(backend):` / etc. |
