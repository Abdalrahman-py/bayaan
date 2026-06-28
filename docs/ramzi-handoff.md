# Bayaan Backend — Ramzi Handoff

**Date:** 2026-06-28  
**Branch:** `main`  
**Your module:** `/backend`

---

## What You Built and What Is Now Live

Your implementation guide (R1–R12) was the foundation for everything in the backend today. All of R1–R6 is implemented and working. R11 (ffmpeg) was implemented but is being removed for reasons explained below. R12 (deployment) is live on Render (not Railway — free tier, no cost difference for the prototype). R7–R10 (the progress endpoints) are what remain to be built.

Here is the state of each piece you wrote, and any adjustments made when wiring everything together.

---

## What Is Implemented

### R1 — Supabase Project

Live. Project ref `djcuxaziipgjlmdfkeqz`, region `ap-northeast-2`. Schema has been migrated (see schema section below — it changed from what was in your guide). Tables `users`, `sessions`, `mistakes` are live with RLS enabled.

**One thing still pending:** The Render deployment needs the environment variables set on the dashboard — `SUPABASE_DB_URL`, `SUPABASE_JWT_SECRET`, `SUPABASE_PROJECT_REF`. Once those are added, the server connects to the database on startup.

---

### R2 — Project Structure

The source tree matches your spec closely:

```
backend/src/main/kotlin/com/bayaan/
├── plugins/
│   └── JwtPlugin.kt          — JWT configuration (your AuthPlugin.kt, renamed)
├── routes/
│   └── AuthRoutes.kt         — POST /auth/sync
├── data/
│   ├── DatabaseFactory.kt    — HikariCP setup + dbQuery helper
│   ├── tables/
│   │   ├── Users.kt
│   │   ├── Sessions.kt
│   │   └── Mistakes.kt       — was Violations.kt in your guide
│   └── repositories/
│       ├── UserRepository.kt
│       ├── SessionRepository.kt
│       └── MistakeRepository.kt  — was ViolationRepository.kt
├── Application.kt            — entry point
└── Routing.kt                — /health, /audio/analyze
```

`SerializationPlugin.kt` and `DatabasePlugin.kt` were not created as separate files — `DatabaseFactory.kt` handles the HikariCP setup directly and `JwtPlugin.kt` handles auth. Functionally identical, just fewer files.

---

### R3 — JWT Middleware

Implemented in `plugins/JwtPlugin.kt`. Your spec was correct on the fundamentals. One addition: the verifier now also validates the token's **issuer** (the Supabase project URL) and **audience** (`"authenticated"`). Supabase always sets both of these on the JWTs it issues, so verifying them closes the gap where a valid JWT from a different Supabase project could be accepted. The rest — HS256 with `SUPABASE_JWT_SECRET`, `sub` claim extraction, 401 on failure — is exactly what you specified.

---

### R4 — POST /auth/sync

Implemented in `routes/AuthRoutes.kt`, exactly to spec. Reads the user UUID from the verified JWT principal, upserts into `public.users`, returns `{"user_id": "...", "created": true/false}`.

---

### R5 — Database Connection + Exposed Setup

Implemented in `data/DatabaseFactory.kt`. The HikariCP setup matches your spec: reads `SUPABASE_DB_URL` from env, pool size 10, `READ_COMMITTED` isolation.

**The table objects changed.** See the schema section below for the full explanation — but the short version is that the column names and types in `sessions` and `mistakes` are different from what your guide specified, because the actual ML engine output turned out to be richer than the original plan assumed.

---

### R6 — Repository Classes

`UserRepository` — complete. `upsert()` works as specified.

`SessionRepository` — partially complete. `insert()` exists and works. `findByUser()` and `findById()` do not exist yet — they are needed for R8 and R9.

`MistakeRepository` — replaces `ViolationRepository`. `insertBatch()` exists and works, used by `/audio/analyze` after every successful recitation. `findBySession()` does not exist yet — needed for R9.

---

### R11 — ffmpeg Conversion

Implemented inline in `Routing.kt`. However, it turns out the Android app records audio directly as raw PCM samples at 16kHz using `AudioRecord`, then wraps them in a WAV header on-device before uploading. What arrives at the backend is already a valid 16kHz mono WAV file. The ffmpeg step receives WAV and outputs identical WAV — it does nothing. It is being removed in the next commit. This also drops the ffmpeg Dockerfile dependency.

---

### R12 — Deployment

Deployed on **Render** (free tier) rather than Railway. Functionally equivalent for the prototype — both run the Docker image, both support env vars. The Dockerfile exists and builds correctly. The Render service is live at `bayaan-backend.onrender.com`. Note that the free tier has a ~30–60 second cold start after periods of inactivity.

---

## The Schema (What Changed and Why)

Your guide specified three tables: `users`, `sessions`, `violations`. The live schema has `users`, `sessions`, `mistakes`. Here is the difference and the reason.

**Why it changed:** The ML engine is a Tajweed error detection model that returns structured error objects with character-level positions, error types, rule names in Arabic and English, and elongation length data. The original schema stored only `rule`, `word_index`, `confidence`, `correct` — a much simpler shape designed before we knew what the engine actually produced. Storing the engine's full output required a different set of columns.

### `public.users`

No change from your spec.

```sql
CREATE TABLE public.users (
    id         UUID PRIMARY KEY,
    email      TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);
```

The `id` column stores the Supabase Auth user UUID. `email` is nullable and currently left null — it can be populated from the JWT payload's `email` claim in a later task.

---

### `public.sessions`

Column names changed. `surah TEXT` became `sura INTEGER`. `verse INTEGER` became `aya INTEGER`. An `all_correct BOOLEAN` column was added.

```sql
CREATE TABLE public.sessions (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID REFERENCES public.users(id) ON DELETE CASCADE,
    sura        INTEGER NOT NULL,
    aya         INTEGER NOT NULL,
    all_correct BOOLEAN NOT NULL,
    created_at  TIMESTAMPTZ DEFAULT now()
);
```

Using integers for `sura` and `aya` rather than a text string like `"al-fatihah"` is cleaner — the Quran is already universally numbered, and it avoids inventing a string identifier scheme. `all_correct` is set by the engine response and stored here so that the session list endpoint can show pass/fail per session without counting its mistakes.

---

### `public.mistakes` (was `public.violations`)

Completely different columns. The old `violations` table stored: `rule`, `word_index`, `confidence`, `correct`. The new `mistakes` table stores the actual engine output:

```sql
CREATE TABLE public.mistakes (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id        UUID REFERENCES public.sessions(id) ON DELETE CASCADE,
    char_start        INTEGER NOT NULL,
    char_end          INTEGER NOT NULL,
    error_type        TEXT NOT NULL,
    speech_error_type TEXT,
    rule_name_en      TEXT,
    rule_name_ar      TEXT,
    expected_len      INTEGER,
    predicted_len     INTEGER,
    created_at        TIMESTAMPTZ DEFAULT now()
);
```

- `char_start` / `char_end` — character positions within the verse text (Uthmani script), so the Android app can highlight exactly the word or letter where the mistake was
- `error_type` — the engine's top-level error category (e.g. `"tajweed"`)
- `speech_error_type` — more specific sub-type within the category
- `rule_name_en` / `rule_name_ar` — the name of the Tajweed rule that was violated, in both English and Arabic
- `expected_len` / `predicted_len` — for elongation (Madd) mistakes: how many counts were expected vs how many the student produced

One important difference from your original design: the `mistakes` table only stores actual mistakes, not correct attempts. There is no `correct BOOLEAN` column. A session with zero rows in `mistakes` means the recitation was perfect. This is reflected in `sessions.all_correct`.

---

## What Is Still Left to Build (R7–R10)

These four endpoints are the progress tracking layer. None of them exist yet. Here is exactly what to build for each one.

---

### Before You Start: Repository Methods to Add

The progress endpoints need query methods that do not exist yet. Add these to the existing repository files before building the routes.

**`SessionRepository.kt` — add these methods:**

```kotlin
// All sessions for a user, newest first, with pagination
suspend fun findByUser(userId: UUID, limit: Int, offset: Int): List<ResultRow> =
    DatabaseFactory.dbQuery {
        Sessions
            .selectAll()
            .where { Sessions.userId eq userId }
            .orderBy(Sessions.createdAt, SortOrder.DESC)
            .limit(limit, offset.toLong())
            .toList()
    }

// Total number of sessions for a user (for pagination metadata)
suspend fun countByUser(userId: UUID): Long =
    DatabaseFactory.dbQuery {
        Sessions
            .selectAll()
            .where { Sessions.userId eq userId }
            .count()
    }

// Single session lookup (used by R9 to verify ownership before returning data)
suspend fun findById(sessionId: UUID): ResultRow? =
    DatabaseFactory.dbQuery {
        Sessions
            .selectAll()
            .where { Sessions.id eq sessionId }
            .singleOrNull()
    }
```

**`MistakeRepository.kt` — add these methods:**

```kotlin
// All mistakes for a session (used by R9 for the detail view)
suspend fun findBySession(sessionId: UUID): List<ResultRow> =
    DatabaseFactory.dbQuery {
        Mistakes
            .selectAll()
            .where { Mistakes.sessionId eq sessionId }
            .toList()
    }

// Count mistakes for a session (used by R8 for the session list summary)
suspend fun countBySession(sessionId: UUID): Long =
    DatabaseFactory.dbQuery {
        Mistakes
            .selectAll()
            .where { Mistakes.sessionId eq sessionId }
            .count()
    }
```

---

### R7 — GET /progress

**What it is:** A summary of the authenticated user's overall performance. The original spec planned per-rule accuracy (ghunnah, madd). The schema no longer stores per-rule attempts, only per-rule mistakes — so the response shape is slightly different from what was originally planned.

**What to return:**

```json
{
  "total_sessions": 14,
  "perfect_sessions": 9,
  "overall_accuracy": 0.64,
  "total_mistakes": 23,
  "mistake_breakdown": {
    "Ghunnah": 8,
    "Madd Tabi'i": 6,
    "Ikhfa": 5,
    "Other": 4
  }
}
```

- `total_sessions` — count of all sessions for the user
- `perfect_sessions` — count of sessions where `all_correct = true`
- `overall_accuracy` — `perfect_sessions / total_sessions` (0.0 if no sessions)
- `total_mistakes` — total mistake rows across all sessions
- `mistake_breakdown` — count per `rule_name_en` across all mistakes; use `"Other"` as the key when `rule_name_en` is null

**Implementation outline:**

```kotlin
get("/progress") {
    val userId = UUID.fromString(call.principal<JWTPrincipal>()!!.payload.subject)
    val totalSessions = SessionRepository.countByUser(userId)
    val perfectSessions = SessionRepository.countPerfectByUser(userId) // add this method
    val accuracy = if (totalSessions == 0L) 0.0 else perfectSessions.toDouble() / totalSessions
    val breakdown = MistakeRepository.countByRuleForUser(userId) // returns Map<String, Long>
    val totalMistakes = breakdown.values.sum()
    // serialize and respond
}
```

You will need one more repository method for the perfect session count:

```kotlin
// In SessionRepository:
suspend fun countPerfectByUser(userId: UUID): Long =
    DatabaseFactory.dbQuery {
        Sessions
            .selectAll()
            .where { (Sessions.userId eq userId) and (Sessions.allCorrect eq true) }
            .count()
    }
```

And one for the mistake breakdown (this requires joining from mistakes through sessions to filter by user):

```kotlin
// In MistakeRepository:
suspend fun countByRuleForUser(userId: UUID): Map<String, Long> =
    DatabaseFactory.dbQuery {
        (Mistakes innerJoin Sessions)
            .select(Mistakes.ruleNameEn, Mistakes.ruleNameEn.count())
            .where { Sessions.userId eq userId }
            .groupBy(Mistakes.ruleNameEn)
            .associate { row ->
                val rule = row[Mistakes.ruleNameEn] ?: "Other"
                rule to row[Mistakes.ruleNameEn.count()]
            }
    }
```

**Auth:** required — wrap in `authenticate("auth-jwt")` in `Application.kt`.

**Register in Application.kt:**

```kotlin
authenticate("auth-jwt") {
    authRoutes()
    analyzeRoute()
    progressRoutes() // add this
}
```

---

### R8 — GET /progress/sessions

**What it is:** Paginated list of the user's recitation sessions, newest first. Each item in the list is a summary — no mistake detail, just counts.

**Query parameters:**
- `limit` — how many to return. Default: `20`. Maximum: `100`.
- `offset` — how many to skip from the newest. Default: `0`.

**Response shape:**

```json
{
  "sessions": [
    {
      "session_id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
      "sura": 1,
      "aya": 1,
      "all_correct": false,
      "mistakes_count": 3,
      "created_at": "2026-06-28T14:32:00Z"
    }
  ],
  "total": 14,
  "limit": 20,
  "offset": 0
}
```

**Implementation outline:**

```kotlin
fun Route.progressRoutes() {
    get("/progress") { /* ... */ }

    get("/progress/sessions") {
        val userId = UUID.fromString(call.principal<JWTPrincipal>()!!.payload.subject)
        val limit  = (call.request.queryParameters["limit"]?.toIntOrNull() ?: 20).coerceIn(1, 100)
        val offset = call.request.queryParameters["offset"]?.toIntOrNull() ?: 0

        val total    = SessionRepository.countByUser(userId)
        val sessions = SessionRepository.findByUser(userId, limit, offset)

        val items = sessions.map { row ->
            val sessionId = row[Sessions.id]
            val mistakesCount = MistakeRepository.countBySession(sessionId)
            // build the response object
        }
        // respond with { sessions: items, total, limit, offset }
    }
}
```

Note: `countBySession()` is called once per session in the list. For 20 sessions that is 20 separate queries. This is fine for the prototype. If it ever becomes slow, replace with a single JOIN query — but do not optimize it now.

**Auth:** required.

---

### R9 — GET /progress/sessions/{session_id}

**What it is:** Full detail for a single session — all the mistake data for that recitation.

**URL parameter:** `session_id` — the UUID of the session.

**Response shape:**

```json
{
  "session_id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
  "sura": 1,
  "aya": 1,
  "all_correct": false,
  "created_at": "2026-06-28T14:32:00Z",
  "mistakes": [
    {
      "id": "uuid",
      "char_start": 14,
      "char_end": 17,
      "error_type": "tajweed",
      "speech_error_type": "elongation",
      "rule_name_en": "Madd Tabi'i",
      "rule_name_ar": "المد الطبيعي",
      "expected_len": 2,
      "predicted_len": 1
    }
  ]
}
```

**Critical security rule:** Before returning any data, verify that the session belongs to the authenticated user. If the session ID does not exist, or if it belongs to a different user, return 404 — not 403. Returning 403 would confirm that the session exists, which leaks information.

**Implementation outline:**

```kotlin
get("/progress/sessions/{session_id}") {
    val userId = UUID.fromString(call.principal<JWTPrincipal>()!!.payload.subject)
    val sessionId = try {
        UUID.fromString(call.parameters["session_id"])
    } catch (_: IllegalArgumentException) {
        return@get call.respondText(
            """{"error":"not_found","message":"Session not found"}""",
            ContentType.Application.Json, HttpStatusCode.NotFound
        )
    }

    val session = SessionRepository.findById(sessionId)
    if (session == null || session[Sessions.userId] != userId) {
        return@get call.respondText(
            """{"error":"not_found","message":"Session not found"}""",
            ContentType.Application.Json, HttpStatusCode.NotFound
        )
    }

    val mistakes = MistakeRepository.findBySession(sessionId)
    // build and respond with the full session object
}
```

**Auth:** required.

---

### R10 — GET /surahs

**What it is:** A public list of surahs available for practice. No auth required. Hardcoded for now — just Al-Fatihah and Al-Bayyinah (the two suras currently in the Android app).

**Response shape:**

```json
{
  "surahs": [
    {
      "number": 1,
      "name_arabic": "الفاتحة",
      "name_english": "Al-Fatihah",
      "verse_count": 7,
      "available": true
    },
    {
      "number": 98,
      "name_arabic": "البينة",
      "name_english": "Al-Bayyinah",
      "verse_count": 8,
      "available": true
    }
  ]
}
```

Note the `number` field uses the standard Quran surah number (1 for Al-Fatihah, 98 for Al-Bayyinah). This matches the integer IDs the Android app and database already use.

**Implementation:** No database query needed. Return a hardcoded list.

```kotlin
get("/surahs") {
    call.respondText(
        """{"surahs":[{"number":1,"name_arabic":"الفاتحة","name_english":"Al-Fatihah","verse_count":7,"available":true},{"number":98,"name_arabic":"البينة","name_english":"Al-Bayyinah","verse_count":8,"available":true}]}""",
        ContentType.Application.Json
    )
}
```

This endpoint goes outside the `authenticate` block in `Application.kt` since it requires no auth.

**Auth:** none.

---

## Where to Put the New Routes

Create `backend/src/main/kotlin/com/bayaan/routes/ProgressRoutes.kt` and `SurahRoutes.kt`. Then register them in `Application.kt`:

```kotlin
fun Application.module() {
    configureJwt()
    DatabaseFactory.connect()
    routing {
        healthRoute()
        surahRoutes()                  // public
        authenticate("auth-jwt") {
            authRoutes()
            analyzeRoute()
            progressRoutes()           // all three progress endpoints go here
        }
    }
}
```

---

## Tests for the New Endpoints

The existing test file is `backend/src/test/kotlin/com/bayaan/ServerTest.kt`. Add new tests there or in a new file. The existing tests show the pattern — `testApplication {}` with a minted test JWT. You do not need a live database to test the route layer; inject test data via a fake repository or test against an in-memory H2 database if you want deeper coverage.

Minimum test cases:

| Endpoint | What to test |
|---|---|
| `GET /progress` | No auth → 401. Valid user with no sessions → zeros, no mistakes. |
| `GET /progress/sessions` | No auth → 401. Default pagination returns at most 20. `limit=5&offset=0` returns 5. |
| `GET /progress/sessions/{id}` | No auth → 401. Wrong user's session ID → 404. Malformed UUID → 404. |
| `GET /surahs` | No auth header needed → 200 with both surahs in the list. |

---

## Error Shape

All error responses follow the same shape already used in the codebase:

```json
{"error": "short_snake_case_code", "message": "Human-readable description"}
```

| Situation | HTTP | Error code |
|---|---|---|
| Missing or invalid JWT | 401 | `unauthorized` |
| Session not found or belongs to another user | 404 | `not_found` |
| Malformed UUID in URL | 404 | `not_found` |
| Invalid query parameter | 400 | `bad_request` |

---

## How to Run and Test Locally

```bash
cd backend
./gradlew run
```

The server starts on `localhost:8080`. To test the progress endpoints without a live Supabase connection, you can set `SUPABASE_DB_URL` to a local PostgreSQL instance and `SUPABASE_JWT_SECRET` to any string (and generate matching test JWTs using the same string).

To generate a test JWT for manual testing with `curl`:

```kotlin
// Use the same approach as ServerTest.kt:
JWT.create()
    .withSubject("<any-uuid>")
    .withIssuer("https://test-project.supabase.co/auth/v1")
    .withAudience("authenticated")
    .withExpiresAt(Date(System.currentTimeMillis() + 3_600_000))
    .sign(Algorithm.HMAC256("your-test-secret"))
```

Or use https://jwt.io with algorithm HS256, set `sub` to any UUID, `iss` to `https://test-project.supabase.co/auth/v1`, `aud` to `authenticated`.

```bash
curl -H "Authorization: Bearer <token>" http://localhost:8080/progress
curl -H "Authorization: Bearer <token>" http://localhost:8080/progress/sessions
curl -H "Authorization: Bearer <token>" http://localhost:8080/progress/sessions/<uuid>
curl http://localhost:8080/surahs
```

---

## Quick Reference

| What | Location |
|---|---|
| Entry point | `backend/src/main/kotlin/com/bayaan/Application.kt` |
| JWT plugin | `backend/src/main/kotlin/com/bayaan/plugins/JwtPlugin.kt` |
| Auth route (done) | `backend/src/main/kotlin/com/bayaan/routes/AuthRoutes.kt` |
| Progress routes (to build) | `backend/src/main/kotlin/com/bayaan/routes/ProgressRoutes.kt` |
| Surahs route (to build) | `backend/src/main/kotlin/com/bayaan/routes/SurahRoutes.kt` |
| DB factory | `backend/src/main/kotlin/com/bayaan/data/DatabaseFactory.kt` |
| Tables | `backend/src/main/kotlin/com/bayaan/data/tables/` |
| Repositories | `backend/src/main/kotlin/com/bayaan/data/repositories/` |
| Tests | `backend/src/test/kotlin/com/bayaan/ServerTest.kt` |
| Build | `./gradlew build` |
| Test | `./gradlew test` |
| Run | `./gradlew run` |

Commit prefix for your work: `feat(backend): description` or `fix(backend): description`.
