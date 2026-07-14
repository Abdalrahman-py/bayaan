# Bayaan — Full Product Vision (Arabic + Tajweed tutoring platform)

> **Framing:** This is the *complete product spec* — the long-term vision, not a build task. The near-term execution plan lives in [`PRODUCTION_PLAN.md`](./PRODUCTION_PLAN.md); the team split is in [`TEAM_PLAN.md`](./TEAM_PLAN.md) (Abdalrahman + Ramzi, with Gemini building Android screens/wiring). This doc is organized into **parallelizable feature workstreams** so the team can pick and sequence from it.

---

## 1. Context & vision

Bayaan is an AI Quran-recitation **tutoring/mentor** product with two tracks that form one funnel:

- **Arabic track (front of funnel):** a recognition-based Arabic **placement test** assigns a proficiency level; graded Arabic lessons (letters → harakat → reading) build that level up.
- **Tajweed/Quran track (gated behind Arabic):** guided daily lessons that **teach one tajweed rule then test it** on a real ayah, with adaptive ayah selection driven by the learner's tracked weak rules; plus a free **Explore** sandbox (browse the whole Quran like quran.com, self-test on tajweed or memorization).

Built state today: the prototype slice is done — auth (login/signup/session), a 3-tab shell (Home/Qur'an/Profile), a full page-faithful QCF mushaf browser (all 114 surahs, 604 pages), and the record→analyze→highlight recitation loop, all wired to the Ktor backend (Supabase JWT verification, Muaalem engine proxy, Postgres persistence) and `/progress*` endpoints. See `docs/CODEBASE_MAP.md` for the as-built detail. Nothing below this (Arabic track, tajweed lessons, gating, roadmap UI) is built yet.

---

## 2. Product structure

**Gating model:** *Hard gate in production* — Arabic proficiency level unlocks Quran/tajweed content; roadmap nodes are locked until the learner reaches the required Arabic level. *Soft gate in the demo* — a `DEMO_MODE` feature flag unlocks everything so the supervisor can see all features. Build the gating logic once; the flag only bypasses the lock check.

**Top-level navigation (proposed):** bottom nav with four tabs:
- **Learn** — the guided roadmap (Arabic nodes → tajweed nodes), daily lesson CTA, level/streak.
- **Explore** — full-Quran browser (all 114 surahs), pick any ayah → choose *Tajweed test* or *Memorization test*.
- **Progress** — stats, weak-rule/weak-attribute breakdown, mistake history, streak calendar.
- **Profile** — account, logout, settings, (later) goals.

---

## 3. Architecture direction

**Backend migrates from the thin Ktor proxy toward Supabase Edge Functions**, for seamless DB↔app integration and so the frontend team can own DB-adjacent logic in TypeScript:
- **Migrate to Edge Functions + RLS:** auth (native Supabase JWT/RLS — deletes the hand-rolled `JwtPlugin`), `/progress`, adaptive lesson selection, and all new learning/gamification/Arabic CRUD.
- **Keep on Ktor/Modal (the exception):** `/audio/analyze`. It buffers a multipart WAV and holds the connection up to ~60s for the Muaalem GPU cold-start — a poor fit for Edge Functions' wall-clock/binary limits. Either leave this one endpoint on Ktor, or have the client call Modal directly and use an Edge Function only to persist the result. **Validate Edge Function timeout/binary limits on a spike before porting this piece.**
- Sequence the migration so each step buys something concrete (team ownership, killing the Render host, unified auth) — not migration for its own sake.

**New Supabase tables (RLS-scoped to `auth.uid()`):** `profiles` (level, streak, placement result), `placement_results`, `lesson_progress`, `arabic_lessons`/`tajweed_lessons` (curriculum content — or bundle as app assets and store only completion), and `sifat_mistakes` (see §5F). Existing `users`/`sessions`/`mistakes` stay.

---

## 4. Auth (foundation)

- **SDK:** official Supabase Kotlin SDK (`io.github.jan-tennert.supabase`, `Auth` module) on the existing Ktor CIO client — automatic session persistence + token refresh.
- **Email confirmation ON** (realistic): signup shows a "check your inbox" pending state; login errors clearly if unconfirmed. Keep a pre-confirmed demo account for live login.
- **Session holder:** single `AuthViewModel` (`AndroidViewModel`, manual `ViewModelProvider`, no Hilt) owns the `SupabaseClient`, exposes `AuthUiState` as plain Compose state. `RecitationViewModel` (and other authed callers) get a `tokenProvider: () -> String?` constructor param, factory-injected in `MainActivity`. Never log the token.
- **`/auth/sync`** called after successful `signInWith(Email)`, before flipping to `LoggedIn`.
- *(Built in detail in the prototype slice — see [`CODEBASE_MAP.md`](./CODEBASE_MAP.md).)*

---

## 5. Feature workstreams (parallelizable)

### Workstream A — Arabic track (placement + lessons) — *headline*
- **Placement test:** recognition-based multiple-choice only (the Muaalem engine can't grade isolated spoken letters). Items: recognize letter forms, match harakat to sounds, read short words. Scores → an Arabic proficiency **level**, persisted to `profiles`/`placement_results`.
- **Arabic lessons (roadmap opening nodes):** 2-3+ real teach-then-practice lessons (alphabet, harakat, basic reading), recognition-based practice. Later nodes visibly **locked/"coming soon."**
- **Roadmap/skill-tree UI:** ordered nodes (Arabic → tajweed), lock state driven by level (bypassed in `DEMO_MODE`).

### Workstream B — Tajweed guided lessons (teach-then-test)
- A lesson = a short **teaching card** for ONE rule (reuse/extend `docs/tajweed-rules.md`: Madd, Ghunnah, Qalqalah, etc.) → then **recite an ayah** that exercises it via the existing record→engine→highlight flow. New `LessonIntroScreen` before the recitation flow; completion returns to the roadmap, not "next ayah in surah."
- **Adaptive selection** (`/learning/next-lesson`, Edge Function or Ktor): score candidate ayat by tag-overlap with the learner's weak rules, gated by level, tie-broken toward least-recently-practiced. New user → default first ayah.
- **Teachable-rule set** = the rules that have teaching cards = the tajweed curriculum's universe.

### Workstream C — Content pipeline (Quran text + rule tags)
- **Text (all surahs for Explore):** the engine supports sura/aya 1-114. Prefer highlighting against the **engine-returned `uthmani`** (from the `/audio/analyze` response, currently ignored by `RecitationViewModel.parseResponse`) so char positions align. For display/browsing text, `quranic_phonemizer` (installed in `ml/.venv`) works — note its text differs from the app's current text only by combining-mark order (indices preserved).
- **Rule tags (deterministic, not guessed):** a script calls `Phonemizer().phonemize("s:a").tajweed_mappings()` for each curated ayah and extracts actual `TajweedRule` values (Madd sub-types, Ghunnah-family, `QALQALA_*`, `TAFKHEEM`, etc.). Sifat attributes not modeled as rules (`safeer`, `tikraar`, `tafashie`, `istitala`, `itbaq`) → small static Arabic-letter lookup. Output → `data/AyahRuleTags`.
- **Naming reconciliation (verify with real data):** confirm the engine's persisted `rule_name_en` strings vs `quranic_phonemizer`'s enum names by recording one real session and inspecting the `mistakes` table — don't assume a 1:1 map.

### Workstream D — Explore (mushaf pages, quran.com-style)
Modeled on **[quran_android](https://github.com/quran/quran_android)**:
- **Mushaf page view:** pre-rendered **Madani page images** (604 pages) from the open [quran.com-images](https://github.com/quran/quran.com-images) project, paged. **Download-on-demand** (heavy assets); note **attribution/license**.
- **Ayah selection = coordinate hit-testing:** bundle/download the **`ayahinfo` bounding-box DB** (`(x,y,width,height)` per ayah per page, per image width). Long-press → hit-test → resolve ayah → draw box highlight → action menu. **Compose implementation note:** quran_android is Views-based; Bayaan is Compose, so this is a real build item (`Image` + `Canvas`/`pointerInput` overlay), not a port.
- **Two selection actions:**
  - **Multiple ayat → Memorization test** (Workstream E).
  - **Single ayah → Tajweed analysis:** run the **full engine** (all `errors` + `sifat_errors`); because letter-level highlights can't be drawn on a page image, transition to the existing text-based `VerseText`/`RecitationScreen` result, rendering against engine-returned `uthmani`.
- Explore is **always open** (not gated), even in production.

### Workstream E — Memorization mode (Tarteel-style)
- **Mimics Tarteel's Hidden Verses loop:** conceal the ayah text → tap mic → recite from memory → surface **missed / incorrect / extra word** errors → log them for weak-spot review. Add a **Peek** affordance.
- **Primary path — batch, reuses existing pipeline (build first):** the Muaalem engine's diff already returns insertions/deletions/replacements = word-recall errors; surface those as "memorization mistakes." No new model/infra.
- **Optional upgrade — streaming ASR with Tarteel's open Whisper (not urgent; more work):** near-real-time "words light up as you recite" is achievable via a **second model** — Tarteel's Quran-fine-tuned Whisper transcribers ([`tarteel-ai/whisper-base-ar-quran`](https://huggingface.co/tarteel-ai/whisper-base-ar-quran), `whisper-tiny-ar-quran`; larger v3 fine-tunes exist). Deploy on Modal with [`faster-whisper`](https://github.com/SYSTRAN/faster-whisper)/[`whisper_streaming`](https://github.com/ufal/whisper_streaming) behind a WebSocket, stream mic → incremental transcript + word timestamps → diff vs known ayah text → highlight live-ish. **Realistic latency ~0.5–3s, NOT Tarteel's proprietary <200ms.** Cost: a second Modal deployment + streaming client. Model-size tradeoff (small=smoother/less accurate vs large=accurate/heavier) picked if/when taken on.

### Workstream F — Progress / mentor surface
- **Level & streak:** level = fixed tiers by cumulative `perfect_sessions`; streak = consecutive calendar days with ≥1 session (from `sessions.created_at`).
- **Weak-area tracking:** `mistake_breakdown` (named rules, exists) + new **`sifat_breakdown`** (needs persistence, below).
- **Sifat persistence (new work):** the engine returns `sifat_errors` but `EngineResponseParser.parse` currently **drops them entirely**. Add: `sifat_mistakes` table (mirrors `mistakes`), a `SifatMistakeRepository` (`insertBatch` + `countByAttributeForUser`), extend `EngineResponseParser` to parse `sifat_errors`, persist them in `RecitationAnalysis.analyze` (same try/catch as `MistakeRepository.insertBatch` — not `AnalyzeRoute`, which only does HTTP), and add `sifat_breakdown` to `/progress` (mirror `ProgressRoutes.kt:71`). (In the Edge Functions target, the equivalent TS handler.)
- **History:** paginated session list (`/progress/sessions*` already exist, unused by the app) + a mistake log for weak-spot review.

### Workstream G — Polish & branding
- Extract `VersePickerScreen`'s header → reusable `ui/components/BayaanHeader.kt`.
- Loading/error states everywhere (auth, lesson fetch, engine cold-start).
- **Custom app icon** (vector adaptive, green/sand) + **branded splash**.
- Consistency pass: reuse the existing 16/20/24dp padding scale + 2dp card elevation on all new screens.

---

## 6. Verification (end-to-end)

1. `android/ ./gradlew build` and `backend/ ./gradlew build && ./gradlew test` pass.
2. **Auth:** signup → confirmation-pending → confirm → login → lands in Learn; `/auth/sync` row in `users`; session persists across restart; logout clears it.
3. **Arabic:** placement test assigns a persisted level; first lessons mark progress; roadmap nodes lock/unlock by level (unlock fully under `DEMO_MODE`).
4. **Tajweed lesson:** teaching card → recite selected ayah → `Result` (no 401) → back to roadmap → level/streak update.
5. **Highlight alignment:** record a new surah with a deliberate mistake → highlight lands on intended letters (switch to engine-returned `uthmani` if misaligned).
6. **Explore:** all 114 surahs browsable; Tajweed and Memorization tests reachable from any ayah.
7. **Memorization:** text hidden → recite → missed/incorrect/extra words surfaced and logged; Peek reveals briefly.
8. **Progress/sifat:** after a Sifat mismatch, `sifat_mistakes` has a row and `/progress` `sifat_breakdown` reflects it; weak areas drive the next adaptive lesson.
9. **Secrets:** `git diff --cached | grep -iE "key|secret|password|token"` empty; `local.properties` never staged.

---

## 7. Open decisions to confirm

- Bottom-nav structure; the team-workstream ownership split; Arabic curriculum depth/level count; how many tajweed rules get teaching cards for v1; bundle-vs-download strategy for mushaf page images + `ayahinfo`; asset licensing for reused Quran images.
