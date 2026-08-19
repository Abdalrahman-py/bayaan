# Decision — Backend hosting: Supabase Edge Functions vs Ktor on Render

> Status: **spike complete — migration recommended, not yet executed**.
> Spike run 2026-08-09. Source code: `spike/edge-functions/`
> (`spike-speech-grade`, `spike-audio-analyze`). Live deployments exist on the
> bayaan Supabase project (both `verify_jwt=true`).
> Context: `docs/ROADMAP.md` (Edge Functions listed under "Explicitly deferred"),
> `docs/CODEBASE_MAP.md` §8 (hosting rationale, contains a now-stale claim about
> Edge time limits — see §Results).

## Question

Bayaan's backend is a thin Ktor proxy on Render (free tier) that verifies JWTs,
forwards audio to the Muaalem engine on Modal, and persists results to Supabase
Postgres. Since Supabase already hosts our auth + database, should the proxy layer
move to **Supabase Edge Functions** (Deno), eliminating Render entirely?

## What the backend actually does (13 routes)

| Group | Routes | Nature |
|---|---|---|
| Modal proxies | `POST /audio/analyze`, `POST /speech/grade` | multipart audio in → Modal → normalized JSON out |
| Learn | `GET /learn/path`, `POST /learn/complete`, `GET /learn/reviews`, `POST /learn/reviews/{id}/result`, `POST /learn/placement` | DB-heavy: SRS scheduler, XP, streaks, curriculum gating |
| Progress | `GET /progress`, `GET /progress/sessions`, `GET /progress/sessions/{id}` | DB aggregates + ownership checks |
| Trivial | `GET /health`, `GET /surahs`, `POST /auth/sync` | liveness / hardcoded / upsert |

## Method (what the spike actually tested)

- Ported **both Modal-proxy routes** 1:1 to Deno Edge Functions (`spike/edge-functions/`),
  including the speech-grade tolerance-policy normalizer (`SpeechGradeNormalizer.kt`
  → TypeScript) and the `/audio/analyze` persistence path (engine parser + users /
  sessions / mistakes / sifat_mistakes writes via service-role PostgREST).
- Deployed via Supabase MCP (`deploy_edge_function`, `verify_jwt=true`).
- Tested: auth gate, boundary validation, body-size limits, cold vs warm latency,
  real-audio grading, **parity against the live Ktor backend**, and DB persistence.
- The 11 DB routes were NOT ported — they are the remaining work.

## Results

### Parity — the decisive test

Same request (real `ba_madd.ogg` clip, ref `بَا`), same JWT, both paths:

| Path | Response | Latency |
|---|---|---|
| **Edge Function** (warm) | `fail / 0.45 / length_short @[2,3]` | **1.6s** |
| **Ktor on Render** (cold) | `fail / 0.45 / length_short @[2,3]` | 31.9s |

**Byte-identical JSON** — the TypeScript normalizer port is faithful.

### Full test matrix

| Test | Result |
|---|---|
| No JWT → auth gate | 401 ✅ |
| Boundary validation (missing/empty fields) | 400, Ktor-identical error shape ✅ |
| Audio > 10MB | 413 from our own cap (body passed the platform boundary) ✅ |
| 9.5MB upload | reached Modal (OOM was unrealistic 311s synthetic input) ✅ |
| Cold call (Modal scaling up) | 20–26s ✅ |
| Warm call | 1.1–1.6s ✅ |
| Real-audio grading | identical verdict to Ktor ✅ |
| Persistence (sessions/mistakes/sifat_mistakes) | rows confirmed in Postgres via SQL ✅ |
| Edge Function boot | 17–18ms (from function logs) ✅ |

### Stale documentation found

`CODEBASE_MAP.md` §8 says: *"keep /audio/analyze on Ktor/Modal — its 60s cold-start
doesn't fit Edge time limits."* **Verified against Supabase docs (2026-08-09): the
free-tier Edge Function wall-clock limit is 150s** (paid 400s), comfortably above the
60s Modal budget. The stated blocker is gone. CPU limit is 2s/request but **async I/O
doesn't count** — waiting on Modal's fetch is free.

## Analysis

### Why migrate (the real reasons)

1. **Latency.** Removes Render's 30–60s cold start from the stack. Cold = Modal only
   (20–26s); warm = ~1.1–1.6s. The demo warm-up ritual (hit `/health`, throwaway
   analyze) becomes unnecessary.
2. **Architecture.** One backend platform instead of two. Auth, DB, and API all in
   Supabase; the app talks to one provider. `verify_jwt=true` replaces the entire
   JWKS/ES256 plugin in Ktor — Supabase validates the JWT and injects the user
   (`x-supabase-auth` header).
3. **Operational simplicity.** No Render dashboard, no Docker build, no second
   deploy target. Function logs via Supabase.
4. **Cost at scale (hypothetical).** Render free → $7/mo Starter when outgrown;
   Edge Functions stay free at our scale (500K invocations/mo included).

### Why NOT migrate (honest counterweight)

1. **Cost today is $0 either way.** Render free tier costs nothing. This migration
   buys architecture + latency, not money.
2. **Rewriting tested code.** The Ktor backend has 9 test files (H2-backed route
   tests, normalizer tests, JWKS test harness). That safety net must be rebuilt for
   Deno/RPC — typically half the work.
3. **The atomicity problem.** `/learn/complete` does 6 writes in one logical unit
   (attempt + progress + XP + profile + streak + review push). PostgREST (the spike's
   approach) is one-table-per-call, **no transactions**. Options: Postgres RPC
   functions (`supabase.rpc`, atomic, but logic moves to PL/pgSQL) or a direct
   Postgres connection from the function (transactions, DB URL becomes a secret).
4. **Curriculum file.** Backend reads `curriculum.json` from its classpath; Edge
   Functions have no persistent filesystem. Must bundle it, store it in Supabase
   Storage, or (decision) move it to a DB table.
5. **RLS is ON with zero policies** on all public tables. Today only the backend's
   direct DB connection can write. Edge Function persistence needs the
   `SERVICE_ROLE_KEY` secret (same trust level as HikariCP) — or RLS policies must
   be added first. The spike uses the service-role path.

### Cost summary (2026-08-09 prices, verified)

| | Render (today) | Edge Functions (today) |
|---|---|---|
| Free tier | $0 (750 hrs/mo, 5GB bandwidth, sleeps after 15 min) | $0 (500K invocations/mo) |
| When outgrown | $7/mo Starter per service | Pro plan $25/mo flat (400s limit, RLS session controls) |

## Verdict

**Migrate — but as a sequenced project, not a rewrite-before-demo.** The spike
proved the hard parts (body-size boundary, Modal forwarding, parity, persistence);
the remaining work is mechanical but real: 11 DB routes, the atomicity decision
(RPC vs direct-DB), curriculum placement, and a rebuilt test suite.

Recommendation, in order:

1. **Decide RPC vs direct-DB** — the one architectural fork that shapes everything.
   Leaning: Postgres RPC functions for the learn/progress routes (atomic, and they
   stay close to the data); Edge Function only as the auth-gated HTTP layer. But this
   deserves its own spike before committing.
2. **Port `/learn/*` first** — riskiest logic (SRS ladder, XP, streaks, mastery
   thresholds). The rest is mechanical.
3. **Run Ktor in parallel** until route-by-route parity is verified (same
   request-response harness used in this spike).
4. **Flip the app last** — `LearnApi.kt` base URL is one line
   (`BuildConfig.BACKEND_URL`), but requires an APK rebuild. Keep Render alive as a
   one-command rollback until the new stack has been exercised on device.

**Effort estimate: 5–6 focused sessions (~2.5–3 days)** including tests, parity
verification, and the app switch. The spike already banked ~20% of it.

## RPC-vs-direct-DB spike (2026-08-09)

Ported `LessonRepository.recordAttempt` + `ProfileRepository.addXp/bumpStreak` +
`ReviewRepository.pushWeak` (today: 6 separate `dbQuery` transactions, not
actually atomic — a crash mid-request can leave an attempt recorded but XP/streak
unbumped) into one function: `learn_complete()`, `backend/sql/0002_learn_complete_rpc.sql`.
Deployed live, verified: single call writes `lesson_attempts`, `lesson_progress`,
`xp_events`, `profiles` (xp + streak), `review_items` — all 4 tables confirmed via
SQL, then cleaned up.

**Verdict: RPC.** Direct-DB (raw Postgres connection from the Edge Function,
transaction hand-written in TS) was not deployed — it needs `SUPABASE_DB_URL`
(with password) as a function secret, which nobody should hand an agent to type in.
Not needed to decide anyway:

- **Round trips.** RPC = 1 network hop Edge Function → Postgres. Direct-DB = 6
  (one per write), each paying full pooler RTT — the same shape of cost this
  whole migration exists to remove from Render.
- **Atomicity is free.** A Postgres function body is one transaction by default.
  Direct-DB requires hand-rolled `BEGIN`/`COMMIT` plus connection lifecycle
  management inside a stateless Edge Function — exactly the kind of thing that
  breaks under cold starts / concurrent invocations.
- **Supabase's pooler (pgbouncer, transaction mode) is known to fight prepared
  statements** from JS Postgres drivers (`postgres.js`, `pg`) — a live footgun
  for direct-DB, a non-issue for RPC since PostgREST already handles it.

Logic lives in PL/pgSQL now instead of Kotlin/TS — the one real cost — but it's
one function, not scattered across 4 repositories, and it's the same file either
way once ported (Ktor's Exposed code doesn't come along for free either).

## Open items before committing

- [x] RPC-vs-direct-DB spike for `/learn/complete` atomicity — **RPC**, see above
- [x] Curriculum: moved into `curriculum_units` + `curriculum_lessons` tables
      (backend/sql/0005), seeded 1:1 from content/curriculum.json (11 units, 44
      lessons — verified via count query post-migration). Closes the hand-copy
      debt from `Curriculum.kt` for real (owner explicitly wanted DB, not a
      relocated file). `learn` reads both tables per request via service-role
      PostgREST, same pattern as everything else it reads.
- [x] Decision on RLS policies vs service-role key for the new functions —
      **service-role key** (matches spike; RLS stays zero-policy). Writes go
      through RPC (`learn_complete`, `review_record_result`, `record_placement`,
      SECURITY DEFINER) for atomicity; reads use service-role PostgREST.
- [x] All 13 routes ported to Edge Functions (2026-08-19): `health`, `surahs`,
      `auth-sync`, `learn` (path/complete/reviews/reviews-result/placement),
      `progress` (summary/sessions/session-detail), plus the already-spiked
      `audio-analyze`/`speech-grade` promoted out of spike status with CORS added
      for Flutter web dev. New RPCs: `review_record_result`, `record_placement`,
      `progress_summary` (backend/sql/0003, 0004). Deployed + smoke-tested
      (public routes 200, protected routes 401 without JWT, CORS preflight OK).
- [ ] Real-audio parity for `/audio/analyze` (spike used lesson clips; verify with
      a full-ayah recitation)
- [x] End-to-end test of all 13 routes with real signed JWTs (throwaway test
      users via real signup, cleaned up after) — `supabase/tests/edge_functions_test.sh`,
      31 assertions, all green. Found and fixed a real bug: `record_placement`
      returned `void` → PostgREST sends an empty 204 body → the Edge Function's
      `pgRpc()` helper calls `r.json()` unconditionally → threw on the empty body →
      every `/learn/placement` call 500'd. Fixed by returning `boolean` instead
      (backend/sql/0003, applied). Also hand-verified `progress_summary`'s
      group-by-count math against seeded sessions/mistakes/sifat_mistakes (3
      sessions, 2 perfect, mixed rule breakdown) — correct via both direct SQL
      and the `/progress` HTTP endpoint.
- [ ] Rebuild the rest of the test suite (Ktor's 9 test files have no full Deno
      equivalent yet; the new integration script covers HTTP contracts but not
      unit-level edge cases like the SRS ladder's boundary intervals)
- [ ] Flip `BuildConfig.BACKEND_URL` to `https://djcuxaziipgjlmdfkeqz.supabase.co/functions/v1`
      once the above is verified; keep Render alive as rollback until then
- [ ] Cleanup: remove `spike-*` functions after the real ones are verified in the app
