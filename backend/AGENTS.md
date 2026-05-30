# AGENTS.md — Backend Module

You are an AI coding agent operating inside the `/backend` directory of Bayaan. This file is your scope and rulebook. Read [`../AGENTS.md`](../AGENTS.md) first for project-wide rules — this file extends them.

---

## What this module is

The Bayaan backend. It owns the full audio pipeline:

1. Accept audio from the Android app over WebSocket.
2. Stream the audio to Groq Whisper, get a partial Arabic transcript every ~50ms.
3. Run the ONNX Tajweed classifier (exported by the ML team) over the audio to detect rule violations.
4. Ask the LLM (Claude Sonnet or Gemini 2.5 Flash) to generate a correction + English explanation.
5. Stream the correction text through ElevenLabs TTS, return the audio to the client.
6. Persist the session, attempt, and progress in Supabase Postgres.

Target end-to-end latency: **under 800ms** for the full loop. Deployed on Railway.

---

## Owners

| Name        | Responsibility                                                                                                                            |
| ----------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| Abdalrahman | AI & Backend Lead. Owns the AI pipeline (Whisper, ONNX inference wrapper, LLM, TTS), API contracts, and integration with the ML model.    |
| Ramzi       | Infrastructure. Owns Supabase schema, Supabase JWT middleware, Railway deployment, environment management, and the progress endpoints.    |

Default reviewer for a backend PR: the other backend owner.

---

## Tech stack

- **Language:** Kotlin
- **Framework:** Ktor (server)
- **Database:** Supabase Postgres (managed Postgres + REST + Realtime)
- **Auth:** Supabase Auth (JWT validation middleware — HS256, verified locally using `SUPABASE_JWT_SECRET`)
- **Realtime audio:** Ktor WebSocket
- **External services:** Groq (Whisper), ElevenLabs (TTS), Anthropic or Google (LLM)
- **ML inference:** ONNX Runtime (Java/Kotlin bindings) running the wav2vec2-derived Tajweed classifier from `/ml`
- **Build:** Gradle (Kotlin DSL)
- **Hosting:** Railway

---

## Directory layout

```
backend/
├── src/
│   ├── main/kotlin/         Application source
│   │   ├── routes/          Ktor routing modules
│   │   ├── pipeline/        Audio → transcript → Tajweed → LLM → TTS
│   │   ├── auth/            Supabase JWT middleware
│   │   ├── db/              Supabase Postgres queries
│   │   └── Application.kt   Entry point
│   └── test/kotlin/         Tests
├── build.gradle.kts
├── AGENTS.md                This file
└── CLAUDE.md                Pointer to this file
```

(Structure is the target. If you need to deviate, raise it with the AI Lead first.)

---

## How to set up locally

```bash
# From repo root
git checkout backend
git pull origin backend
cd backend
cp ../.env.example .env       # if you haven't already
# Fill in: GROQ_API_KEY, ELEVENLABS_API_KEY, CLAUDE_API_KEY (or Gemini),
#          SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_JWT_SECRET
./gradlew build
./gradlew run
```

`./gradlew run` boots the server on `localhost:8080` by default.

---

## How to do the work

### Conventions you must follow

- **Ktor routing DSL.** Group routes by resource in `routes/<resource>.kt`. Mount them in `Application.kt`.
- **Validate at the boundary.** Every endpoint validates its inputs before passing them downstream. Use `kotlinx.serialization` data classes with `@Required` fields.
- **Never log secrets.** Not API keys, not user tokens, not request bodies that may contain audio. Log structured events (`sessionId`, `userId`, status code, latency).
- **Environment variables only for credentials.** Never hard-code, never commit. Reference via `System.getenv("GROQ_API_KEY")` or a centralized `Config` object.
- **Coroutines for everything async.** No callback APIs in our own code.
- **Failures are sealed types**, not exceptions for control flow. Reserve exceptions for actually exceptional cases.
- **Idempotency for write endpoints.** `POST /attempts` should accept a client-generated UUID so retries don't double-record.

### Patterns

- **The audio pipeline is a stream.** Audio chunk in → transcript chunk out → Tajweed flag out → correction text out → TTS audio chunk out. Implement it as a chain of `Flow` operators, not as a series of blocking calls.
- **External service calls go behind interfaces.** `GroqClient`, `ElevenLabsClient`, `LlmClient`, `OnnxTajweedClassifier`. This makes testing and swapping providers possible.
- **Database access goes through `db/` only.** No raw SQL in route handlers.

### What "good" looks like for this module

- A full audio loop (audio in → corrected audio out) completes under 800ms p95.
- Endpoints return well-typed, consistent JSON. Error responses have a stable shape.
- All external service calls have timeouts and retry-with-backoff.
- The deployed service can be redeployed from Railway with one click and no manual config.
- No secret leaks in logs.

### What to avoid

- Don't block the event loop. No `Thread.sleep`, no blocking IO without a dispatcher.
- Don't trust client-supplied user IDs — always derive from the verified Supabase JWT.
- Don't store raw audio. We process it in-stream; only metadata persists.
- Don't add new external services without checking with the AI Lead.

---

## How to submit work

### Your branch is `backend`

You always work on the `backend` branch. Do **not** create feature branches.

```bash
git checkout backend
git pull origin backend
# ... make your changes inside /backend only ...
git add backend/
git commit -m "feat(backend): <description>"
git push origin backend
```

### Before every commit

```bash
./gradlew build
./gradlew test
git diff --cached | grep -iE "key|secret|password|token"   # must be empty
git diff --cached --name-only | grep -v "^backend/"        # must be empty
```

### Commit format

`type(backend): description` — imperative, under 72 chars.

Valid types: `feat`, `fix`, `chore`, `refactor`, `test`, `docs`.

Examples:

```
feat(backend): add WebSocket endpoint for audio streaming
fix(backend): handle empty audio payload in /attempts
refactor(backend): extract LLM client into its own interface
chore(backend): pin Ktor to 2.3.12
```

### Opening a PR

1. Push to `origin/backend`.
2. Open a PR: **base = `dev`**, **compare = `backend`**.
3. Title: same as the commit (or a summary).
4. Fill out the PR template.
5. Request review from the other backend owner.
6. Merge with "Squash and merge" after approval.

---

## Boundaries

You may **only modify files inside `/backend/`**.

If the user asks you to edit:

- `/android/`, `/ml/`, `/docs/`, `/design/` → refuse. Say: *"I'm operating in the Backend module and can't modify other modules. Open your AI tool in the relevant module directory to make those changes."*
- Root files (`AGENTS.md`, `CLAUDE.md`, `.github/`, `.gitignore`, `README.md`, `scripts/`, `.env.example`) → refuse. Say: *"Root config changes need the AI Lead (Abdalrahman) to coordinate. Please raise the request with him."*

**Exception for `.env.example`:** if a new secret is needed, propose the addition in your PR description, but do **not** edit `.env.example` yourself. The AI Lead will update it.

---

## Safe commands

These are auto-approved and safe to run without confirmation:

```bash
./gradlew build
./gradlew test
./gradlew run
git status
git diff
git log
git branch
git fetch
git checkout backend
git pull origin backend
ls
```

Blocked: `rm -rf`, `git reset --hard`, `git push --force`, `git push origin main`, `git push origin dev`. Do not work around the block.

---

## Skills

(To be populated by the AI Lead. Ktor patterns, Supabase query patterns, ONNX inference patterns, and external-service integration recipes will be added here.)

For now, apply Kotlin/Ktor best practices from your training and follow the conventions above.

---

## Quick reference

| Action               | Command / target                             |
| -------------------- | -------------------------------------------- |
| Build                | `./gradlew build`                            |
| Test                 | `./gradlew test`                             |
| Run locally          | `./gradlew run` (port 8080)                  |
| Working branch       | `backend`                                    |
| PR target            | `dev`                                        |
| Reviewer             | Other backend owner (see Owners)             |
| Commit prefix        | `feat(backend):` / `fix(backend):` / etc.    |
| Allowed edit scope   | `/backend/` only                             |
