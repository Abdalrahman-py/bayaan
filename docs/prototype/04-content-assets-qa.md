# Owner D — Content, Assets, Integration & QA

> You make the demo *real* and *correct*: source the mushaf assets, fix the verse-text gotcha so `RecitationScreen` shows the right ayah, produce the app icon + splash art, run the consistency/cold-start polish pass, and own end-to-end integration + QA. You're the glue and the last line of defense before the showcase.
>
> **Read first:** [`android/UI_SPEC.md`](../../android/UI_SPEC.md) and the [overview](../PROTOTYPE_BUILD_GUIDE.md). You touch a bit of everything, so coordinate widely.

---

## 1. Mushaf assets (for Owner C)

Bundle in `app/src/main/assets/`:
- A **small subset** of Madani page images at **ONE width** from [quran.com-images](https://github.com/quran/quran.com-images).
- The matching **`ayahinfo` SQLite DB** for that width (bounding boxes per ayah per page).

**Must do:**
- **Verify attribution/license** for both the images and the DB before bundling; record the source + license in the repo (a short `assets/ATTRIBUTION.md`).
- **Agree the image width with Owner C** — the boxes only align at the width they were generated for.
- **Inspect the DB schema on the actual file** (`sqlite3 ayahinfo.db ".schema"`) and hand C the real table/column names — variants differ (`min_x/max_x` vs `x/width`).
- Keep the subset small (a handful of pages) so the APK stays light for a cold-install demo.

---

## 2. The verse-text gotcha (must resolve or the demo breaks)

[`verseFor()`](../../android/app/src/main/java/com/bayaan/ui/model/Models.kt) only has hardcoded Uthmani text for **Al-Fatihah (1)** and **Al-Bayyinah (98)**:
```kotlin
val (surahNameAr, verses) = if (sura == 98) BAYYINAH else FATIHAH   // everything else silently → Fatihah
```
The mushaf can select **any** ayah, so `RecitationScreen` would show the **wrong text** for anything outside those two surahs — and the highlight char-ranges wouldn't line up. Fix, cheapest first:

- **Cheapest (recommended for the demo):** constrain the demo mushaf to **pages whose surahs already have text** (Fatihah / Bayyinah). Zero code risk; coordinate the bundled pages with C.
- **Better — use the engine's own `uthmani`:** the backend already returns an `uthmani` field, but [`RecitationViewModel.parseResponse`](../../android/app/src/main/java/com/bayaan/ui/viewmodel/RecitationViewModel.kt) currently **ignores it** and keeps the local `verseFor()` text. Switch the `Result` state's verse text to the engine-returned `uthmani` so the highlight char positions always line up with what the engine indexed. (Small change in `parseResponse` — coordinate with Owner A, who's already in that file.)
- **Fuller:** generalize `verseFor()` from its `if (sura == 98)` branch into a small map, populating text via the `quranic_phonemizer` package (installed in `ml/.venv`): `Phonemizer().phonemize("s:a").text()` (strip the trailing ayah-number glyph). Only worth it if the demo needs surahs beyond the two.

**Pick one and confirm with A + C** — this is a cross-owner decision, don't resolve it silently.

---

## 3. App icon & splash art

- Adaptive vector app icon (green/sand per the palette in [`UI_SPEC.md`](../../android/UI_SPEC.md) — `#2C5E43` / `#FCFBF7`). Replace the default launcher icon; keep it simple (a بَيَان mark or a mushaf glyph).
- Branded splash art consistent with `BayaanHeader` (Owner B builds the Splash screen; you supply/approve the art). Don't ship a bare spinner.

---

## 4. Polish pass (consistency + honest states)

- **Consistency:** enforce the `UI_SPEC.md` tokens across all new screens — 16/20/24dp spacing, 2dp card elevation, `primary` for accents (no stray terracotta on non-feedback UI), dark-mode correctness.
- **Cold-start affordances (critical):** Render + Modal free tiers cold-start slowly. The first `/audio/analyze` and the splash session-check can take many seconds — spinners must be visible with honest copy ("Waking the coach…", "Analyzing recitation…"), never a frozen screen. Audit every loading state.
- **Error/empty states:** wrong password, unconfirmed email, no network, engine timeout — each should show a friendly message + retry, not a crash or a dead screen.

---

## 5. Integration & QA (you own the end-to-end)

- Run the full flow on a **real device, cold-installed** (not just the emulator): the acceptance test in the [overview §8](../PROTOTYPE_BUILD_GUIDE.md#8-definition-of-done-acceptance-test--run-on-a-real-device-cold).
- **Keep the backends warm** before the live demo: hit `bayaan-backend.onrender.com` and trigger one analyze so Render + Modal are hot when the supervisor watches.
- Keep a **pre-confirmed demo account** for the live login (email-confirmation is ON); use a throwaway email only to show the pending-confirmation state.
- Lead the **demo rehearsal**; keep the list **fallback** (guide 03) verified as the safety net.
- Before any commit: `./gradlew build && ./gradlew test`, and `git diff --cached | grep -iE "key|secret|password|token"` must be empty (`android/AGENTS.md`).

---

## Expected output / acceptance (Owner D)

- [ ] Page images + `ayahinfo` DB bundled in `assets/`, width agreed with C, **attribution recorded**.
- [ ] Verse-text gotcha resolved (approach chosen with A + C); **`RecitationScreen` shows the correct text for every selectable ayah**, highlights aligned.
- [ ] Adaptive app icon + branded splash art shipped.
- [ ] Every loading/error state audited — no frozen-looking screens; cold starts communicated honestly.
- [ ] Full cold-install flow passes on a real device (overview §8, all 7 checks).
- [ ] Backends warm + demo account ready + fallback verified for the showcase.
