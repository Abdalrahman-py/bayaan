# AGENTS.md — Backend Module

You are an AI coding agent operating inside the `/backend` directory of Bayaan. Read [`../AGENTS.md`](../AGENTS.md) first for project-wide rules — this file extends them.

---

## What this module is

A thin Ktor proxy in front of a third-party recitation-analysis engine:

1. Accept a recorded ayah from the Android app over HTTP (multipart).
2. Convert it to 16kHz mono WAV via `ffmpeg`.
3. Forward it to the recitation engine (an external pretrained model on a serverless GPU).
4. Pipe the engine's response straight back to the app — no interpretation, no persistence.

There is no auth, no database, and no STT/LLM/TTS. The whole implementation is `Application.kt` + `Routing.kt`. An earlier draft of this file planned a much larger system (Supabase auth/DB, Whisper, LLM, TTS, WebSocket streaming) — none of that was built; this file now describes what actually exists.

Deployed on **Render** (Docker, free tier), not Railway.

---

## Owner

Solo project — Abdalrahman (@Abdalrahman-py).

---

## Tech stack

- **Language:** Kotlin
- **Framework:** Ktor (server + client)
- **Audio conversion:** shells out to `ffmpeg` (must be on `PATH` — the Dockerfile installs it)
- **External service:** the recitation engine, called over HTTP. URL has a working default in `Routing.kt`, overridable via env var for local/staging swaps.
- **Build:** Gradle (Kotlin DSL)
- **Hosting:** Render

---

## Directory layout

```
backend/
├── src/
│   ├── main/kotlin/com/bayaan/
│   │   ├── Application.kt   Entry point (EngineMain)
│   │   └── Routing.kt       /health, /audio/analyze, ffmpeg conversion
│   └── test/kotlin/         Tests
├── build.gradle.kts
├── Dockerfile                Multi-stage build, installs ffmpeg in the runtime image
├── AGENTS.md                 This file
└── CLAUDE.md                 Pointer to this file
```

---

## How to set up locally

```bash
cd backend
./gradlew run
```

Boots the server on `localhost:8080`. No `.env` is required to run it — the recitation engine's default URL is baked in.

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
- Don't add auth, a database, or new external services without a real need; this module is intentionally minimal right now.

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

You may modify files inside `/backend/`. For changes to `/android/`, `/ml/`, `/docs/`, `/design/`, or root config, say so and let the user decide — there's no other team member to hand off to, so this is a heads-up, not a refusal.

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
