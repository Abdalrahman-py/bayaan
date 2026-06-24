---
type: resource
project: "Diploma Graduation Project"
entities: [Mahmoud Abu Jadallah]
date: 2026-06-10
tags: [bayaan, backend, ramzi, tasks, implementation]
summary: "Ramzi's complete backend implementation guide — context, tech decisions, 12 tasks with exact specifications, Supabase setup, database schema, API contracts, testing expectations, and what NOT to build. Self-contained — no questions needed."
---

> ⚠️ **OUTDATED (pre-pivot, June 10).** Superseded by [`quran-muaalem-decision.md`](./quran-muaalem-decision.md) (2026-06-23). This guide builds a full auth + sessions + violations backend around a model we no longer train. The demo backend is a thin proxy to the `obadx/quran-muaalem` engine on Modal (no auth/DB for the demo). The Supabase/Ktor/ffmpeg/Railway mechanics here are still good reference. Kept for history; do not execute top-to-bottom.

# Ramzi — Bayaan Backend Implementation Guide

Everything you need to build the Bayaan backend. Read this once, then start from R1 and work down. If a question isn't answered here, ask Abdalrahman. Otherwise, just build.

---

## 1. What We're Building

Bayaan is an AI-powered Arabic and Quran voice tutor. Users speak, the app listens, AI checks correctness.

**The backend's job:** Receive audio from the Android app, run it through our ML model, save the results, and return feedback. Also handle user sign-in and progress tracking.

**MVP scope:**
- Arabic Word Recognition (30-50 words, multi-class classifier)
- 2 Tajweed rules (Ghunnah nasal sound, Madd elongation)
- Surah Al-Fatihah only (7 verses)
- Android only, English interface

**Repo:** `github.com/Abdalrahman-py/bayaan`
**Branch:** `dev` (PR to `main`)
**Your module:** `/backend`

---

## 2. Technology Stack (Decisions Already Made)

These are decided. Don't research alternatives — use exactly these.

| Concern | What we're using | Why (don't second-guess) |
|---------|-----------------|--------------------------|
| **Framework** | Ktor (Kotlin) | Same language as Android, coroutine-native, already scaffolded |
| **Auth** | Ktor JWT plugin (`ktor-server-auth-jwt`) | Verifies Supabase-issued JWTs locally. No network call needed. |
| **Database access** | Exposed ORM + HikariCP + JDBC | Direct PostgreSQL connection. NOT supabase-kt (that's a mobile SDK). |
| **Database host** | Supabase PostgreSQL | Free tier, same platform as auth, web dashboard |
| **Auth provider** | Supabase Auth | Issues JWTs. Android SDK handles sign-in UI. Backend only verifies tokens. |
| **Audio upload** | HTTP multipart/form-data | Simple, reliable, matches ML model architecture (needs complete clip) |
| **Audio conversion** | ffmpeg (called from Kotlin) | Converts Android's M4A to 16kHz WAV for ML inference |
| **ML pipeline** | ML-only (no STT/LLM/TTS) | wav2vec2 → pre-written feedback text. Simpler, cheaper, sufficient for demo. |
| **Deployment** | Railway + Dockerfile | $5/month Hobby plan. Auto-deploys on push. |
| **Serialization** | kotlinx.serialization | Kotlin-native, Ktor integration built-in |

**What we are NOT using (don't add these):**
- supabase-kt or PostgREST (mobile SDK, not for servers)
- Spring Boot (too heavy for 10 routes)
- Firebase Auth/Firestore (Supabase handles auth + DB)
- WebSocket streaming (stretch goal, not MVP)
- Groq Whisper / Claude / ElevenLabs (Phase 2, not now)
- Hibernate/JPA (too heavy, Exposed is sufficient)

---

## 3. Architecture at a Glance

```
Android App
    │
    │  HTTP request (with Supabase JWT)
    ↓
Ktor Backend (your code)
    │
    ├──→ JWT plugin verifies token locally (HS256, microseconds)
    │
    ├──→ ffmpeg converts M4A → 16kHz WAV
    │
    ├──→ POST http://localhost:8001/classify/ghunnah  (calls ML server)
    │
    ├──→ INSERT INTO sessions (via Exposed/JDBC)
    ├──→ INSERT INTO violations (via Exposed/JDBC)
    │
    └──→ Returns JSON response to Android

Supabase Auth: only touched at sign-in time (by Android, not backend)
Supabase PostgreSQL: direct JDBC connection from Ktor
Python ML Server: separate process, different port, called via HTTP
```

---

## 4. Your Tasks (R1 → R12)

Build in this order. Each task depends on the previous one. Test before moving on.

### Phase 1: Foundation

#### R1. Supabase Project + Environment

**What to do:**
1. Go to https://supabase.com, create account (GitHub login works)
2. Create a new project named `bayaan`
3. Choose region closest to Gaza/Egypt (`eu-central-1` Frankfurt or `ap-southeast-1` Singapore)
4. Save the database password securely
5. Go to SQL Editor, paste and run the schema from Section 5 of this document
6. Get these credentials from Project Settings → API:
   - Project URL: `https://xxxx.supabase.co`
   - `anon` public key (share with Issa for Android)
   - JWT Secret (backend only — never share with Android)
7. Get connection string from Project Settings → Database → Connection String
8. Convert it to JDBC format: `jdbc:postgresql://db.xxxx.supabase.co:5432/postgres?user=postgres&password=YOUR_PASSWORD`
9. Create `backend/.env`:
   ```
   SUPABASE_DB_URL=jdbc:postgresql://db.xxxx.supabase.co:5432/postgres?user=postgres&password=...
   SUPABASE_JWT_SECRET=your-jwt-secret-here
   PORT=8080
   ```
10. Share Project URL and `anon` key with Issa (he needs them for the Android Supabase SDK)

**Verify:** Run `psql "postgresql://db.xxxx.supabase.co:5432/postgres" -U postgres` — you should connect and see the `users`, `sessions`, `violations` tables.

**Google OAuth (optional, 5 min):**
- If we want Google sign-in: Abdalrahman enables it in Supabase dashboard
- You don't need to do anything — backend code is identical either way

---

#### R2. Ktor Dependencies + Project Structure

**What to do:**
1. The scaffold already exists at `backend/` with Application.kt and Routing.kt
2. Add these to `backend/build.gradle.kts`:

```kotlin
dependencies {
    // Existing (keep these):
    implementation(ktorLibs.server.config.yaml)
    implementation(ktorLibs.server.core)
    implementation(ktorLibs.server.netty)
    implementation(libs.logback.classic)
    testImplementation(kotlin("test"))
    testImplementation(ktorLibs.server.testHost)

    // Auth
    implementation("io.ktor:ktor-server-auth:$ktorVersion")
    implementation("io.ktor:ktor-server-auth-jwt:$ktorVersion")

    // Database
    implementation("org.jetbrains.exposed:exposed-core:0.57.0")
    implementation("org.jetbrains.exposed:exposed-dao:0.57.0")
    implementation("org.jetbrains.exposed:exposed-jdbc:0.57.0")
    implementation("org.postgresql:postgresql:42.7.4")
    implementation("com.zaxxer:HikariCP:6.2.1")

    // Serialization
    implementation("io.ktor:ktor-server-content-negotiation:$ktorVersion")
    implementation("io.ktor:ktor-serialization-kotlinx-json:$ktorVersion")

    // HTTP client (for calling ML server)
    implementation("io.ktor:ktor-client-core:$ktorVersion")
    implementation("io.ktor:ktor-client-cio:$ktorVersion")
    implementation("io.ktor:ktor-client-content-negotiation:$ktorVersion")
}
```

3. Organize source tree under `backend/src/main/kotlin/com/bayaan/`:
   ```
   plugins/
     AuthPlugin.kt          — JWT configuration
     DatabasePlugin.kt      — Exposed + HikariCP setup
     SerializationPlugin.kt — kotlinx.serialization config
   routes/
     AuthRoutes.kt          — POST /auth/sync
     AudioRoutes.kt         — POST /audio/analyze (Abdalrahman builds this)
     ProgressRoutes.kt      — GET /progress, /progress/sessions, etc.
     SurahRoutes.kt         — GET /surahs
   data/
     tables/
       Users.kt             — Exposed table object
       Sessions.kt
       Violations.kt
     repositories/
       UserRepository.kt
       SessionRepository.kt
       ViolationRepository.kt
   util/
     AudioConverter.kt      — ffmpeg wrapper
   Application.kt           — entry point (already exists)
   Routing.kt               — route registration (already exists)
   ```

4. **Verify:** `./gradlew build` compiles without errors.

---

### Phase 2: Auth

#### R3. JWT Verification Middleware

**What to build:**
- Ktor `Authentication` plugin with `jwt("auth-jwt")` provider
- HS256 verifier using `SUPABASE_JWT_SECRET` from environment
- Extracts `sub` claim (user UUID) from verified JWT → attaches to call context

**Key details:**
- Supabase JWTs use HS256. The `sub` claim is the user's UUID.
- The JWT is sent by Android in the `Authorization: Bearer *** See: https://ktor.io/docs/server-jwt.html
- On failure: return 401 with `{"error": "unauthorized", "message": "Token is not valid or expired"}`

**The plugin config (reference):**
```kotlin
install(Authentication) {
    jwt("auth-jwt") {
        realm = "bayaan"
        verifier {
            JWT.require(Algorithm.HMAC256(jwtSecret))
                .build()
        }
        validate { credential ->
            val userId = credential.payload.subject  // "sub" claim
            if (userId != null) JWTPrincipal(credential.payload)
            else null
        }
        challenge { _, _ ->
            call.respond(HttpStatusCode.Unauthorized,
                mapOf("error" to "unauthorized",
                      "message" to "Token is not valid or expired"))
        }
    }
}
```

**Test:** Write a test that:
- Sends invalid JWT → 401
- Sends valid JWT → extracts correct user ID from principal

To generate a test JWT, use https://jwt.io with HS256, paste your `SUPABASE_JWT_SECRET`, and set `sub` to a test UUID.

---

#### R4. POST /auth/sync

**What to build:**
- Protected endpoint (wrapped in `authenticate("auth-jwt")`)
- Reads user UUID from the verified JWT principal
- Upserts into `public.users` table (find or create by UUID)
- Returns `{"user_id": "...", "created": true}` or `{"user_id": "...", "created": false}`

**Route:**
```kotlin
authenticate("auth-jwt") {
    post("/auth/sync") {
        val principal = call.principal<JWTPrincipal>()
        val userId = UUID.fromString(principal!!.payload.subject)
        val created = userRepository.upsert(userId)
        call.respond(mapOf("user_id" to userId.toString(), "created" to created))
    }
}
```

**UserRepository.upsert:**
```kotlin
suspend fun upsert(userId: UUID): Boolean {
    return dbQuery {
        val existing = Users.selectAll().where { Users.id eq userId }.singleOrNull()
        if (existing == null) {
            Users.insert { it[id] = userId }
            true
        } else {
            false
        }
    }
}
```

**Test:** Call endpoint with valid JWT → user row appears in database. Call again → `created: false`.

---

### Phase 3: Database Layer

#### R5. Database Connection + Exposed Setup

**What to build:**
- `DatabaseFactory` that reads `SUPABASE_DB_URL` from env and creates a HikariCP connection pool
- Exposed table objects matching the schema (Section 5)

**DatabaseFactory:**
```kotlin
object DatabaseFactory {
    fun init() {
        val dbUrl = System.getenv("SUPABASE_DB_URL")
            ?: throw IllegalStateException("SUPABASE_DB_URL not set")
        Database.connect(
            url = dbUrl,
            driver = "org.postgresql.Driver",
            // HikariCP auto-configured by Exposed
        )
    }
}
```

**Table objects (reference — match exactly):**
```kotlin
object Users : UUIDTable("users") {
    // id comes from Supabase Auth (auth.users)
    val email = text("email").nullable()
    val createdAt = datetime("created_at").default(Instant.now())
}

object Sessions : UUIDTable("sessions") {
    val userId = reference("user_id", Users)
    val surah = text("surah")
    val verse = integer("verse")
    val createdAt = datetime("created_at").default(Instant.now())
}

object Violations : UUIDTable("violations") {
    val sessionId = reference("session_id", Sessions)
    val rule = text("rule")       // "ghunnah" | "madd"
    val wordIndex = integer("word_index")
    val confidence = float("confidence")
    val correct = bool("correct")
}
```

**Helper for coroutine transactions:**
```kotlin
suspend fun <T> dbQuery(block: Transaction.() -> T): T =
    newSuspendedTransaction(Dispatchers.IO, statement = block)
```

**Test:** Connect, insert a test user row, read it back, drop it.

---

#### R6. Repository Classes

**What to build:**

**UserRepository:**
```kotlin
class UserRepository {
    suspend fun findById(id: UUID): UserRow?
    suspend fun upsert(id: UUID): Boolean  // true = created, false = already existed
}
```

**SessionRepository:**
```kotlin
class SessionRepository {
    suspend fun insert(userId: UUID, surah: String, verse: Int): UUID  // returns session ID
    suspend fun findByUser(userId: UUID, limit: Int, offset: Int): List<SessionRow>
    suspend fun countByUser(userId: UUID): Long
    suspend fun findById(sessionId: UUID): SessionRow?
}
```

**ViolationRepository:**
```kotlin
class ViolationRepository {
    suspend fun insertBatch(sessionId: UUID, violations: List<ViolationInput>)
    suspend fun findBySession(sessionId: UUID): List<ViolationRow>
    suspend fun countByUserAndRule(userId: UUID, rule: String): Long
    suspend fun countByUserAndRuleCorrect(userId: UUID, rule: String): Long
}
```

**ViolationInput data class:**
```kotlin
data class ViolationInput(
    val rule: String,
    val wordIndex: Int,
    val confidence: Float,
    val correct: Boolean
)
```

**Every method must be suspendable.** Use the `dbQuery` helper from R5.

**Test:** Insert a session with 3 violations → query back → verify all fields match.

---

### Phase 4: Progress Endpoints

All of these are protected (wrap in `authenticate("auth-jwt")`).

#### R7. GET /progress

Returns per-rule stats for the authenticated user.

**Response shape:**
```json
{
  "total_sessions": 14,
  "rules": {
    "ghunnah": {
      "total_attempts": 42,
      "correct": 35,
      "accuracy": 0.833
    },
    "madd": {
      "total_attempts": 38,
      "correct": 28,
      "accuracy": 0.737
    }
  }
}
```

**Implementation:**
- Get user UUID from JWT principal
- Count total sessions for user
- For each rule ("ghunnah", "madd"):
  - Count total violations with that rule
  - Count violations where correct = true
  - accuracy = correct / total (or 0.0 if no attempts)

**Test:** Empty user → `{"total_sessions": 0, "rules": {}}`. User with 10 sessions → correct stats.

---

#### R8. GET /progress/sessions

Paginated session history, newest first.

**Query params:** `limit` (default 20, max 100), `offset` (default 0)

**Response shape:**
```json
{
  "sessions": [
    {
      "session_id": "uuid",
      "surah": "al-fatihah",
      "verse": 1,
      "violations_count": 1,
      "overall_correct": false,
      "created_at": "2026-05-29T14:32:00Z"
    }
  ],
  "total": 14,
  "limit": 20,
  "offset": 0
}
```

**Implementation:**
- Query sessions for user, ordered by created_at DESC
- Apply limit and offset
- For each session, count violations and check if any are incorrect

**Test:** Insert 50 test sessions, request page 2 (offset=20, limit=20) → returns sessions 20-39.

---

#### R9. GET /progress/sessions/{session_id}

Full detail for a single session including all violations.

**Response shape:**
```json
{
  "session_id": "uuid",
  "surah": "al-fatihah",
  "verse": 1,
  "created_at": "2026-05-29T14:32:00Z",
  "violations": [
    {
      "rule": "ghunnah",
      "word_index": 3,
      "word_text": "الرَّحِيمِ",
      "confidence": 0.87,
      "correct": false,
      "feedback": "Apply 2-count nasal sound on the meem with shadda."
    }
  ]
}
```

**Implementation:**
- Find session by ID
- Verify `session.userId == authenticatedUserId` → 404 if not
- Query all violations for that session
- Map violations to response shape (feedback text is pre-written per rule — see Section 6)

**Test:** User A's session ID, accessed with user B's JWT → 404.

---

#### R10. GET /surahs

Public endpoint (no auth required). Returns available surahs for practice.

**Response shape:**
```json
{
  "surahs": [
    {
      "id": "al-fatihah",
      "name_arabic": "الفاتحة",
      "name_english": "Al-Fatihah",
      "verse_count": 7,
      "available": true
    }
  ]
}
```

**Implementation:** Hardcoded for MVP. Just return Al-Fatihah. When more surahs are added, this becomes a database query.

**Test:** GET /surahs → single surah with correct fields. No auth header needed.

---

### Phase 5: Infrastructure

#### R11. Audio Format Conversion (ffmpeg)

**Why:** Android's MediaRecorder outputs M4A/AAC. Our ML model expects 16kHz mono WAV. The backend converts.

**What to build:**
```kotlin
object AudioConverter {
    fun convertToWav(inputBytes: ByteArray): ByteArray {
        val process = ProcessBuilder(
            "ffmpeg",
            "-i", "pipe:0",          // read from stdin
            "-ar", "16000",           // 16kHz sample rate
            "-ac", "1",               // mono
            "-f", "wav",              // WAV format
            "-v", "quiet",            // suppress logs
            "pipe:1"                  // output to stdout
        ).start()

        process.outputStream.use { it.write(inputBytes) }
        val wavBytes = process.inputStream.readBytes()
        val exitCode = process.waitFor()

        if (exitCode != 0) {
            val error = process.errorStream.readBytes().toString(Charsets.UTF_8)
            throw AudioConversionException("ffmpeg failed: $error")
        }
        return wavBytes
    }
}

class AudioConversionException(message: String) : Exception(message)
```

**On Jade's laptop:** ffmpeg is installed via Flatpak. For local testing, you may need: `flatpak run --command=ffmpeg org.freedesktop.Platform//25.08` instead of just `ffmpeg`. The Docker image on Railway has standard ffmpeg.

**Returns:** 16kHz mono WAV bytes, ready for ML inference.

**Test:** Take a sample M4A file, convert it, verify output is valid WAV with correct sample rate (check header bytes or use ffprobe).

---

#### R12. Railway Deployment

**Dockerfile** (create in `backend/Dockerfile`):
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

**Configuration:**
- In `application.conf`, read port from env: `port = ${?PORT}`
- Bind to `0.0.0.0` (Railway requirement)

**Deploy steps:**
1. Go to https://railway.com, sign in with GitHub
2. Click "New Project" → "Deploy from GitHub repo"
3. Select `Abdalrahman-py/bayaan`
4. Set root directory to `backend/`
5. Add environment variables: `SUPABASE_DB_URL`, `SUPABASE_JWT_SECRET`, `PORT`
6. Deploy — Railway auto-detects the Gradle project

**Cost:** $5/month (Hobby plan). Abdalrahman handles this.

**Verify:** `curl https://your-app.railway.app/health` → `{"status": "ok"}`

---

## 5. Database Schema

Run this EXACTLY in the Supabase SQL Editor (Project → SQL Editor):

```sql
-- Users table: one row per signed-in user
-- id comes from Supabase Auth (auth.users), which is auto-created
CREATE TABLE public.users (
    id          UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email       TEXT,
    created_at  TIMESTAMPTZ DEFAULT now()
);

-- Sessions table: one row per recitation attempt
CREATE TABLE public.sessions (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID REFERENCES public.users(id) ON DELETE CASCADE,
    surah       TEXT NOT NULL,
    verse       INTEGER NOT NULL,
    created_at  TIMESTAMPTZ DEFAULT now()
);

-- Violations table: one row per detected violation in a session
CREATE TABLE public.violations (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id   UUID REFERENCES public.sessions(id) ON DELETE CASCADE,
    rule         TEXT NOT NULL,       -- "ghunnah" | "madd"
    word_index   INTEGER NOT NULL,    -- position in verse (0-indexed)
    confidence   FLOAT NOT NULL,      -- model confidence 0.0–1.0
    correct      BOOLEAN NOT NULL     -- true = rule applied correctly
);

-- Row Level Security: users can only access their own data (safety net)
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

**Verify:** In Table Editor, you should see `users`, `sessions`, `violations` under `public` schema.

---

## 6. API Contracts You Own

These are the endpoints you build. Match the response shapes exactly — Issa's Android code will depend on them.

| Endpoint | Method | Auth | What it does | Doc reference |
|----------|--------|------|-------------|---------------|
| `/auth/sync` | POST | Yes | Sync Supabase Auth user into public.users | R4 above |
| `/progress` | GET | Yes | Per-rule accuracy stats | R7 above |
| `/progress/sessions` | GET | Yes | Paginated session history | R8 above |
| `/progress/sessions/{id}` | GET | Yes | Single session with violations | R9 above |
| `/surahs` | GET | No | Available surahs list | R10 above |
| `/health` | GET | No | Liveness check | Already exists |

**Endpoints Abdalrahman builds (you don't touch these):**
| `/audio/analyze` | POST | Yes | Audio upload + ML analysis | M8 (Abdalrahman) |

**The full API spec:** `docs/api-spec.md` in the repo — has exact request/response shapes for every endpoint. Match it.

**Pre-written feedback text** (used by M8, hardcoded for now):
- Ghunnah violation: `"Apply 2-count nasal sound on the meem with shadda."`
- Madd violation: `"Hold the vowel for the correct number of counts."`

---

## 7. Dependency Chain

```
You (Ramzi):   R1 → R2 → R3 → R4 → R5 → R6 → R7,R8,R9,R10 → R11 → R12

Jade (ML):     M1,M2,M3 → M4,M5,M6 → M7 → M8,M9
```

**What Jade needs from you:**
- R3 (JWT middleware) → M8 uses it for user identity
- R6 (repositories) → M8 uses them to save session/violation data
- R11 (ffmpeg utility) → M8 calls it to convert audio

**You can work independently of Jade.** Your R1–R10 and his M1–M7 are completely parallel. The coupling only happens at his M8, which is weeks away.

**Testing without Jade:** Insert test data into PostgreSQL directly via psql or the Supabase SQL Editor. Example:
```sql
INSERT INTO public.users (id) VALUES ('00000000-0000-0000-0000-000000000001');
INSERT INTO public.sessions (id, user_id, surah, verse)
VALUES (gen_random_uuid(), '00000000-0000-0000-0000-000000000001', 'al-fatihah', 1);
```

---

## 8. Testing

Every endpoint needs at least one test. Use Ktor's `testApplication {}`:

```kotlin
@Test
fun `GET /progress returns stats for authenticated user`() = testApplication {
    application { module() }
    val response = client.get("/progress") {
        header("Authorization", "Bearer $validTestJwt")
    }
    assertEquals(HttpStatusCode.OK, response.status)
    // Verify response shape
}
```

**Test data strategy:**
- Generate a test JWT at https://jwt.io with HS256, your `SUPABASE_JWT_SECRET`, and `sub` set to a test UUID
- Insert test data into Postgres via psql before running tests
- Test both success and failure cases (missing JWT → 401, wrong user's data → 404)

**What to test:**
- Auth: missing JWT → 401, invalid JWT → 401, valid JWT → extracted user ID
- Progress: empty user → zero stats, user with data → correct stats
- Sessions: pagination (page 2 returns correct offset), cross-user access → 404
- Surahs: public access works, returns correct data

---

## 9. Error Handling

All error responses must follow this shape:
```json
{"error": "short_snake_case_code", "message": "Human-readable description"}
```

| Situation | HTTP | Error code |
|-----------|------|-----------|
| Missing/invalid JWT | 401 | `unauthorized` |
| Session not found | 404 | `not_found` |
| Session belongs to another user | 404 | `not_found` |
| Malformed request body | 400 | `bad_request` |
| Audio processing failed | 422 | `unprocessable_audio` |
| Database connection lost | 503 | `service_unavailable` |

---

## 10. Environment Variables

In `backend/.env` (never committed — already in `.gitignore`):

| Variable | Description | Example |
|----------|-------------|---------|
| `SUPABASE_DB_URL` | JDBC connection string | `jdbc:postgresql://db.xxxx.supabase.co:5432/postgres?user=postgres&password=...` |
| `SUPABASE_JWT_SECRET` | HS256 shared secret | From Supabase → Settings → API → JWT Secret |
| `PORT` | Server port (Railway sets this) | `8080` locally, Railway provides it |

---

## 11. What NOT to Build

These are either Abdalrahman's responsibility or out of MVP scope:

- **POST /audio/analyze** — Abdalrahman builds this (M8). You provide R3, R6, R11.
- **User sign-in/sign-up UI** — Android team (Issa) builds this with Supabase SDK.
- **Password reset, email verification** — Supabase Auth handles it automatically.
- **WebSocket endpoint** — Stretch goal, not MVP.
- **Groq Whisper / Claude / ElevenLabs integration** — Phase 2, cut from MVP.
- **Firebase Auth / Firestore** — Supabase replaces both.
- **The ML model or inference server** — Abdalrahman's domain.
- **Dockerfile optimizations beyond what's in R12** — Not needed for MVP scale.

---

## 12. Reference Files in the Repo

| File | What it covers |
|------|---------------|
| `docs/architecture.md` | Full system diagram, data flows, module responsibilities |
| `docs/api-spec.md` | Exact request/response shapes for every endpoint |
| `docs/supabase-setup.md` | Supabase reference with setup steps |
| `docs/backend-review.md` | Full architecture review with all decisions |
| `docs/team-roles.md` | Who owns what |
| `backend/AGENTS.md` | AI agent rules for the backend module |
| `README.md` | Project overview, getting started, branch strategy |

---

## Questions?

If something isn't covered here, ask Abdalrahman. If you discover something that SHOULD be in this doc, tell him and he'll add it. Don't guess on architecture decisions — everything here was researched and chosen deliberately.

Start from R1. Build in order. Test each step.

---

## Related (vault)

- [[Diploma-Graduation-Project]] — parent project hub
- [[bayaan-backend-harsh-review]] — full architecture review
- [[bayaan-supabase-reference]] — Supabase setup reference
- [[2026-06-10-bayaan-backend-crash-course]] — crash course on every tech choice
- [[bayaan-project-document]] — full proposal
