---
type: resource
project: "Diploma Graduation Project"
entities: [Mahmoud Abu Jadallah]
date: 2026-06-10
tags: [bayaan, supabase, backend, reference, ramzi]
summary: "Supabase reference for Bayaan — what it is, why we picked it, what pieces we use, how to set it up, schema, env vars, and the Android integration flow. Written for Ramzi."
---

# Bayaan — Supabase Reference

Everything Ramzi needs to know about Supabase for Bayaan. What it is, why it's here, how to set it up, and where the boundaries are.

---

## What Supabase Is

Supabase is two services under one roof:

| Service | What it does | Bayaan uses it for |
|---------|-------------|-------------------|
| **Supabase Auth** | User sign-up, sign-in, password reset, OAuth, issues JWTs | All user authentication. Android signs in via the Supabase SDK. Backend verifies the resulting JWT locally. |
| **Supabase PostgreSQL** | Hosted PostgreSQL database with a web dashboard | Storing users, sessions, violations. Backend connects directly via JDBC. |

That's it. Supabase also has file storage, realtime subscriptions, edge functions, and vector search. Bayaan uses none of those.

---

## Why Supabase

### The problem it solves

Without Supabase, you'd need two separate services:

1. **An auth provider** (Auth0, Firebase Auth, Clerk, etc.) for sign-in
2. **A database host** (Railway PostgreSQL, Neon, AWS RDS, etc.) for data

That means two accounts, two bills, two sets of API keys, two dashboards, and the plumbing to connect them (auth provider issues user ID → database stores it).

Supabase combines both. One account, one dashboard, free tier covers everything Bayaan needs, and the user ID from Auth IS the primary key in the database — no wiring needed.

### Why not the alternatives

| Alternative | Problem |
|-------------|---------|
| **Firebase** | Google proprietary. Firestore is NoSQL — bad for relational data like session→violations. Vendor lock-in. |
| **Auth0 + Railway PostgreSQL** | Two services, two bills, Auth0 free tier is limited. Supabase combines them. |
| **Build auth from scratch** | Password hashing, email verification, password reset, session management — weeks of work on security-sensitive code. Supabase gives it for free. |
| **Railway PostgreSQL alone + hardcoded users** | No real auth. Can't tell users apart securely. Unacceptable for a graded project. |

---

## What We Use (and What We Skip)

### We use:

| Feature | Details |
|---------|---------|
| **Supabase Auth — email/password** | Primary sign-in method. Android SDK handles the UI. |
| **Supabase Auth — Google OAuth** | Optional. Enable in dashboard, add Google Client ID. One-click. |
| **Supabase Auth — JWT issuance** | After sign-in, Supabase gives Android a JWT. Android sends it to backend on every request. |
| **Supabase PostgreSQL** | Direct JDBC connection from Ktor. Three tables: users, sessions, violations. |
| **Supabase Dashboard** | Web UI for managing auth users, running SQL, viewing tables. |
| **Row Level Security** | Database-enforced rules: user A can never read user B's data. Safety net. |

### We do NOT use:

| Feature | Why we skip it |
|---------|---------------|
| **PostgREST / Data API** | Auto-generates REST API. Adds HTTP latency. We query PostgreSQL directly via JDBC. |
| **Realtime** | WebSocket subscriptions. Not needed — Bayaan is request/response, not live collaboration. |
| **Storage** | File hosting (S3-like). Audio files are processed and discarded — no permanent storage needed. |
| **Edge Functions** | Serverless Deno functions. We have a whole Ktor backend — no need for serverless. |

---

## How the Pieces Fit Together

### Sign-in flow (happens once per user):

```
1. User opens Bayaan app
2. Android shows sign-in screen (Supabase SDK provides the UI)
3. User enters email + password  (or taps "Sign in with Google")
4. Supabase Auth verifies credentials
5. Supabase returns a JWT to Android
6. Android stores the JWT
7. Android calls POST /auth/sync on the Ktor backend (with JWT)
8. Backend verifies JWT locally → extracts user UUID → upserts into users table
9. User is now "signed in" — JWT is attached to every subsequent request
```

### Every subsequent request:

```
1. Android wants to analyze an audio clip
2. Android sends POST /audio/analyze with:
   - audio file
   - JWT in Authorization header
3. Ktor JWT plugin verifies the signature (local math, microseconds)
4. Extracts user UUID from JWT payload
5. Processes audio → calls ML → gets violations
6. Inserts session row (with user UUID) into sessions table
7. Inserts violation rows (linked to session) into violations table
8. Returns results to Android
```

### The key insight:

**Supabase Auth is only touched during sign-in.** After that, the backend never calls Supabase. JWT verification is local. Database queries are direct JDBC. Supabase Auth and Supabase PostgreSQL are connected only by the user UUID — Auth creates it, the JWT carries it, the database stores it.

```
┌─────────────────────┐
│   Supabase Auth     │  ← Only used at sign-in
│   issues JWT once   │
└────────┬────────────┘
         │ JWT
         ↓
┌─────────────────────┐
│   Android App       │  ← Stores JWT, sends on every request
└────────┬────────────┘
         │ JWT + request
         ↓
┌─────────────────────┐     ┌──────────────────────┐
│   Ktor Backend      │────→│  Supabase PostgreSQL │  ← Direct JDBC
│   verifies JWT      │     │  users/sessions/     │
│   locally (HS256)   │     │  violations          │
└─────────────────────┘     └──────────────────────┘
```

---

## Setup Steps (for Ramzi)

### Step 1: Create the Supabase project

1. Go to https://supabase.com and sign up (GitHub login works)
2. Click "New project"
3. Name: `bayaan`
4. Database password: generate a strong one, save it
5. Region: choose the closest to your users (for Gaza/Egypt, `eu-central-1` Frankfurt or `ap-southeast-1` Singapore)
6. Wait 2 minutes for the database to provision

### Step 2: Get the credentials

Go to Project Settings → API. You'll see:

| Credential | What it's for | Who needs it |
|-----------|---------------|-------------|
| **Project URL** | `https://xxxx.supabase.co` | Android (Issa), Backend |
| **anon public key** | Safe to include in the Android app | Android (Issa) |
| **JWT Secret** | Used by Ktor to verify tokens | Backend only — NEVER share with Android |
| **Database connection string** | For direct JDBC connection | Backend only |

The connection string is in Project Settings → Database → Connection string. It looks like:

```
postgresql://postgres:[YOUR-PASSWORD]@db.xxxx.supabase.co:5432/postgres
```

Convert to JDBC format:

```
jdbc:postgresql://db.xxxx.supabase.co:5432/postgres?user=postgres&password=[YOUR-PASSWORD]
```

### Step 3: Run the schema SQL

Go to SQL Editor in the Supabase dashboard. Paste and run:

```sql
-- Users table: one row per signed-in user
-- The id comes from Supabase Auth (auth.users)
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
    rule         TEXT NOT NULL,
    word_index   INTEGER NOT NULL,
    confidence   FLOAT NOT NULL,
    correct      BOOLEAN NOT NULL
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

Verify: in the Table Editor, you should see `users`, `sessions`, `violations` under `public`.

### Step 4: Fill in backend .env

In `bayaan/backend/.env`:

```
SUPABASE_JWT_SECRET=your-jwt-secret-from-dashboard
SUPABASE_DB_URL=jdbc:postgresql://db.xxxx.supabase.co:5432/postgres?user=postgres&password=your-password
PORT=8080
```

Never commit this file. It's already in `.gitignore`.

### Step 5: Share with Android team

Give Issa:
- Project URL: `https://xxxx.supabase.co`
- Anon key: the long string labeled "anon public"

He'll use these with the Supabase Android SDK for sign-in. That's all he needs.

---

## Google OAuth (Optional — Enable If You Want)

### Why Google OAuth?

Instead of typing email + password, users tap "Sign in with Google." Their Google account is used for authentication. No password to remember. No email verification step.

### Setup (5 minutes)

1. Go to Google Cloud Console → APIs & Services → Credentials
2. Create an OAuth 2.0 Client ID (Web application type)
3. Add authorized redirect URI from Supabase dashboard (Authentication → Providers → Google)
4. Copy Client ID and Client Secret
5. In Supabase dashboard → Authentication → Providers → Google:
   - Enable
   - Paste Client ID and Client Secret
6. That's it — Android Supabase SDK handles the rest

### Does this change anything on the backend?

No. Google OAuth vs email/password is entirely handled by Supabase Auth. The backend receives the same JWT format either way. The user UUID is the same. No backend code changes needed.

### Should we enable it?

For a graduation demo: nice-to-have, not essential. Email/password works fine for 5-10 test users. Google OAuth is a 5-minute setup — enable it if you have time, skip it if not.

---

## Data Flow Reference

```
USER SIGN-UP (happens once per user)
═══════════════════════════════════
Android: Supabase SDK → signUp(email, password)
Supabase: Creates user in auth.users, sends confirmation email
User: Clicks confirmation link in email
Android: Supabase SDK → signIn(email, password)
Supabase: Returns JWT
Android: POST /auth/sync (JWT in header)
Backend: Extracts UUID from JWT, upserts into public.users
         Returns {user_id: "...", created: true}


RECITATION SESSION (every time user practices)
══════════════════════════════════════════════
Android: Records audio
Android: POST /audio/analyze (multipart: audio file + JWT)
Backend: JWT plugin verifies token → extracts user UUID
Backend: ffmpeg converts M4A → 16kHz WAV
Backend: POST http://localhost:8001/classify/ghunnah (WAV bytes)
ML Server: wav2vec2 inference → {violation: true, confidence: 0.87}
Backend: INSERT INTO sessions (user_id, surah, verse)
Backend: INSERT INTO violations (session_id, rule, word_index, confidence, correct)
Backend: Returns JSON with violations + pre-written feedback
Android: Shows results to user


PROGRESS CHECK (when user views stats)
═════════════════════════════════════
Android: GET /progress (JWT in header)
Backend: JWT plugin verifies token → extracts user UUID
Backend: SELECT FROM sessions WHERE user_id = ? 
         SELECT FROM violations WHERE session_id IN (...)
Backend: Calculates per-rule accuracy
Backend: Returns JSON with stats
Android: Shows progress dashboard


USER B CANNOT SEE USER A'S DATA (enforced at database level)
═════════════════════════════════════════════════════════════
Backend: SELECT * FROM sessions WHERE user_id = ?
         (always filters by the authenticated user's UUID)
Plus: Row Level Security as safety net — 
         even if a bug forgets the WHERE clause, RLS blocks the query
```

---

## Free Tier Limits (Reality Check)

| Resource | Free tier limit | Bayaan's usage | Safe? |
|----------|----------------|---------------|-------|
| Database size | 500 MB | ~5 MB | Yes |
| Monthly active users (auth) | 50,000 | ~10 | Yes |
| Projects | 2 | 1 | Yes |
| Database connections | 20 direct | ~5 (HikariCP pool) | Yes |
| Bandwidth | 5 GB/month | <100 MB | Yes |
| Auto-suspension | After 1 week inactive | Won't happen (project is active) | Yes |

Supabase is genuinely free for Bayaan's scale. No credit card needed.

---

## Related

- [[Diploma-Graduation-Project]] — parent project hub
- [[bayaan-backend-harsh-review]] — backend architecture review with all decisions
- [[2026-06-10-bayaan-backend-crash-course]] — crash course explaining every term
- [[bayaan-project-document]] — full proposal
- [[2026-05-25-bayaan-team-task-breakdown]] — original team task breakdown
