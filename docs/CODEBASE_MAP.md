# Bayaan — Codebase Map (the "why" file)

> Written 2026-07-03. Read this when you feel lost. Explains every moving part and
> the decision behind it, so you drive the code instead of the AI driving you.
> Style: terse. Caveman words, senior-dev substance.
>
> Companion files: [`PRODUCTION_PLAN.md`](./PRODUCTION_PLAN.md) (current execution plan),
> [`PRODUCT_VISION.md`](./PRODUCT_VISION.md) (full dream).
> **Where they disagree with each other, THIS file matches the code as of today.**

---

## 1. What Bayaan is (one breath)

App listen to you recite Quran ayah. App tell you where tajweed wrong, mark it on the
Arabic script. You try again. That is the whole loop.

We do **not** build the AI that grades recitation. We rent one (off-the-shelf, MIT).
We build: the phone app, a thin backend around the model, the login, the storage.

---

## 2. Three boxes. Know these and you know the system.

```
[ Android app ]  --Bearer JWT + audio+sura+aya-->  [ Ktor backend (Render) ]
      ^                                                   |
      |                                        forward audio | verify JWT
      | JSON: errors + sifat_errors                          v
      |                                             [ Muaalem engine (Modal GPU) ]
      |                                                   |
      +------------------- JSON --------------------------+
                                                          |
                                          persist session+mistakes
                                                          v
                                              [ Supabase Postgres ]
```

Box 1 — **Android** (`/android`). Kotlin + Jetpack Compose. Records mic, shows script, draws highlights.
Box 2 — **Backend** (`/backend`). Ktor (Kotlin). Thin. Checks token, forwards audio, saves result. Does NOT run any AI.
Box 3 — **Engine** (`/ml`). Python on Modal serverless GPU. The actual recitation grader. One file: [`ml/muaalem_modal.py`](../ml/muaalem_modal.py).

Plus two rented services: **Supabase** (login + Postgres DB) and **Render** (hosts box 2), **Modal** (hosts box 3).

---

## 3. One recitation, start to finish

1. User picks ayah (mushaf screen, or old verse-picker).
2. Phone records mic → 16kHz mono PCM → wraps as WAV **in memory** (no file, no server conversion). See `RecitationViewModel.buildWav`.
3. Phone POST `multipart/form-data` to backend `/audio/analyze` with header `Authorization: Bearer <supabase-jwt>` + fields `audio`, `sura`, `aya`.
4. Backend verify token (see §4). Reject if bad → 401.
5. Backend forward WAV to Muaalem on Modal. Waits up to **60s** (engine can cold-start).
6. Engine run model, diff your phonemes vs the reference ayah, return JSON: `errors` (phoneme/tajweed mistakes with char positions) + `sifat_errors` (letter-characteristic mistakes) + `uthmani` (the reference text) + `all_correct`.
7. Backend save one `sessions` row + one `mistakes` row per error into Postgres.
8. Backend return engine JSON **unchanged** to phone.
9. Phone parse it (`RecitationViewModel.parseResponse`): `errors` → char-range highlights on the Arabic; `sifat_errors` → "Letter Characteristics" card. `all_correct` → green.

Key trick step 9: phone swaps its own verse text for the engine-returned `uthmani` before highlighting, so char positions line up exactly (same string the engine measured against).

---

## 4. Auth — how it works, why every route is fenced

**Who issues tokens:** Supabase Auth. Phone logs in with email+password using the Supabase
Kotlin SDK (`AuthViewModel`). Supabase hands back a **JWT** (a signed token proving "this is user X").

**What phone does with it:** every backend call attaches `Authorization: Bearer <jwt>`.

**How backend checks it** — [`plugins/JwtPlugin.kt`](../backend/src/main/kotlin/com/bayaan/plugins/JwtPlugin.kt):
- Backend does NOT ask Supabase "is this token good?" on every request (too slow, one round-trip per call).
- Instead it verifies the **signature locally**. Supabase signs with an asymmetric key (**ES256**). Backend fetches Supabase's **public keys** from the JWKS URL (`https://<ref>.supabase.co/auth/v1/.well-known/jwks.json`), caches them 24h, and checks the signature + issuer + audience (`authenticated`) itself.
- Valid token → Ktor builds a `JWTPrincipal`. The user's UUID is the token's `sub` field.
- Bad/expired → `challenge{}` returns `401 {"error":"unauthorized"}`.

The code moved from HS256/`SUPABASE_JWT_SECRET` to **JWKS/ES256** (commits db8ff83, 706df94).
`SUPABASE_JWT_SECRET` is dead; the real env vars are `SUPABASE_PROJECT_REF` (builds the
issuer URL) and `SUPABASE_DB_URL`.

**Where the fence is** — [`Application.kt`](../backend/src/main/kotlin/com/bayaan/Application.kt):
```kotlin
routing {
    healthRoute()          // open
    surahRoutes()          // open
    authenticate("auth-jwt") {   // <-- fence. everything inside needs a valid token
        authRoutes()       // /auth/sync
        analyzeRoute()     // /audio/analyze
        progressRoutes()   // /progress*
    }
}
```
Inside the fence, `call.userId()` ([`AuthExtensions.kt`](../backend/src/main/kotlin/com/bayaan/plugins/AuthExtensions.kt)) pulls the UUID from the verified token. **Safe** because Ktor already guaranteed the principal exists before the route body runs.

**Why fence these routes:** they touch or reveal a user's private data. `/audio/analyze`
saves rows tagged to *you*. `/progress` reveals *your* history. If unfenced, anyone could
read/write anyone's data — the token is the only thing tying a request to a person.
`/health` and `/surahs` reveal nothing private → left open.

**`/auth/sync` — why it exists:** Supabase owns the login table, but our Postgres has its own
`users` table (so `sessions.user_id` has something to point at). On first login the phone calls
`/auth/sync`; backend upserts a `users` row with the token's UUID. Idempotent — safe to call every launch.

---

## 5. Backend endpoints — the whole surface

Six routes. Files in [`backend/src/main/kotlin/com/bayaan/routes/`](../backend/src/main/kotlin/com/bayaan/routes/).

| Route | Auth? | What | Why |
|---|---|---|---|
| `GET /health` | no | returns `{"status":"ok"}` | Render liveness ping; reveals nothing |
| `GET /surahs` | no | **hardcoded** list (Fatihah + Bayyinah) | old verse-picker fed off this; mushaf screen doesn't use it. Stale-ish. |
| `POST /auth/sync` | yes | upsert `users` row | give Postgres a user to hang sessions on |
| `POST /audio/analyze` | yes | engine call + persist | the core loop (§3) |
| `GET /progress` | yes | aggregate stats for you | Progress tab (not built in app yet) |
| `GET /progress/sessions` | yes | your session history, paginated | history list (not wired in app) |
| `GET /progress/sessions/{id}` | yes | one session + all its mistakes | drill-in (not wired in app) |

Note: `/progress*` endpoints **work but the app never calls them yet**. Backend is ahead of the UI here.

**`/audio/analyze` guts** — [`AnalyzeRoute.kt`](../backend/src/main/kotlin/com/bayaan/routes/AnalyzeRoute.kt) + [`RecitationAnalysis.kt`](../backend/src/main/kotlin/com/bayaan/RecitationAnalysis.kt):
- Validate at boundary: audio present, ≤10MB (post-buffer check — marked `ponytail:` as a known ceiling; fine while the app is the only caller).
- `RecitationAnalysis.analyze` is a clean state machine returning `Success` / `EngineError` / `EngineFailed` / `PersistenceFailed`, each mapping to a distinct HTTP status. Engine's own error body passes through unchanged.
- `EngineResponseParser` reads `all_correct` + `errors[]`. **Note:** it does NOT parse `sifat_errors` — backend drops those, so DB has no sifat data yet (see NEXT_STEPS step 4). The *phone* does show sifat live; only *storage* skips it.

---

## 6. Database — three tables, that's it

Supabase Postgres. Schema defined as Exposed table objects in [`data/tables/`](../backend/src/main/kotlin/com/bayaan/data/tables/). Live DDL lives in Supabase itself.

```
users
  id          uuid  PK        <- same UUID as Supabase auth user (the JWT 'sub')
  email       text  null
  created_at  timestamp

sessions
  id          uuid  PK
  user_id     uuid  -> users.id   (CASCADE delete)
  sura        int
  aya         int
  all_correct bool
  created_at  timestamp

mistakes
  id                uuid  PK
  session_id        uuid  -> sessions.id  (CASCADE delete)
  char_start        int         <- highlight range start in the uthmani text
  char_end          int
  error_type        text        <- e.g. "tajweed"
  speech_error_type text  null
  rule_name_en      text  null  <- tajweed rule name, English
  rule_name_ar      text  null  <- ...Arabic
  expected_len      int   null  <- e.g. madd should be 4 counts
  predicted_len     int   null  <- ...you did 2
  created_at        timestamp
```

Why this shape: one session = one recitation attempt. Mistakes hang off the session. CASCADE
means delete a user → their sessions and mistakes vanish too. Enough to compute progress
(`count sessions`, `count perfect`, `group mistakes by rule`) — see `ProgressRoutes.kt`.

**Connection:** HikariCP pool (10 conns) → JDBC → Supabase Postgres, via Exposed ORM.
[`DatabaseFactory.kt`](../backend/src/main/kotlin/com/bayaan/data/DatabaseFactory.kt). Pool is **lazy** — first DB-touching request builds it. That's why `/health` and `/surahs` boot even without `SUPABASE_DB_URL` set.

---

## 7. The engine (Muaalem) — the AI we rent, not build

File: [`ml/muaalem_modal.py`](../ml/muaalem_modal.py). It is the ONLY thing in `/ml`. No training code. The original plan (collect data, fine-tune wav2vec2, export ONNX) **never happened and is dropped**.

**What model:** `quran-muaalem` (with `quran-transcript`) — pretrained, MIT-licensed, off HuggingFace. We chose "rent a working model" over "train our own" to avoid months of ML work for an app project.

**What it does per request** (`_correct`):
1. Decode uploaded WAV → 16kHz mono float32.
2. Look up the reference ayah text (Hafs) via `quran_transcript.Aya(sura,aya)`. Bismillah counts as aya 1.
3. Phonetize the reference (with madd/tajweed timing rules → `MoshafAttributes`, rewaya=hafs).
4. Run the model on your audio → your predicted phonemes.
5. `explain_error(...)` diffs reference vs predicted → `errors[]` (each with char positions + tajweed rule).
6. `expalin_sifat(...)` diffs letter *characteristics* (hams/jahr, shidda, tafkheem, qalqala, ghonna...) → `sifat_errors[]` with confidence scores.
7. Return JSON.

Why call the two diff functions directly instead of importing the upstream FastAPI app: the
upstream ships a two-server stack (engine :8000 + app :8001 talking over http). We run the model
in-process and only borrow its two pure functions — one container, no internal HTTP.

**Hosting = Modal serverless GPU (L4):**
- **Scale-to-zero.** $0 when idle. But first call after idle = **cold start ~24s** (load model into GPU).
- `scaledown_window=300` → container stays warm 5 min after last call. Back-to-back demo runs hit the **~1.7s warm path**.
- **Deploy gotcha:** `modal deploy` does NOT replace an already-warm container. To verify a code
  change you must `modal app stop bayaan-muaalem && modal deploy` first, else you test old code.
- For a live demo: uncomment `min_containers=1` to pin one warm (costs money continuously — recomment after).
- URL baked as default in `RecitationAnalysis.kt`; override with `MUAALEM_URL` env.

The 60s HTTP timeout in both backend and phone exists **specifically to survive this cold start.** Don't shorten it.

---

## 8. Hosting & rented services — who runs what, why

| Thing | Rented from | Why that one | Cost/gotcha |
|---|---|---|---|
| Backend (box 2) | **Render**, Docker, free tier | one Dockerfile deploy, no config fuss | free tier **sleeps** → ~30–60s cold start |
| Auth + DB | **Supabase** | managed Postgres + drop-in email auth + JWKS | anon key + URL baked into app `BuildConfig` |
| Engine (box 3) | **Modal** | serverless GPU, scale-to-zero, cheap idle | ~24s cold start (§7) |

**Two cold starts stack** (Render + Modal). Before any live demo: warm both first (hit `/health`,
then one throwaway analyze). Make spinners honest about the wait.

**Why not one platform?** Render has no cheap GPU; Modal is great for burst GPU but a bad fit for a
always-on REST API. Supabase gives auth+DB for free. Each box sits where it's cheapest/easiest.
Future idea (PRODUCT_VISION): move auth/progress to Supabase Edge Functions, but **keep
`/audio/analyze` on Ktor/Modal** — its 60s cold-start doesn't fit Edge time limits.

---

## 9. Android app — screens, brains, gate

Single Gradle module `app/`, all Compose. Files under [`android/app/src/main/java/com/bayaan/`](../android/app/src/main/java/com/bayaan/).

**Two brains (ViewModels):**
- `AuthViewModel` — owns Supabase client. `checkSession / login / signup / signOut`. State machine `Checking → LoggedOut / LoggedIn`. `friendlyAuthError()` turns Supabase's wall-of-text exceptions into short human messages. Also handles email-confirmation-pending state.
- `RecitationViewModel` — the record loop. Mic → PCM → WAV → upload → parse. Holds one UI state **per (sura,aya)** so revisiting an ayah keeps its result. Built with a `Factory` that injects the auth token provider — that's how `/audio/analyze` gets its Bearer token (fixed the old 401).

**Navigation** — `NavGraph.kt`. Single `NavHost`. The **auth gate** is here: `authState` drives
whether you see Splash/Onboarding/Login/Signup or the real app. 3-tab bottom bar (Home · Qur'an ·
Profile); drill-in routes (mushaf, recitation) hide the bar. Onboarding shows once via a
`first_launch` SharedPreference.

**Screens of note:** `SplashScreen` (auth check), `OnboardingScreen` (once), `Login/Signup`,
`SurahIndexScreen` (list surahs) → `MushafPagerScreen` (the script) → tap ayah → `RecitationScreen` (record + highlights). `VersePickerScreen` is the OLD path (feeds off `/surahs`), superseded by the mushaf.

**Full-Quran text:** [`QuranText.kt`](../android/app/src/main/java/com/bayaan/ui/model/QuranText.kt) loads all 6236 Uthmani ayat from `assets/quran/uthmani.json` (1.4MB, dumped from the same DB the engine uses) once at VM init, so pre-record verse text is correct for *any* ayah. Hardcoded Fatihah/Bayyinah kept only as a Compose-preview fallback.

---

## 10. Mushaf & fonts — the trickiest visual piece

We render the Quran as a **real page-faithful mushaf**, not plain Arabic text. Source data: QCF v4
(`quran-qcf4`, MIT). Files in `android/app/src/main/assets/qcf4/`.

**How it renders** ([`MushafPagerScreen.kt`](../android/app/src/main/java/com/bayaan/ui/screens/MushafPagerScreen.kt) + [`QcfRepository.kt`](../android/app/src/main/java/com/bayaan/ui/mushaf/QcfRepository.kt)):
- Each **page** has its **own font file** (`QCF4_Hafs_NN_W.ttf`). Page N's words carry glyph **codes** (integers), not letters. The page's font maps those codes (in the Unicode Private Use Area) to the exact ligatures printed on that physical page → pixel-faithful to the printed Madani mushaf. Header/basmala uses `QCF4_QBSML.ttf`.
- Loader convention: `getFontFamily` expects `${fontName}_W.ttf` for Hafs pages, `QCF4_QBSML.ttf` for the header. A wrong filename = silent placeholder, not a crash.
- `index.json` = all 114 chapters (name ar/en, verse count, start/end page). `pages/NNN.json` = per-page lines→words→{code,font,verse_key}.
- RTL pager (`reverseLayout=true`) — swipe right = next page, like a real mushaf.
- Tap a word → whole ayah highlights → action sheet {Analyze Tajweed, Memorize(disabled)} → hands off to the recitation screen for that `sura:aya`.

**Bundle size:** each font ≈ 2MB; all 48 ≈ 113MB total for all 604 pages. Decided to bundle
everything rather than subset or download-on-demand — simplest, fine for a sideloaded showcase.
Revisit before a Play Store release (APK size limits).

> ⚠️ **LICENSE:** MIT covers the QCF *data*, **NOT the fonts** (KFGQPC owns those). Fine for a
> non-commercial supervisor showcase. **Production blocker** until you get KFGQPC permission.
> Do NOT delete `assets/qcf4/ATTRIBUTION.md`.

---

## 11. Decision log — the "why we did it this way" list

- **Rent the recitation model, don't train one.** App project, not an ML thesis. Saved months. (`/ml` has no training code on purpose.)
- **Thin backend, not fat.** Backend = auth + forward + store. All intelligence lives in the rented engine. Keeps Ktor box dumb and cheap.
- **Local JWT verify (JWKS), not call-Supabase-per-request.** No network round-trip on every API call; public keys cached 24h.
- **Own `users` table mirroring Supabase auth.** So `sessions` FK has a real target. `/auth/sync` keeps it filled.
- **WAV built on-device at 16kHz mono.** Model needs 16kHz; doing it on the phone means backend never transcodes audio (stays thin, stores nothing).
- **Store audio? No.** Audio processed in memory, discarded. Only the *mistake data* persists. Privacy + cheap.
- **Modal scale-to-zero.** GPU is expensive; we pay ~$0 idle and eat a cold start. Acceptable for a prototype/demo.
- **Render free tier.** One-Dockerfile deploys; cold start acceptable for now.
- **QCF glyph-font mushaf, fully bundled.** Page-faithful script beats plain text for a recitation coach; all 604 pages ship in the APK for the showcase.
- **Solo repo, one `main` branch.** Team shrank to one; PR ceremony was pure overhead → removed (AGENTS.md).

---

## 12. Sharp edges to remember

- **Two cold starts** (Render + Modal) stack before a demo. Warm both.
- **Modal deploy** won't replace a warm container — `modal app stop` first to test new code.
- **Backend drops `sifat_errors`** (parser ignores them). Phone shows them live; DB never sees them.
- **`/progress*` built but unused** by the app. Backend ahead of UI.
- **`/surahs` is hardcoded** to 2 surahs and mostly superseded by the mushaf screen.
- **Font license** = showcase-only until KFGQPC permission.
- **10MB audio cap is post-buffer** (`ponytail:` note in AnalyzeRoute) — fine while the app is the only client.
</content>
</invoke>
