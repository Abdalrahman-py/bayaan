# Bayaan — Android UI Build Brief (for the UI builder)

> **Historical brief.** This is the original spec the two-screen UI was built to and is still accurate for those two screens. Supabase sign-in has since entered scope (see [`AGENTS.md`](./AGENTS.md)) and is not covered here — treat "no login" below as describing the state at the time this brief was written, not the app's current scope. **[`ui/model/Models.kt`](./app/src/main/java/com/bayaan/ui/model/Models.kt) is the live source of truth** for the data contract — it has already diverged additively from this brief (e.g. `SifatError`/`sifatErrors` were added, not covered below). Check the code, not just this doc.

You are building **only the UI** for Bayaan, an Android Quran-recitation coach.
Someone else wires the logic (recording, networking, state) afterwards. Your job
is to make beautiful, correct **stateless** Compose screens and components that
accept the data types defined below and emit user events via lambdas. Do **not**
implement networking, audio recording, permissions, ViewModels, or DI — those are
wired in later against the exact contracts here. If you build those, they get
thrown away. Build for `@Preview` with the fake data provided.

---

## 1. What the app does (the demo loop)

The user picks a verse of the Quran, taps record, recites it, and the app shows
which letters they pronounced incorrectly — highlighted on the Arabic script —
with a short explanation per mistake. Then they try again. That's the whole demo.
Two surahs only: **Al-Fatihah (1)** and **Al-Bayyinah (98)**.

There is **no login, no account, no progress dashboard** in this demo.

---

## 2. Tech & project setup

- **Pure Android** (not KMP), **Jetpack Compose**, **Material 3**.
- Package: `com.bayaan`. `minSdk = 26`, target/compile = latest stable.
- Navigation: **Navigation Compose**, type-safe routes.
- Arabic text is central: the app is **RTL-aware**; verse text uses a proper
  **Uthmani/Naskh Arabic font** (e.g. bundle a Quran/Naskh font in `res/font`).
- Scaffold the Gradle project yourself (you have the Android skills). Add only
  UI dependencies. Do **not** add Ktor/Retrofit/Supabase — networking is wired
  later.

---

## 3. Screens to build (exactly two)

### Screen A — Verse Picker (start screen)
- App title/header ("Bayaan", a calm tagline is fine).
- Two surahs to choose: **Al-Fatihah** and **Al-Bayyinah** (Arabic + English name,
  verse count). Selecting one reveals its list of ayat.
- Each ayah row shows its number and a preview of the Arabic text (RTL).
- Tapping an ayah navigates to Screen B for that `(sura, aya)`.

### Screen B — Recitation (the core)
Drives off a single `RecitationUiState` (defined in §4). Render each state:
- **Ready** — the verse in large, readable Uthmani script (RTL, centered), the
  surah/ayah label, and a big **Record** button.
- **Recording** — recording affordance (pulsing mic, a timer is nice) + **Stop**.
- **Uploading** — a spinner / "checking your recitation…".
- **Result** — the verse again, but with the mistaken character ranges
  **highlighted** (see §5), a verdict line ("Perfect!" when `allCorrect`, else
  "N things to fix"), and a list of mistake cards (one per `Mistake`). Buttons:
  **Try again** and **Next ayah**.
- **Error** — a friendly message + **Retry** (e.g. "Couldn't reach the coach").

Emit all user actions as lambdas (`onRecord`, `onStop`, `onTryAgain`,
`onNextAyah`, `onRetry`, `onPickAyah`). The screen holds no logic.

> A bottom sheet for the result instead of an inline section is fine if it looks
> better — your call on layout. Keep the *data* it renders the same.

Anything beyond these two screens (history, settings, splash, the word-practice
or Arabic-level features mentioned elsewhere) is **out of scope for this demo** —
do not build it.

---

## 4. Data contract — use these types verbatim

Create these in `com.bayaan.ui.model`. The wiring layer will produce exactly
these instances; your composables must accept them as inputs. **Do not rename
fields or invent your own shapes.**

```kotlin
package com.bayaan.ui.model

/** One ayah and its canonical Uthmani text. */
data class Verse(
    val sura: Int,
    val aya: Int,
    val surahNameEn: String,
    val surahNameAr: String,
    val uthmani: String,      // the Arabic text to display AND to index into
)

/** One detected recitation mistake. */
data class Mistake(
    val charRange: IntRange,    // [start, end) indices into Verse.uthmani — what to highlight
    val isTajweed: Boolean,     // true = a tajweed-rule error, false = a plain misread
    val kind: String,           // "replace" | "insert" | "delete"
    val ruleNameEn: String?,    // e.g. "Aared Madd"  (null for plain misreads)
    val ruleNameAr: String?,    // e.g. "المد العارض للسكون"
    val expectedLen: Int?,      // e.g. 4  (counts) — may be null
    val gotLen: Int?,           // e.g. 2  — may be null
)

sealed interface RecitationUiState {
    val verse: Verse
    data class Ready(override val verse: Verse) : RecitationUiState
    data class Recording(override val verse: Verse, val elapsedSec: Int) : RecitationUiState
    data class Uploading(override val verse: Verse) : RecitationUiState
    data class Result(
        override val verse: Verse,
        val mistakes: List<Mistake>,
        val allCorrect: Boolean,
    ) : RecitationUiState
    data class Error(override val verse: Verse, val message: String) : RecitationUiState
}
```

### Fake data for your `@Preview`s

```kotlin
val previewVerse = Verse(
    sura = 1, aya = 2,
    surahNameEn = "Al-Fatihah", surahNameAr = "الفاتحة",
    uthmani = "ٱلْحَمْدُ لِلَّهِ رَبِّ ٱلْعَـٰلَمِينَ",
)
val previewMistakes = listOf(
    Mistake(charRange = 35 until 36, isTajweed = true, kind = "replace",
        ruleNameEn = "Aared Madd", ruleNameAr = "المد العارض للسكون",
        expectedLen = 4, gotLen = 2),
    Mistake(charRange = 0 until 2, isTajweed = false, kind = "delete",
        ruleNameEn = null, ruleNameAr = null, expectedLen = null, gotLen = null),
)
// Preview each RecitationUiState: Ready, Recording(elapsedSec=3), Uploading,
// Result(previewVerse, previewMistakes, allCorrect=false),
// Result(previewVerse, emptyList(), allCorrect=true), Error(previewVerse, "...").
```

---

## 5. The one hard component — highlightable verse text

This is the most important component to get right, because the wiring depends on it:

```kotlin
@Composable
fun VerseText(
    uthmani: String,
    highlights: List<IntRange> = emptyList(),  // char ranges to mark as mistakes
    modifier: Modifier = Modifier,
)
```

- Renders `uthmani` large, RTL, centered, in the Uthmani/Naskh font.
- For each range in `highlights`, visually mark **exactly those characters**
  (e.g. colored/underlined/background-tinted) — build it with `AnnotatedString`
  + `SpanStyle` over the given index ranges so arbitrary sub-spans can be styled.
- Ranges are half-open `[start, end)` indices into the `uthmani` string. They can
  be single characters. Assume they're valid and non-overlapping.
- When `highlights` is empty, it's just clean verse text (used in the Ready state).

On the Result screen, pass `highlights = mistakes.map { it.charRange }`.

---

## 6. Verse data you can hard-code (real, demo-aligned)

Use this as the picker's content and the source of `Verse.uthmani`. It's the
canonical text the recitation engine indexes against, so highlight ranges line up.

```kotlin
// com.bayaan.ui.model — demo verse list
val FATIHAH = "الفاتحة" to listOf(
    /* 1 */ "بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ",
    /* 2 */ "ٱلْحَمْدُ لِلَّهِ رَبِّ ٱلْعَـٰلَمِينَ",
    /* 3 */ "ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ",
    /* 4 */ "مَـٰلِكِ يَوْمِ ٱلدِّينِ",
    /* 5 */ "إِيَّاكَ نَعْبُدُ وَإِيَّاكَ نَسْتَعِينُ",
    /* 6 */ "ٱهْدِنَا ٱلصِّرَٰطَ ٱلْمُسْتَقِيمَ",
    /* 7 */ "صِرَٰطَ ٱلَّذِينَ أَنْعَمْتَ عَلَيْهِمْ غَيْرِ ٱلْمَغْضُوبِ عَلَيْهِمْ وَلَا ٱلضَّآلِّينَ",
)
val BAYYINAH = "البينة" to listOf(
    /* 1 */ "لَمْ يَكُنِ ٱلَّذِينَ كَفَرُوا۟ مِنْ أَهْلِ ٱلْكِتَـٰبِ وَٱلْمُشْرِكِينَ مُنفَكِّينَ حَتَّىٰ تَأْتِيَهُمُ ٱلْبَيِّنَةُ",
    /* 2 */ "رَسُولٌۭ مِّنَ ٱللَّهِ يَتْلُوا۟ صُحُفًۭا مُّطَهَّرَةًۭ",
    /* 3 */ "فِيهَا كُتُبٌۭ قَيِّمَةٌۭ",
    /* 4 */ "وَمَا تَفَرَّقَ ٱلَّذِينَ أُوتُوا۟ ٱلْكِتَـٰبَ إِلَّا مِنۢ بَعْدِ مَا جَآءَتْهُمُ ٱلْبَيِّنَةُ",
    /* 5 */ "وَمَآ أُمِرُوٓا۟ إِلَّا لِيَعْبُدُوا۟ ٱللَّهَ مُخْلِصِينَ لَهُ ٱلدِّينَ حُنَفَآءَ وَيُقِيمُوا۟ ٱلصَّلَوٰةَ وَيُؤْتُوا۟ ٱلزَّكَوٰةَ وَذَٰلِكَ دِينُ ٱلْقَيِّمَةِ",
    /* 6 */ "إِنَّ ٱلَّذِينَ كَفَرُوا۟ مِنْ أَهْلِ ٱلْكِتَـٰبِ وَٱلْمُشْرِكِينَ فِى نَارِ جَهَنَّمَ خَـٰلِدِينَ فِيهَآ أُو۟لَـٰٓئِكَ هُمْ شَرُّ ٱلْبَرِيَّةِ",
    /* 7 */ "إِنَّ ٱلَّذِينَ ءَامَنُوا۟ وَعَمِلُوا۟ ٱلصَّـٰلِحَـٰتِ أُو۟لَـٰٓئِكَ هُمْ خَيْرُ ٱلْبَرِيَّةِ",
    /* 8 */ "جَزَآؤُهُمْ عِندَ رَبِّهِمْ جَنَّـٰتُ عَدْنٍۢ تَجْرِى مِن تَحْتِهَا ٱلْأَنْهَـٰرُ خَـٰلِدِينَ فِيهَآ أَبَدًۭا رَّضِىَ ٱللَّهُ عَنْهُمْ وَرَضُوا۟ عَنْهُ ذَٰلِكَ لِمَنْ خَشِىَ رَبَّهُۥ",
)
// Al-Fatihah = sura 1, Al-Bayyinah = sura 98. Ayah numbers are 1-based.
```

---

## 7. Visual direction

Calm, reverent, modern. Generous whitespace; the Arabic verse is the hero (large,
high-contrast, comfortable line height). Mistakes highlighted in a clear but not
alarming way (a warm amber/terracotta reads better than harsh red for a learning
app). Light and dark themes. Accessible: ≥48dp touch targets, content
descriptions on icon buttons. Make it look like something a student would enjoy
opening daily. Lean on your design judgment here — this section is intentionally
open.

---

## 8. Handoff checklist (so wiring is painless)

- [ ] All screens/components are **stateless** — state in, events out via lambdas.
- [ ] They consume the **exact** types in §4 (no renamed fields, no new shapes).
- [ ] `VerseText` highlights arbitrary `[start, end)` ranges via `AnnotatedString`.
- [ ] Every state and component has a working `@Preview` using the §4 fixtures.
- [ ] No networking, recording, permissions, ViewModel, or DI code.
- [ ] Navigation between the two screens works with placeholder/in-memory data.
- [ ] Project builds and previews render.

When done, hand back. Wiring (a `RecitationViewModel` that records audio, POSTs to
`/audio/analyze`, maps the response into `RecitationUiState`) plugs into these
slots — nothing in your UI should need to change.
