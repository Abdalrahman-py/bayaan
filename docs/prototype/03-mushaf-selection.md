# Owner C — Mushaf Paged Ayah Selection

> **The hard part.** A paged Quran-image viewer where tapping an ayah's region selects it and hands off `(sura, aya)`. Modeled on **quran_android** — but that's classic Views, and **we're Compose, so there's no drop-in; this is real work.** You develop standalone against one bundled page; you don't need auth or the rest of the app.
>
> **Read first:** [`android/UI_SPEC.md`](../../android/UI_SPEC.md). **You own the list fallback** — the demo must survive even if bbox scaling fights you.

---

## The one interface you expose

```kotlin
@Composable
fun MushafScreen(
    onAyahSelected: (sura: Int, aya: Int) -> Unit,
    modifier: Modifier = Modifier,
)
```
The nav layer (Owner B) passes `onAyahSelected = { s, a -> navController.navigate("recitation/$s/$a") }`. That's your entire contract with the app. Everything else is internal.

---

## Assets you get from Owner D (guide 04)

Bundled in `app/src/main/assets/` (no download infra in this build):
- A **small subset of Madani page images** at **one image width** (e.g. `page604.png`), from [quran.com-images](https://github.com/quran/quran.com-images).
- The **`ayahinfo` SQLite DB** for that width — bounding boxes `(min_x, min_y, max_x, max_y)` (or `x, y, width, height` depending on the DB variant — **confirm the column names on the actual file**) per `(sura, ayah, page)` glyph line.

> Coordinate the **image width** with D: the `ayahinfo` boxes are in the pixel space of that exact width. Mismatched width = misaligned boxes.

---

## Files you create

| File | Purpose |
|---|---|
| `ui/screens/MushafScreen.kt` | the pager + overlay + action menu |
| `ui/mushaf/AyahInfoDb.kt` | read-only `SQLiteDatabase` open-from-assets + query → `List<AyahBox>` |
| `ui/mushaf/AyahBox.kt` | `data class AyahBox(val sura: Int, val aya: Int, val x: Int, val y: Int, val w: Int, val h: Int)` |

Optional dep: **Coil** for async image loading (or decode from assets with `BitmapFactory` — your call; one bundled page is small).

---

## Implementation (step-by-step)

1. **Pager:** `HorizontalPager` over the bundled pages; each page renders its `Image` (from assets). Track the page's intrinsic image width in pixels.
2. **Boxes:** on page change, query `ayahinfo` for that page → `List<AyahBox>`. Open the DB read-only from assets (copy the `.db` to `context.cacheDir` once, then `SQLiteDatabase.openDatabase(..., OPEN_READONLY)` — assets aren't a file path). No Room.
3. **Overlay + scaling (the #1 bug):** overlay a `Canvas` (or `Modifier.drawWithContent`) sized to the **displayed** image. Compute `scale = displayedWidth / imageIntrinsicWidth` and multiply every box coord by `scale` before drawing/hit-testing. If the image is letterboxed, also offset by the empty margin. **Get this right on ONE page before touching the pager.**
4. **Hit-test:** `Modifier.pointerInput { detectTapGestures(onTap = …, onLongPress = …) }` on the overlay. Convert the tap `Offset` into image space (or scale the boxes into view space — pick one space and stay in it) and find the box containing the point → `(sura, aya)`. Draw a translucent `primary`-tinted rect over the selected box.
5. **Action menu:** on selection show a `ModalBottomSheet` (or `DropdownMenu`) with two items:
   - **Memorize** — `enabled = false`, label "Coming soon" (locked this build).
   - **Analyze Tajweed** — `onClick = { onAyahSelected(sura, aya) }`.

Use the shared tokens from `UI_SPEC.md` for the sheet/menu (surface color, 16dp radius, ≥48dp touch targets).

---

## Day-1 spike (do this FIRST, before the pager)

Render **one** page image + draw the **scaled** boxes for that page + select **one** ayah correctly (highlight lands exactly on the tapped ayah). If the boxes align after scaling, you're safe to build the pager. **If it's not working by end of Day 1 → invoke the fallback.**

**Preview strategy:** you can't easily `@Preview` real asset decoding + SQLite. Preview the overlay logic with a hardcoded `List<AyahBox>` over a solid-color `Box` sized like a page, so the scaling/hit-test/highlight is reviewable without assets.

---

## Fallback (guaranteed demo — you own it)

Reuse the existing [`VersePickerScreen`](../../android/app/src/main/java/com/bayaan/ui/screens/VersePickerScreen.kt) (surah→ayah **list**, already built). Wrap its `onPickAyah` with the same **two-option action menu** (Memorize disabled + Analyze Tajweed) so the UX matches, then call `onAyahSelected`. The full record→analyze→highlight loop still demos — just without the page-image risk. Keep this wired and working **all week**, not just as a Day-4 panic button.

---

## Expected output / acceptance (Owner C)

- [ ] `MushafScreen(onAyahSelected)` compiles and is navigable from `home` via B's `mushaf` route.
- [ ] Tapping an ayah's region highlights **exactly that ayah's box** (scaling correct on every page, not just page 1).
- [ ] Action menu shows **Memorize (disabled, "Coming soon")** + **Analyze Tajweed**; the latter fires `onAyahSelected(sura, aya)` with the right numbers.
- [ ] Selected `(sura, aya)` reaches `RecitationScreen` and shows the **correct verse text** (coordinate the demo pages with Owner D's text gotcha — guide 04).
- [ ] Overlay logic has a `@Preview` against hardcoded boxes.
- [ ] **Fallback path works** end-to-end as an alternative (demonstrated, not theoretical).
