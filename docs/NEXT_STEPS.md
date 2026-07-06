# Bayaan — Handoff & Execution Plan

> Written 2026-07-03. Snapshot of what's built, what's left, and the order to do it in.
> Source of truth for scope: [`PROTOTYPE_BUILD_GUIDE.md`](./PROTOTYPE_BUILD_GUIDE.md) (showcase slice) and [`PRODUCT_VISION.md`](./PRODUCT_VISION.md) (full product). This file is the "what's next" layer on top of them.

---

## 1. Where we actually are (verified against the code, not the docs)

### Done and working
- **Auth (full):** `AuthViewModel` (Supabase Kotlin SDK 3.1.4), Splash auth-gate, Onboarding (once via `first_launch` pref), Login, Signup (email-confirmation-pending state), Profile logout. Token is wired into the recitation pipeline — `MainActivity.kt:40` passes `authViewModel.currentAccessToken()` into `RecitationViewModel.Factory`, so `/audio/analyze` is authenticated (no more 401).
- **Backend:** Ktor proxy verifies Supabase JWTs via **JWKS/ES256** (note: `backend/AGENTS.md` still says HS256 — stale, the last 3 commits fixed this), proxies Muaalem on Modal, persists `sessions` + `mistakes`, serves `/progress*`. Deployed on Render free tier (~30–60s cold start).
- **App shell/nav:** single `NavHost`, 3-tab bottom bar (Home · Qur'an · Profile), Settings under Profile, drill-in routes hide the bar. [`NavGraph.kt`](../android/app/src/main/java/com/bayaan/ui/navigation/NavGraph.kt).
- **Tajweed flow:** record → engine → **letter-level highlights** works. `RecitationViewModel.parseResponse` already (a) parses `sifat_errors` for **client display** and (b) falls back to the **engine-returned `uthmani`** for highlight alignment post-record. This is better than the docs imply.
- **Mushaf renderer (QCF v4 text mushaf):** `MushafPagerScreen` + `SurahIndexScreen` + `QcfRepository` are built — glyph-code→PUA rendering, per-word tap → whole-ayah highlight → action sheet {Analyze Tajweed, Memorize (disabled)} → handoff to `recitation/{sura}/{aya}`. RTL pager, surah index with Arabic/English names + verse counts.

### Uncommitted right now (working tree)
Small polish, not yet committed — **commit this first** (see step 0):
- `verticalScroll` added to Home/Login/Signup/Profile/Settings (avoids clipping on short screens).
- `friendlyAuthError()` in `AuthViewModel` — maps Supabase's wall-of-text exceptions to short messages.
- `Locale.US` fix on the page-filename `String.format` in `QcfRepository`.

### The one big hole
**Only page 1 of the mushaf exists.** `assets/qcf4/` has `index.json` (all 114 chapters), `pages/001.json`, and **2 of 47 fonts**. Every page ≠ 1 renders the placeholder *"Page N JSON or fonts not loaded"* ([`MushafPagerScreen.kt:126`](../android/app/src/main/java/com/bayaan/ui/screens/MushafPagerScreen.kt#L126)). This is the "add the rest of the surahs" you flagged — but it has an APK-size catch (below).

---

## 2. Execution plan (ordered by what unblocks the showcase)

### Step 0 — Commit the pending polish (5 min)
It's done, tested-by-eye work sitting uncommitted. Land it so it's not lost.
```
feat(android): scrollable auth/home screens + friendly auth errors
```

---

### Step 1 — Ship all 604 pages 🚧 **(the main task — has a decision in it)**

The renderer already works; this is a **data + size** problem, not a code problem.

**The catch:** each `QCF4_Hafs_NN_W.ttf` is ~2 MB. 47 of them ≈ **~90–100 MB of fonts**, plus 604 small JSONs. Bundling all of them = a ~100 MB APK. The QCF guide explicitly warns: *"do not silently ship a 100 MB APK."* **This is a real decision, make it before copying files:**

| Option | APK size | Effort | When |
|---|---|---|---|
| **A. Bundle everything** | ~100 MB | trivial (copy files) | Fine for a sideloaded **showcase build**. Recommended for the supervisor demo. |
| **B. Download-on-demand** | small base APK | real work (downloader, cache, progress UI, offline handling) | Only if this goes to Play Store. Post-showcase. |
| **C. Bundle a subset** | medium | low | Ship the ~10 fonts covering a demo path (Fatihah, Baqarah start, a few short surahs); rest show placeholder. Ugly but small. |

**Recommendation: Option A for the showcase.** It's a sideloaded APK to a supervisor, size doesn't matter, and it's the honest "browse the whole Quran" story. Revisit B only if it ships publicly.

**To execute A:**
1. Clone the source: `github.com/MohamadHajjRabee/quran-qcf4` (MIT data + fonts).
2. Copy `pages/002.json … 604.json` → `android/app/src/main/assets/qcf4/pages/`.
3. Copy all `QCF4_Hafs_NN_W.ttf` → `assets/qcf4/fonts/`. **Watch the filename convention:** the loader ([`MushafPagerScreen.kt:57`](../android/app/src/main/java/com/bayaan/ui/screens/MushafPagerScreen.kt#L57)) expects `${fontName}_W.ttf` for Hafs fonts and `QCF4_QBSML.ttf` for the header/basmala font. Verify the repo's actual filenames match, or fix the mapping.
4. `du -sh assets/qcf4` and check the release APK size is what you expect.
5. **Verify a dense page** (e.g. a mid-Baqarah page, 15 full lines) fits without vertical scroll and stays readable — the renderer sizes text at a fixed 28sp and relies on `SpaceEvenly`/`SpaceBetween`. Page 1 (Fatihah, sparse) is not a real test of the justification. **If a dense page overflows, this is where you'd find out** — fix by auto-fitting font size per page, not after.
6. Delete the placeholder branch's stale copy once real pages load (optional).

---

### Step 2 — Fix the pre-record verse text gotcha ✅ DONE (2026-07-03)

`verseFor` now resolves **any** ayah. All 6236 Uthmani ayat are bundled at `assets/quran/uthmani.json`, dumped from the `quranic_phonemizer` DB (the same source the engine derives its uthmani from) — so the bundled text matches the app's original hardcoded Fatihah/Bayyinah glyphs (differences are combining-mark *order* only, NFC-equal, renders identically). Loaded once via `QuranText.ensureLoaded()` in `RecitationViewModel.init`; surah names reused from the QCF index. Post-record highlight alignment is unchanged (still swaps in the engine-returned uthmani). Hardcoded Fatihah/Bayyinah kept as a fallback for Compose previews.

---

### Step 3 — Gate 2 full-build verification on a real device (30 min)

From the QCF guide, non-negotiable before calling it done:
```
cd android && ./gradlew build
```
Then run the **cold** end-to-end path on a device/emulator:
splash → onboarding → signup → confirm → login → Home → Qur'an (surah index) → tap surah → mushaf opens **at that surah's page, RTL** → tap ayah → Analyze Tajweed → record → highlights (not a 401) → try again.
**"Compiles" ≠ "works" — actually run it,** and warm the Render + Modal endpoints before demoing (both free-tier, both cold-start).

---

### Step 4 — Backend sifat persistence (Workstream F, ~2–3 hrs) — *optional for showcase*

The engine returns `sifat_errors`; the **client already displays them**, but the **backend drops them** — `EngineResponseParser.parse` only reads `errors` (confirmed: no `sifat` anywhere in `backend/src`). So Progress/weak-area tracking can never see sifat mistakes.

Only needed once you build the **Progress surface**. To close it:
1. `sifat_mistakes` table (mirror `mistakes`), `SifatMistakeRepository` (`insertBatch` + `countByAttributeForUser`).
2. Extend `EngineResponseParser` to parse `sifat_errors`.
3. Persist in `RecitationAnalysis.analyze` (same try/catch spot as `MistakeRepository.insertBatch`).
4. Add `sifat_breakdown` to `/progress` (mirror the existing `mistake_breakdown`).

Skip for the showcase unless the Progress tab is in scope.

---

## 3. Beyond the showcase (full product — from PRODUCT_VISION, not yet started)

None of these are built. Sequence them after the showcase lands. Roughly in dependency order:

1. **Progress/mentor surface** (Workstream F) — level, streak, weak-rule + sifat breakdown, history. `/progress*` endpoints exist and are unused by the app; wire them up. Needs Step 4 for sifat.
2. **Explore actions completion** — the mushaf's single-ayah → tajweed is done; **multi-ayah select → Memorization test** is not.
3. **Memorization mode** (Workstream E) — Tarteel-style hidden-verses. *Build the batch version first* (the engine's diff already returns missed/extra/replaced words — no new model). Streaming ASR is a later, optional upgrade.
4. **Tajweed guided lessons** (Workstream B) — teach-one-rule card → recite an ayah exercising it → adaptive next-lesson selection by weak rules. Needs the content pipeline below.
5. **Content pipeline** (Workstream C) — deterministic rule tags per ayah via `quranic_phonemizer` (`Phonemizer().phonemize(...).tajweed_mappings()`), not guessed. Reconcile engine `rule_name_en` vs phonemizer enums against a real recorded session.
6. **Arabic track** (Workstream A, the headline) — recognition-based placement test → level → graded Arabic lessons → **hard gate** unlocking the Quran/tajweed track (soft-gated via `DEMO_MODE`).
7. **Backend → Supabase Edge Functions migration** — move auth/RLS, `/progress`, lesson logic to TS/Edge Functions; **keep `/audio/analyze` on Ktor/Modal** (the 60s cold-start hold is a bad fit for Edge limits). Migrate only when each step buys something (team ownership, killing Render, unified auth) — **spike Edge timeout/binary limits before porting audio.**

---

## 4. Known risks / gotchas to carry forward

- **APK size** (Step 1) — the fonts are the whole problem; decide bundle-vs-download deliberately.
- **Dense-page justification** — the renderer is only proven on sparse Fatihah. Verify on a full Baqarah page.
- **Font filename convention** — loader hardcodes `_W.ttf` suffix; a mismatch = silent placeholder, not a crash.
- **Free-tier cold starts** — Render (~30–60s) + Modal both sleep. Keep-warm before any live demo; make spinners honest.
- **QCF font license** — MIT covers the *data*, **not the fonts**. Fine for a non-commercial showcase; a **production blocker** until KFGQPC permission. Don't remove `assets/qcf4/ATTRIBUTION.md`.
- **Stale `backend/AGENTS.md`** — says HS256; the code now does JWKS/ES256. Fix the doc when you next touch the backend.

---

## TL;DR
1. Commit the pending polish. 2. Decide APK strategy, then bundle all 604 pages + 47 fonts (this is "the rest of the surahs"). 3. Generalize `verseFor` so pre-record text is correct. 4. Build + run cold on a device (Gate 2). — That's the showcase. Everything in §3 is the real product and comes after.
