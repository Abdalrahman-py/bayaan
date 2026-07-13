# Bayaan — Shared UI Spec

> **Read this before writing any screen.** Four people build screens in parallel; without one shared spec they drift into four different-looking apps. Everything here already exists in the code — **use it, don't reinvent it.** If you need a token that isn't here, add it to the theme (don't inline a hex/size in a screen).
>
> **Source of truth is the theme package, not this file.** This doc explains *how to use* it; the values live in code:
> [`Theme.kt`](app/src/main/java/com/bayaan/ui/theme/Theme.kt) · [`Color.kt`](app/src/main/java/com/bayaan/ui/theme/Color.kt) · [`Type.kt`](app/src/main/java/com/bayaan/ui/theme/Type.kt).
> **Reference implementations to copy from:** [`VersePickerScreen.kt`](app/src/main/java/com/bayaan/ui/screens/VersePickerScreen.kt) (cards, header, lists) and [`RecitationScreen.kt`](app/src/main/java/com/bayaan/ui/screens/RecitationScreen.kt) (scaffold, states, buttons, result cards).

---

## 0. Golden rules

1. **Wrap everything in `BayaanTheme { }`.** Every screen and every `@Preview`.
2. **Never hardcode a color, font size, or `TextStyle`.** Pull from `MaterialTheme.colorScheme` / `MaterialTheme.typography`. The one sanctioned exception is the mistake-highlight colors, which are named constants owned by `VerseText`/result cards (see §2).
3. **Stateless composables: state in, events out via lambdas.** No networking, recording, permissions, `ViewModel`, or DI logic inside a screen. (The two existing screens follow this — copy the shape.)
4. **Every screen and reusable component has a working `@Preview`** wrapped in `BayaanTheme`, using fake data — so it can be built and reviewed before auth/nav exist.
5. **App layout is LTR (English-first).** Do **not** mirror the app to RTL. The only right-to-left thing is the Arabic *content* — see §5.
6. **Material 3 only. Compose only. No XML layouts, no Material 2 imports.** (`android/AGENTS.md`.)

---

## 1. Color

Pull from `MaterialTheme.colorScheme` — light/dark switch automatically via `BayaanTheme`. Defined in [`Color.kt`](app/src/main/java/com/bayaan/ui/theme/Color.kt) / [`Theme.kt`](app/src/main/java/com/bayaan/ui/theme/Theme.kt).

| Role | Token | Light | Dark | Use for |
|---|---|---|---|---|
| Primary | `colorScheme.primary` | green `#2C5E43` | `#639D7E` | CTAs, selected state, brand accents |
| Secondary | `colorScheme.secondary` | sage `#8D9965` | `#A5B284` | secondary accents |
| Background | `colorScheme.background` | sand `#FCFBF7` | `#111814` | screen background (set on `Scaffold(containerColor=…)`) |
| Surface | `colorScheme.surface` | cream `#F6F4EB` | `#1A231E` | cards |
| Text | `onBackground` / `onSurface` | `#1E2922` | `#E3EAE6` | all text; use `.copy(alpha = 0.6f)` for secondary text (established pattern) |

**Mistake-highlight colors are reserved.** These three families exist only for recitation feedback and are owned by `VerseText` + the result cards — **do not use them for general UI** (no terracotta buttons, no purple chips):

| Meaning | Constant | Card background |
|---|---|---|
| Tajweed rule error | `TerracottaHighlight` `#D95A3B` | `TerracottaBackgroundLight/Dark` |
| Plain misread | `PlainErrorHighlight` `#C084FC` | `PlainErrorBackgroundLight/Dark` |
| Letter-characteristic (sifat) error | `SifatHighlight` `#2B7AB3` | `SifatBackgroundLight/Dark` |

For a normal accent, use `primary`. `TerracottaHighlight` is also used for the recording timer/stop affordance (see `RecitationScreen`) — that's the one non-feedback exception, already implemented.

---

## 2. Typography

Use `MaterialTheme.typography` — the M3 scale is configured in [`Type.kt`](app/src/main/java/com/bayaan/ui/theme/Type.kt). Latin text uses the default system font.

| Style | Size/weight | Use for |
|---|---|---|
| `displayLarge` | 32 Bold | app title / hero numbers |
| `headlineMedium` | 24 SemiBold | screen titles |
| `titleLarge` | 20 SemiBold | card titles, surah names |
| `bodyLarge` | 16 | body / taglines |
| `bodyMedium` | 14 | secondary text, captions |
| `labelLarge` | 14 Medium | button labels |

**Arabic text never uses the default font.**
- **Quranic verse text → `QuranTextStyle`** (Amiri, 36sp / 56sp line height) via `VerseText`. Don't render verses yourself.
- **Any standalone Arabic word** (surah name, بَيَان wordmark, a rule name) → `fontFamily = AmiriFontFamily`, sized inline (see `SurahCard` uses 24sp, header wordmark 48sp).

---

## 3. Spacing & shape

Matches [`VersePickerScreen.kt`](app/src/main/java/com/bayaan/ui/screens/VersePickerScreen.kt) and [`RecitationScreen.kt`](app/src/main/java/com/bayaan/ui/screens/RecitationScreen.kt). Keep new screens consistent with these:

- **Screen padding:** `horizontal = 16.dp` (lists) or `20.dp` (focused/content screens like recitation).
- **Vertical rhythm:** `16.dp` between blocks; `24.dp` between major sections; `32.dp` trailing spacer at list end; `8.dp` leading spacer under a top bar.
- **Cards:** `RoundedCornerShape(16.dp)` (24.dp for the hero verse card), `containerColor = colorScheme.surface`, `CardDefaults.cardElevation(2.dp)`, inner `padding(20.dp)` (or 16.dp for compact feedback cards).
- **Pills / small badges:** `RoundedCornerShape(8.dp)`.
- **Buttons:** `RoundedCornerShape(12.dp)`, height `48–52.dp`. Primary = filled `Button(primary)`; secondary = `OutlinedButton` with 2dp border in `primary`.

---

## 4. Component conventions (reuse — do not fork)

- **`BayaanHeader`** — Owner B extracts this from `VersePickerScreen`'s private `HeaderSection`: بَيَان (Amiri, 48sp, `primary`) + "Bayaan" (`displayLarge`, ExtraBold) + a `bodyLarge` tagline at 70% alpha. **Use it on onboarding, auth, and home** so branding is pixel-identical everywhere.
- **Primary action** = full-width `Button` with `colorScheme.primary`. While an async action is in flight: **disable it and show an inline `CircularProgressIndicator`** (see the `Uploading` state in `RecitationScreen` for the spinner treatment).
- **Text input** = `OutlinedTextField`. Inline validation errors: `bodyMedium`, in the terracotta family (`TerracottaHighlight`), directly under the field.
- **Loading** = `CircularProgressIndicator(color = primary)`. Cold starts (Render + Modal free tiers) are slow — spinners must be visible and paired with honest text ("Analyzing recitation…"), never a frozen-looking screen.
- **Top bar / back** = `TopAppBar` with `containerColor = background`; back icon is `Icons.AutoMirrored.Filled.ArrowBack` with a `contentDescription`.
- **Result feedback cards** (tajweed / sifat) already exist in `RecitationScreen` — don't rebuild them.

---

## 5. Arabic / RTL rules

- The app is **LTR**. Do not force `LayoutDirection.Rtl` on whole screens.
- Arabic *content* renders right-to-left on its own via Unicode bidi. For a standalone Arabic `Text`, follow the `AyahRow` pattern: `textAlign = TextAlign.End` + `style = …copy(textDirection = TextDirection.Rtl)`. Verse blocks: just use `VerseText`, which handles it.
- **Never reverse Arabic strings** or split them by character for layout. Highlight ranges are indices into the canonical `uthmani` string and are handled inside `VerseText`.
- `AndroidManifest` already sets `android:supportsRtl="true"` — leave it.

---

## 6. Accessibility (non-negotiable)

- Touch targets **≥ 48dp**.
- **`contentDescription` on every icon button** (decorative-only icons may pass `null`, as the result-card icons do).
- Don't encode meaning in color alone — mistake cards pair color with a title + icon; keep that pattern.
- Respect dark mode: never hardcode black/white — use `onSurface`/`onBackground` (the result cards read `isSystemInDarkTheme()` to pick the right tinted background; copy that if you add a tinted surface).

---

## 7. Handoff checklist (per screen)

- [ ] Wrapped in `BayaanTheme`; no hardcoded colors/sizes/`TextStyle`s.
- [ ] Stateless — all state is a parameter, all actions are lambdas.
- [ ] Working `@Preview`(s) with fake data for **every** visual state.
- [ ] Uses `BayaanHeader` where branding appears; uses shared card/button/spacing tokens.
- [ ] Arabic (if any) via `VerseText` or the `AyahRow` RTL pattern — never reversed strings.
- [ ] Icon buttons have `contentDescription`; touch targets ≥ 48dp; looks right in light **and** dark.

---

**Data contract** (types the recitation screen consumes) lives in [`UI_BRIEF.md`](UI_BRIEF.md) §4 and in [`ui/model/Models.kt`](app/src/main/java/com/bayaan/ui/model/Models.kt) — don't rename those fields.
