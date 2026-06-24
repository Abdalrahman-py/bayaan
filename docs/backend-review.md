---
type: resource
project: "Diploma Graduation Project"
entities: [Mahmoud Abu Jadallah]
date: 2026-06-10
tags: [bayaan, backend, architecture-review, harsh-review, ramzi]
summary: "Harsh technical review of the Bayaan backend track — 8 critical issues found in the June 10 breakdown, with concrete fixes and a revised task list. Same treatment the ML track got on June 8."
---

> ⚠️ **OUTDATED (pre-pivot, June 10).** Superseded by [`quran-muaalem-decision.md`](./quran-muaalem-decision.md) (2026-06-23). This review already cut Whisper/LLM/TTS/WebSocket down to an ML-only pipeline — and then the June-23 pivot cut training our own model too. Useful as a record of *why* those scope cuts were made; do not build from its task list.

# Bayaan Backend — Harsh Review (June 10)

Same treatment the ML track got on June 8. No sugarcoating. Here's what's wrong with the backend plan and how to fix it.

---

## Issue #1: The Database Access Pattern Is Undefined (CRITICAL)

The June 10 breakdown says "use Exposed or raw JDBC" for database repositories. But the architecture also says "Supabase JWT middleware." These come from two different worlds:

**Path A — Direct PostgreSQL (standard server approach):**
- Ktor's built-in `ktor-server-auth-jwt` plugin verifies Supabase-issued JWTs locally using `SUPABASE_JWT_SECRET`
- Exposed (JetBrains SQL library) connects directly to the Supabase PostgreSQL database via JDBC
- Fast, no extra HTTP hop, standard server architecture
- You manage RLS yourself in the application layer

**Path B — supabase-kt PostgREST (client-side library):**
- The `supabase-kt` community library wraps Supabase's PostgREST API
- Every database query goes through HTTP to `https://<project>.supabase.co/rest/v1/`
- Supabase auto-applies Row Level Security on the server
- Slower (HTTP overhead per query), designed for mobile apps that can't have direct DB connections

The current plan mixes both — it says "Exposed" but also says "Supabase JWT middleware" without specifying which Supabase verification approach. These don't compose. You pick one path.

**Verdict: Path A.** For a backend server sitting next to the database, direct PostgreSQL via Exposed + Ktor's JWT plugin is the correct architecture. supabase-kt is a mobile SDK — using it server-side adds HTTP latency to every query for zero benefit.

**What changes:**
- Ramzi's R4 becomes: "Install ktor-server-auth-jwt, configure HS256 verifier with SUPABASE_JWT_SECRET"
- Ramzi's R6 becomes: "Write Exposed repositories — User, Session, Violation — with direct PostgreSQL connection"
- Add dependency: `ktor-server-auth-jwt`, `exposed-core`, `exposed-dao`, `exposed-jdbc`, `postgresql`

---

## Issue #2: Railway Is Not Free (COST)

The plan and architecture doc say "Railway free tier." There is no permanent free tier. Railway gives a 30-day trial with $5 credit, then you must upgrade to Hobby ($5/month minimum). Additionally, Railway had a platform-wide outage in May 2026 when Google Cloud suspended their production account — control plane, API, and databases were offline for ~8 hours.

**Verdict:** Budget $5/month for the semester. That's ~20 ILS/month. Acceptable for a graduation project. But the plan must state this honestly.

**Alternative:** Render has a free tier for web services (though they spin down after inactivity). Fly.io has a free allowance. But Railway's DX is better for Ktor. Stick with Railway, just be honest about the cost.

---

## Issue #3: The Audio Pipeline Is Contradictory (ARCHITECTURE)

Three different documents say three different things:

| Document | What it says |
|----------|-------------|
| `docs/architecture.md` | "Audio streamed to backend via WebSocket" — "partial results every 50ms" |
| `docs/api-spec.md` | `POST /audio/analyze` — multipart/form-data upload (HTTP) |
| `README.md` task list | "WebSocket endpoint" AND "POST /audio/analyze" |

These are different architectures. WebSocket streaming with partial results requires:
- Persistent connection management
- Streaming audio chunks as they're recorded
- ML model that can do partial inference
- Backpressure handling
- Reconnection logic

HTTP multipart is:
- Record → send file → wait → get result
- Simple, reliable, works everywhere
- No partial results, no streaming complexity

**Verdict: HTTP multipart for MVP.** WebSocket streaming is a stretch goal that adds weeks of complexity for marginal UX benefit. The architecture doc needs to be updated to be internally consistent.

---

## Issue #4: The 800ms Latency Target Is Unrealistic Over Gaza Internet (REALITY)

The proposal targets "under 800ms from end of user speech to first audio response." For HTTP multipart:

1. Audio recording: 3–7 seconds (user is reciting)
2. File upload to server: 2–5 seconds over typical Gaza connection for a ~200KB WAV
3. Server processing (ML inference): ~200–500ms
4. Response download: ~100–200ms

The 800ms number assumes the clock starts *after upload completes*, which is misleading. The user experiences 3–10 seconds from finishing their recitation to seeing feedback.

**Verdict:** Report latency honestly. Measure: (a) upload time, (b) processing time, (c) total wall-clock. Target < 2 seconds for processing time. The total wall clock will be 3–7 seconds and that's fine for a graduation demo.

---

## Issue #5: Audio Format Conversion Is Missing (GAP)

Android's `MediaRecorder` outputs M4A/AAC by default. The wav2vec2 ML model expects 16kHz mono WAV.

Who does the conversion? Not Android — it adds complexity to the mobile side. Not the ML service — it should receive clean input. The Ktor backend must do it.

**Verdict:** Add to the backend track. Use FFmpeg (already installed on Jade's system via Flatpak). The backend receives whatever format Android sends, runs `ffmpeg -i input.m4a -ar 16000 -ac 1 output.wav`, and passes the WAV to the ML service.

**New task:** "Audio format conversion middleware — M4A/AAC → 16kHz mono WAV via FFmpeg"

---

## Issue #6: External API Integrations Are Missing (GAP)

The architecture diagram shows:
- Groq Whisper → STT (speech-to-text)
- Claude/Gemini → LLM (feedback generation)
- ElevenLabs → TTS (voice response)

None of these appear in Ramzi's task list OR in the API spec endpoints. The API spec only has `/audio/analyze` which returns violations — no STT transcript, no LLM feedback, no TTS audio.

What's the actual pipeline for MVP? Two options:

**Option A — ML-only pipeline (simpler):**
- Audio → wav2vec2 classifier → violations JSON
- No STT, no LLM, no TTS
- Feedback text is pre-written per rule (e.g., "Apply 2-count nasal sound on the meem with shadda")
- This is what the current API spec and codebase describe

**Option B — Full AI pipeline (ambitious):**
- Audio → Groq Whisper (transcript) → wav2vec2 (violations) → Claude (feedback) → ElevenLabs (voice)
- Requires API keys for 3 paid services
- Adds latency and cost

**Verdict: Option A for MVP.** The ML-only pipeline is simpler, cheaper, and sufficient for a graduation demo. The pre-written feedback text per rule is already in the API spec response format. Groq/Claude/ElevenLabs are stretch goals. Remove them from the MVP architecture diagram or mark them clearly as Phase 2.

---

## Issue #7: No Testing Strategy (PROCESS)

The Ktor scaffold includes `ktor-server-test-host` — the testing infrastructure is already there. But the task breakdown has zero mention of tests.

**Verdict:** Add testing to every phase. Ktor's `testApplication {}` lets you test endpoints without starting a real server. Test auth (missing JWT → 401, valid JWT → 200), test progress endpoints (empty user → empty stats, user with data → correct stats), test the audio endpoint (valid multipart → 200, missing file → 400).

---

## Issue #8: Task Dependencies Are Incomplete (PROCESS)

The dependency map says R6 → M8, but misses:
- R7–R9 (progress endpoints) need session/violation data to test against, which only exists after M8 (audio endpoint) creates it
- R4 (auth middleware) needs to be tested WITH R7 (progress endpoint) — you can't verify auth works without a real protected endpoint

**Fix:** Ramzi builds R4, then immediately builds ONE protected endpoint (R5 — auth/sync is the simplest) to verify the middleware works end-to-end. Then builds R6, then tests R7–R9 with manually inserted test data BEFORE M8 is ready.

---

## Revised Backend Track

Here's the fixed task list, incorporating all findings above.

### Ramzi's Tasks — Backend Infrastructure

#### Phase 1: Foundation

**R1. Supabase project + environment**
- Create Supabase project (free tier)
- Run schema SQL from `docs/architecture.md` (users, sessions, violations tables + RLS)
- Get Supabase connection string, JWT secret, anon key
- Create `.env` in backend/ with: `SUPABASE_DB_URL`, `SUPABASE_JWT_SECRET`, `PORT`
- Share anon key + Supabase URL with Issa (Android needs them for auth SDK)
- Verify: can connect to the database with `psql`

**R2. Ktor dependencies + project structure**
- Add to build.gradle.kts:
  ```kotlin
  // Auth
  implementation("io.ktor:ktor-server-auth")
  implementation("io.ktor:ktor-server-auth-jwt")
  // Database
  implementation("org.jetbrains.exposed:exposed-core:$exposedVersion")
  implementation("org.jetbrains.exposed:exposed-dao:$exposedVersion")
  implementation("org.jetbrains.exposed:exposed-jdbc:$exposedVersion")
  implementation("org.postgresql:postgresql:$postgresVersion")
  // Serialization
  implementation("io.ktor:ktor-server-content-negotiation")
  implementation("io.ktor:ktor-serialization-kotlinx-json")
  ```
- Organize source tree: `auth/`, `routes/`, `data/`, `plugins/`
- Confirm project compiles

#### Phase 2: Auth

**R3. Supabase JWT verification middleware**
- Use Ktor's `Authentication` plugin with `jwt("auth-jwt")` provider
- Configure HS256 verifier using `SUPABASE_JWT_SECRET` from env
- Extract `sub` claim (user UUID) from verified JWT, attach to call context
- On failure: respond 401 with `{error: "unauthorized", message: "..."}`
- **Test:** Write a test that sends an invalid JWT → 401, valid JWT → extracts user ID
- Reference: https://ktor.io/docs/server-jwt.html (step-by-step, matches exactly)

**R4. POST /auth/sync endpoint**
- Protected route (wrapped in `authenticate("auth-jwt")`)
- Read user UUID from the verified JWT principal
- Upsert into `public.users` table
- Return `{user_id, created: true/false}`
- **Test:** Call endpoint with a valid JWT → user row appears in DB

#### Phase 3: Database Layer

**R5. Database connection + Exposed setup**
- Create `DatabaseFactory` that connects to Supabase PostgreSQL using the connection string
- Use HikariCP for connection pooling (Exposed supports it natively)
- Create Exposed table objects matching the schema:
  ```kotlin
  object Users : UUIDTable("users") { ... }
  object Sessions : UUIDTable("sessions") { ... }
  object Violations : UUIDTable("violations") { ... }
  ```
- **Test:** Connect, create a test row, read it back, drop it

**R6. Repository classes**
- `UserRepository`: findById, upsert (used by R4)
- `SessionRepository`: insert, findByUser(paginated, newest first), findById
- `ViolationRepository`: insertBatch(sessionId, violations), findBySession
- All methods suspendable (Exposed's `transaction` block works with coroutines when using `Dispatchers.IO`)
- **Test:** Insert a session with violations, query it back, verify all fields match

#### Phase 4: Progress Endpoints

**R7. GET /progress**
- Protected. Read authenticated user's session/violation data
- Calculate per-rule stats (total_attempts, correct, accuracy)
- Return JSON matching API spec
- **Test:** Empty user → all zeros. User with 10 sessions → correct stats

**R8. GET /progress/sessions**
- Protected. Paginated session list (newest first)
- Query params: `limit` (default 20), `offset` (default 0)
- Return JSON matching API spec
- **Test:** 50 sessions, page size 20, offset 20 → returns sessions 20-39

**R9. GET /progress/sessions/{session_id}**
- Protected. Full session detail with violations
- Verify session belongs to authenticated user → 404 if not
- **Test:** User A's session ID accessed by user B's JWT → 404

**R10. GET /surahs**
- Public (no auth). MVP: returns only Al-Fatihah
- Return JSON matching API spec
- **Test:** GET /surahs → single surah with correct fields

#### Phase 5: Deployment

**R11. Audio format conversion utility**
- Add FFmpeg integration: receive uploaded audio bytes, convert to 16kHz mono WAV
- Use `java.lang.Process` to call ffmpeg (flatpak wrapper on Jade's system, standard ffmpeg on Railway)
- Input: M4A/AAC/any format Android sends
- Output: 16kHz mono WAV bytes ready for ML inference
- Fallback: if ffmpeg fails, return 422 with `{error: "unprocessable_audio"}`
- **Test:** Convert a sample M4A file → valid WAV at correct sample rate

**R12. Railway deployment**
- Create `Dockerfile` in backend/ root:
  ```dockerfile
  FROM gradle:8.5-jdk21 AS build
  COPY . /app
  WORKDIR /app
  RUN gradle buildFatJar --no-daemon
  
  FROM ubuntu:24.04
  RUN apt-get update && apt-get install -y openjdk-21-jre-headless ffmpeg
  COPY --from=build /app/build/libs/*-all.jar app.jar
  EXPOSE 8080
  CMD ["java", "-jar", "app.jar"]
  ```
- Configure `application.conf` to read `PORT` from env, bind to `0.0.0.0`
- Set env vars on Railway: `SUPABASE_DB_URL`, `SUPABASE_JWT_SECRET`, `PORT`
- Confirm `/health` returns 200 on the Railway domain
- **Monthly cost: $5 (Hobby plan)** — be honest about this

### Abdalrahman's Tasks — Backend API + ML Client

#### Phase 6: Audio Endpoint + ML Wiring

**M8. POST /audio/analyze endpoint**
- Protected route
- Accept multipart/form-data: `audio` (file), `mode` (string: "word" or "tajweed"), plus optional `surah`/`verse` for tajweed mode
- Validate: file present, size < 10MB, mode is valid
- Convert audio to 16kHz WAV via Ramzi's ffmpeg utility
- Forward WAV bytes to ML inference server (Python/FastAPI running on same machine, different port or localhost)
- Parse ML response, insert session + violations via Ramzi's repositories
- Return JSON matching API spec
- **Test:** Multipart POST with a sample WAV → valid session created in DB

**M9. Internal ML service client**
- Ktor `HttpClient` configured with:
  - Engine: CIO (coroutine-based, no extra deps)
  - Timeout: requestTimeout = 10_000, connectTimeout = 5_000
  - JSON serialization (kotlinx.serialization)
- Three methods matching the ML inference server endpoints:
  - `classifyWord(audio: ByteArray): WordResult`
  - `classifyGhunnah(audio: ByteArray): BinaryResult`
  - `classifyMadd(audio: ByteArray): BinaryResult`
- Error handling: catch timeouts → 503, catch serialization errors → 422
- **Test with mock server:** Point at a test HTTP server that returns known responses

---

## Updated Dependency Map

```
Ramzi:   R1 → R2 → R3 → R4 → R5 → R6 → R7,R8,R9,R10 → R11 → R12
                                                    ↑
Jade:   M1,M2,M3 → M4,M5,M6 → M7 → M8,M9
                                      ↑
                      (M8 depends on R3, R6, R11 — auth + repos + ffmpeg)
                      (M9 depends on M7 — ML inference server)
```

**Key handoffs:**
- R3 (auth middleware) → M8 uses it
- R6 (repositories) → M8 uses them to save data
- R11 (ffmpeg utility) → M8 uses it for audio conversion
- M7 (inference server) → M9 calls it

**Testing data for Ramzi:** Ramzi can test R7–R9 by inserting test data directly via psql or a SQL script — no need to wait for M8. This unblocks parallel work.

---

## What Got Cut (MVP Scope Discipline)

The following were in the original architecture but are removed from MVP:

| Item | Why cut |
|------|---------|
| WebSocket audio streaming | Adds weeks of complexity; HTTP multipart is sufficient for demo |
| Groq Whisper STT integration | ML-only pipeline with pre-written feedback is simpler and cheaper |
| Claude/Gemini LLM feedback | Pre-written per-rule feedback text works for 2 rules |
| ElevenLabs TTS | Visual feedback is sufficient for graduation demo; voice is Phase 2 |
| Firebase Auth + Firestore | Supabase Auth handles everything; no need for a second auth system |
| Railway free tier (free) | Doesn't exist — budget $5/month |

---

## Honest Cost Estimate

| Service | Plan | Monthly Cost |
|---------|------|-------------|
| Railway (backend hosting) | Hobby | $5 |
| Supabase (auth + DB) | Free tier | $0 |
| Kaggle (GPU training) | Free P100, 30h/week | $0 |
| **Total** | | **$5/month** |

One semester (4 months) = $20. About 75 ILS. Cheaper than one human Quran tutoring session ($30–60/hour).

---

## Related

- [[Diploma-Graduation-Project]] — parent project hub
- [[bayaan-backend-ml-task-breakdown]] — previous (June 10) breakdown — this review supersedes it
- [[bayaan-project-document]] — full proposal (v2)
- [[2026-06-08-bayaan-stack-review-design-ml]] — ML track review (the model for this review)
- [[2026-05-25-bayaan-team-task-breakdown]] — original May 25 task breakdown
- [[Mahmoud-Abu-Jadallah]] — project supervisor
