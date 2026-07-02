# Owner E — QCF v4 Text-Mushaf Browse (Gemini/Antigravity build plan)

> **Status:** approved design (see [[project_qcf_v4_mushaf_browse]] in decisions). Replaces the placeholder image-based `MushafScreen` (`demoPages` + `ayahinfo` bbox).
> **What this is:** the Qur'an *browse* surface rendered as a **text mushaf** using KFGQPC **QCF v4** glyph fonts — printed-mushaf fidelity, fully selectable, no page images.
> **Audience:** the agent writing the code (Gemini in Antigravity). This is leave-nothing-to-guess. Two hard gates are marked 🚧 — do not skip them.

---

## 0. Scope & non-goals

**In scope:** surah index → 604-page swipeable text mushaf → tap an ayah → action sheet {Memorize (disabled), Analyze Tajweed} → hand off to the EXISTING tajweed screen.

**Out of scope (reuse as-is, do NOT touch):** `RecitationScreen`, `VerseText` letter highlighting, `RecitationViewModel` + engine pipeline, the `recitation/{sura}/{aya}` route, auth. The tajweed half already works: record → analyze → feedback → try-again.

**License note (prototype only):** QCF v4 **JSON data is MIT** (free). The **font files are NOT** — fine to bundle for this non-commercial showcase, but a production blocker until KFGQPC permission is obtained. Do not remove `assets/qcf4/ATTRIBUTION.md`.

---

## 1. Assets to bundle

Source repo (MIT data + fonts): `https://github.com/MohamadHajjRabee/quran-qcf4`

Stage into `android/app/src/main/assets/qcf4/`:

```
qcf4/
├── index.json            # chapters[] (surah list) + meta
├── pages/001.json … 604.json   # per-page glyph data (zero-padded 3 digits)
├── fonts/                # 47 × QCF4_Hafs_NN.ttf  +  QCF4_QBSML.ttf
└── ATTRIBUTION.md        # copy the repo's LICENSE.md text here
```

- `verses.json` and `font-map.json` are **not required** (page JSON already carries the page `font` and per-word `verse_key`). Skip them to keep the APK lean.
- **Verify APK impact** after adding fonts: `du -sh assets/qcf4` and confirm the release APK size is acceptable. If fonts are large, note it — do not silently ship a 100MB APK.

---

## 2. Data model (parse with `org.json`, already a project dependency — no new libs)

```kotlin
// ui/mushaf/QcfModels.kt
data class QcfChapter(val id: Int, val nameEn: String, val nameAr: String,
                      val versesCount: Int, val startPage: Int, val endPage: Int)

data class QcfWord(
    val code: Int,          // decimal PUA codepoint, e.g. 61696 == U+F100
    val fontName: String,   // "QCF4_Hafs_01" | "QCF4_QBSML"
    val type: String,       // "word" | "end" | "surah_header" | "bismillah"
    val verseKey: String?,  // "1:1"  (null for surah_header)
)
data class QcfLine(val line: Int, val words: List<QcfWord>)
data class QcfPage(val page: Int, val fontName: String, val lines: List<QcfLine>)
```

```kotlin
// ui/mushaf/QcfRepository.kt  — read straight from assets, cache in memory
class QcfRepository(private val ctx: Context) {
    fun chapters(): List<QcfChapter>      // parse index.json once (cache)
    fun page(n: Int): QcfPage             // parse pages/%03d.json (cache last few)
}
```

- `index.json` → `chapters[]`: use `id`, `name`, `name_arabic`, `verses_count`, `pages[0]`(start), `pages[1]`(end).
- `pages/%03d.json` → `page`, `font`, `lines[].words[]`: `code`, `font`, `type`, `verse_key`.

---

## 3. Rendering a page 🚧 (the one real unknown — spike this FIRST, see §6)

**Glyph rule (critical):** display each word by converting its `code` to a char and rendering it in its `font` — **never render the `text` field.**

```kotlin
val glyph = String(Character.toChars(word.code))      // the PUA char
// FontFamily for word.fontName loaded from assets/qcf4/fonts/<fontName>.ttf
```

- Build one `FontFamily` per font name on demand and **cache** them (≤48 total):
  `FontFamily(Font("qcf4/fonts/$name.ttf", context.assets))`.
- Render **line by line** (a `Column` of lines). Each line is one horizontal row of word glyphs.
- **Justification:** each line should fill the page width like the print. Try, in order, and keep the first that looks right in the spike:
  1. `Row(horizontalArrangement = Arrangement.SpaceBetween)` across the line's word glyphs;
  2. a single `Text` with `textAlign = TextAlign.Justify` built from an `AnnotatedString` (per-word `SpanStyle(fontFamily=…)`);
  3. per-line auto-fit font size so the natural line fills the width.
- `type == "surah_header"` and `bismillah`: center them, use the `QCF4_QBSML` font, no tap target.
- `type == "end"` is the ayah-number glyph — part of that ayah's tap target.
- Page canvas is fixed-count (15 lines); size text so a full page fits without vertical scroll (the layout is designed to fit — do not add per-page scrolling).

## 4. Selection & handoff

- Wrap each `word`/`end` glyph whose `verseKey != null` in a tap target (`Modifier.clickable` per word, or `ClickableText` offset→annotation).
- On tap: parse `verseKey` → `(sura, aya)`; **highlight every word on the page sharing that `verseKey`** (background `SpanStyle`/box tint) so the whole ayah lights up, not just the tapped word.
- Show the existing-style `ModalBottomSheet`: **Analyze Tajweed** (enabled) + **Memorize (Coming Soon)** (disabled) — copy the exact composable from the current `MushafScreen`.
- Analyze Tajweed → `onAyahSelected(sura, aya)` → nav `recitation/$sura/$aya` (unchanged).

## 5. Navigation (surah index → pager)

Reuse the existing `NavGraph` structure. Replace the current `mushaf` destination:

- `mushaf` → **`SurahIndexScreen`** (LazyColumn of `chapters()`; row = number badge + English + Arabic name + "N verses"). Tap → `navigate("mushaf_page/${chapter.startPage}")`.
- `mushaf_page/{page}` (new, `NavType.IntType`) → **`MushafPagerScreen(startPage)`**: `HorizontalPager(pageCount=604, reverseLayout=true)` (RTL, page 1 on the right), initial page = `startPage-1`. Each page = the §3 renderer for page `index+1`.
- Bottom nav "Qur'an" tab keeps pointing at `mushaf` (the index). `mushaf_page` is a drill-in: hide the bottom bar there (don't add it to `showBottomBar`), system back returns to the index.
- **Delete** the old `MushafScreen.kt`, `ui/mushaf/AyahInfoDb.kt`, `ui/mushaf/AyahBox.kt`, `demoPages`, and the placeholder `assets/page1.png`, `page598.png`, `ayahinfo.db`.

---

## 6. Build order & acceptance gates

🚧 **Gate 1 — page-1 spike (do before anything else):** stage only `index.json`, `pages/001.json`, and fonts `QCF4_Hafs_01.ttf` + `QCF4_QBSML.ttf`. Render page 1 (Al-Fatihah) with the §3 renderer and make ONE ayah selectable. **Acceptance: a screenshot of page 1 that visually matches the printed Fatihah page (correct glyphs, lines justified, header + basmala centered), and tapping any word highlights the whole ayah + opens the sheet.** If justification looks wrong, fix the §3 strategy here — not after wiring 604 pages.

Then:
1. Stage all 604 pages + all 48 fonts. Verify a dense page (e.g. a page of Al-Baqarah) still fits and reads.
2. `SurahIndexScreen` + `mushaf_page` route + pager, RTL, opens at the right page.
3. Delete old image mushaf + placeholder assets (§5).

🚧 **Gate 2 — clean build & run:** `cd android && ./gradlew build` passes, app launches on a device/emulator, and the full flow works cold: splash → auth → home → Qur'an (surah index) → tap surah → mushaf page → tap ayah → Analyze Tajweed → record → feedback → try again. "Compiles" is not "works" — actually run it. (Also confirms the pending Supabase `3.1.4` bump resolves.)

---

## 7. Acceptance checklist

- [ ] Surah index lists all 114 with correct names + verse counts.
- [ ] Tapping a surah opens the mushaf at that surah's start page (RTL).
- [ ] Pages render from `code`→PUA glyphs (not `text`), correct per-page font, justified, headers/basmala centered.
- [ ] Tapping any word highlights the whole ayah and opens {Analyze Tajweed, Memorize(disabled)}.
- [ ] Analyze Tajweed lands on `RecitationScreen` with the correct `(sura, aya)` and the record→analyze→try-again loop works (not a 401).
- [ ] Old image `MushafScreen` + placeholder assets removed; `./gradlew build` clean; app runs.
