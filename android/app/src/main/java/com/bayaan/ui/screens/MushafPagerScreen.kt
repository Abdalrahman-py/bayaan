package com.bayaan.ui.screens

import android.content.Context
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.text.TextMeasurer
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.bayaan.ui.mushaf.QcfChapter
import com.bayaan.ui.mushaf.QcfLine
import com.bayaan.ui.mushaf.QcfPage
import com.bayaan.ui.mushaf.QcfRepository
import com.bayaan.ui.mushaf.QcfWord
import com.bayaan.ui.mushaf.getFontFamily

// The mushaf page is always a cream/black printed page, independent of app theme —
// intentionally not sourced from MaterialTheme.colorScheme (see ink color comment below).
private val MushafGreen = Color(0xFF2C5E43) // Elegant Quranic Green — headers, ayah-end markers, selection tint
private val MushafPaper = Color(0xFFFDFBF7)
private val MushafPaperBorder = Color(0xFFE8E2D5)
private val MushafHeaderBg = Color(0xFFF4EFE6)
private val MushafHeaderBorder = Color(0xFFDCD6C8)
private val MushafInk = Color(0xFF000000)

// ponytail: uniformFontSizeForLines measures every word on the page (~100+ calls);
// re-entering a page after scrolling away redoes it since Pager discards the
// composable slot (and its remember) outside beyondBoundsPageCount. Keyed on
// dimensions too (not just page number) since rotation recreates the Activity but
// not this process-lifetime cache — a stale entry from the old orientation would
// otherwise render the wrong size after rotating back to a visited page.
private val pageFontSizeCache = mutableMapOf<Triple<Int, Int, Int>, TextUnit>()

@OptIn(ExperimentalFoundationApi::class, ExperimentalMaterial3Api::class)
@Composable
fun MushafPagerScreen(
    startPage: Int,
    onAyahSelected: (sura: Int, aya: Int) -> Unit,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    val qcfRepository = remember { QcfRepository(context) }
    val chapters = remember { qcfRepository.chapters() }
    
    // 604 pages total. Pager pages are 0-indexed, so page 1 is index 0.
    // In Quran, page numbering starts from 1 up to 604.
    // reverseLayout = true for RTL navigation (swiping right to go to next page).
    val pagerState = rememberPagerState(
        initialPage = startPage - 1,
        pageCount = { 604 }
    )

    var selectedVerseKey by remember { mutableStateOf<String?>(null) }
    var showMenu by remember { mutableStateOf(false) }

    // Clear selection when turning pages
    LaunchedEffect(pagerState.currentPage) {
        selectedVerseKey = null
    }

    Scaffold(
        modifier = modifier.fillMaxSize(),
        containerColor = MaterialTheme.colorScheme.background
    ) { innerPadding ->
        HorizontalPager(
            state = pagerState,
            reverseLayout = true,
            // ponytail: parsing a page's JSON + measuring its glyphs for uniform
            // sizing (see uniformFontSizeForLines) is real main-thread work; without
            // this it happens mid-swipe as the neighbor page is dragged into view.
            // Pre-composing 1 page ahead moves that work to idle time instead.
            beyondViewportPageCount = 1,
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
        ) { pageIndex ->
            val pageNum = pageIndex + 1
            // produceState: JSON parse runs on qcfRepository's ioDispatcher, not this
            // composition frame — fixes the main-thread spike on first open and on
            // any page swiped to for the first time. Result<> (vs a bare nullable)
            // lets "still loading" (null) read differently from "load failed"
            // (Result.failure) so we don't flash the error text while loading.
            val pageResult by produceState<Result<QcfPage>?>(initialValue = null, pageNum) {
                value = try {
                    Result.success(qcfRepository.page(pageNum))
                } catch (e: java.io.IOException) {
                    Result.failure(e)
                }
            }
            val pageData = pageResult?.getOrNull()

            if (pageResult == null) {
                // Still loading — avoid flashing the error/blank state.
            } else if (pageData != null) {
                MushafPageRenderer(
                    page = pageData,
                    chapters = chapters,
                    selectedVerseKey = selectedVerseKey,
                    onWordTapped = { verseKey ->
                        selectedVerseKey = verseKey
                        showMenu = true
                    }
                )
            } else {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = "Couldn't load page $pageNum.",
                        textAlign = TextAlign.Center,
                        color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.5f)
                    )
                }
            }
        }

        if (showMenu && selectedVerseKey != null) {
            val parts = selectedVerseKey!!.split(":")
            val sura = parts[0].toInt()
            val aya = parts[1].toInt()

            ModalBottomSheet(
                onDismissRequest = { showMenu = false },
                containerColor = MaterialTheme.colorScheme.surface,
                shape = RoundedCornerShape(topStart = 16.dp, topEnd = 16.dp)
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(24.dp)
                ) {
                    Text(
                        text = "Surah $sura, Ayah $aya",
                        style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold),
                        color = MaterialTheme.colorScheme.onSurface
                    )
                    Spacer(modifier = Modifier.height(16.dp))

                    TextButton(
                        onClick = {
                            showMenu = false
                            onAyahSelected(sura, aya)
                        },
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text(
                            text = "Analyze Tajweed",
                            style = MaterialTheme.typography.bodyLarge.copy(
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.primary
                            )
                        )
                    }

                    Spacer(modifier = Modifier.height(8.dp))

                    TextButton(
                        onClick = {},
                        enabled = false,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text(
                            text = "Memorize (Coming Soon)",
                            style = MaterialTheme.typography.bodyLarge.copy(
                                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.3f)
                            )
                        )
                    }

                    Spacer(modifier = Modifier.height(24.dp))
                }
            }
        }
    }
}

@Composable
fun MushafPageRenderer(
    page: QcfPage,
    chapters: List<QcfChapter>,
    selectedVerseKey: String?,
    onWordTapped: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    val density = LocalDensity.current
    val textMeasurer = rememberTextMeasurer()

    // Beautiful cream book-like paper background
    Box(
        modifier = modifier
            .fillMaxSize()
            .padding(12.dp)
            .background(MushafPaper, shape = RoundedCornerShape(8.dp))
            .border(1.5.dp, MushafPaperBorder, shape = RoundedCornerShape(8.dp))
            .padding(16.dp),
        contentAlignment = Alignment.Center
    ) {
        BoxWithConstraints(Modifier.fillMaxSize()) {
            val availableWidthPx = with(density) { maxWidth.toPx() }
            val availableHeightPx = with(density) { maxHeight.toPx() }

            // QCF glyphs are page-specific ligatures with no shipped width metadata.
            // Shrinking font size per-LINE (first pass) killed the overlap but left
            // every line a different size on the same page (dense lines shrink more
            // than sparse ones) — reads as broken typography, not a fixed mushaf page.
            // Real mushaf pages are one uniform size per page, so measure every line's
            // natural width up front and use the single smallest scale for the whole
            // page: the worst-case line stays overlap-free, and every other line
            // matches it exactly, same as a printed page. Pages are a fixed 15 lines
            // (8 on pages 1-2) — also check the whole page's natural height against
            // the screen, or Column's SpaceEvenly hits the same negative-gap bug
            // Row/SpaceBetween had, just stacking lines vertically instead of words
            // horizontally.
            // Tried moving this to Dispatchers.Default + produceState (measuring is
            // real CPU work, ~100+ measure() calls/page) — measured WORSE on-device
            // (25.7% janky frames vs 11.4% synchronous, 90th pct 200ms vs 38ms). This
            // device's CPU is the bottleneck during a fling, not main-thread scheduling,
            // so background threads just compete with Main/RenderThread for the same
            // cores instead of freeing them up. Reverted to synchronous measurement.
            val pageFontSize = remember(page, availableWidthPx, availableHeightPx) {
                val cacheKey = Triple(page.page, availableWidthPx.toInt(), availableHeightPx.toInt())
                pageFontSizeCache.getOrPut(cacheKey) {
                    uniformFontSizeForLines(page.lines, availableWidthPx, availableHeightPx, density, textMeasurer, context)
                }
            }

            // Arabic reads right-to-left: flip the layout so word 1 sits on the right
            // and multi-verse lines order correctly. Only wraps the page glyphs.
            CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Rtl) {
            Column(
                modifier = Modifier.fillMaxSize(),
                verticalArrangement = Arrangement.SpaceEvenly,
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                page.lines.forEach { line ->
                    val hasSurahHeader = line.words.any { it.type == "surah_header" }

                    // Find chapter context to determine if this line contains the last verse of the surah
                    val sampleWordWithVerse = line.words.firstOrNull { it.verseKey != null }
                    val surahId = sampleWordWithVerse?.verseKey?.split(":")?.get(0)?.toIntOrNull()
                    val currentChapter = chapters.find { it.id == surahId }

                    val isLastLine = isLastLineOfSurah(line, currentChapter)

                    // Page 1 and Page 2 are fully centered in the Madinah Mushaf.
                    // Surah headers and the last lines of suras are also centered.
                    val alignCenter = page.page <= 2 || hasSurahHeader || isLastLine

                    if (hasSurahHeader) {
                        SurahHeaderRenderer(words = line.words)
                    } else {
                        MushafLineRenderer(
                            line = line,
                            fontSize = pageFontSize,
                            alignCenter = alignCenter,
                            selectedVerseKey = selectedVerseKey,
                            onWordTapped = onWordTapped
                        )
                    }
                }
            }
            }
        }
    }
}

// Extracted so the same scaling logic can be exercised from a @Preview (no device
// needed) as from production — a preview that reimplemented this separately would
// stop being a real regression guard the moment the two copies drifted.
// Shrink to fit ~4% under the theoretical max, not the exact boundary. The fit math
// measures each glyph in isolation and scales linearly, but real layout snaps every
// glyph's advance to whole pixels — across 9-13 words/line that rounding drift adds
// up, worst at the last-placed word (leftmost, since RTL places word 1 rightmost).
// An exact-fit target leaves zero room for that drift and tips back into the same
// negative-gap overlap on some lines, or reads as a vanished inter-word gap on others.
private const val FIT_SAFETY_MARGIN = 0.96f

private fun uniformFontSizeForLines(
    lines: List<QcfLine>,
    availableWidthPx: Float,
    availableHeightPx: Float,
    density: Density,
    textMeasurer: TextMeasurer,
    context: Context
): TextUnit {
    val safeAvailableWidthPx = availableWidthPx * FIT_SAFETY_MARGIN
    val safeAvailableHeightPx = availableHeightPx * FIT_SAFETY_MARGIN
    val wordPaddingPx = with(density) { (WORD_PADDING * 2).toPx() }
    var minScale = 1f
    var wordLineHeightPx = 0f
    var wordLineCount = 0
    var headerLineHeightPx = 0f
    var headerLineCount = 0

    lines.forEach { line ->
        val headerWord = line.words.firstOrNull { it.type == "surah_header" }
        if (headerWord != null) {
            headerLineCount++
            if (headerLineHeightPx == 0f) {
                // SurahHeaderRenderer always renders at a fixed 24.sp, independent of
                // the body scale, so its height is a fixed cost, not a scaled one.
                headerLineHeightPx = textMeasurer.measure(
                    text = headerWord.glyph,
                    style = TextStyle(
                        fontFamily = getFontFamily(context, headerWord.fontName),
                        fontSize = 24.sp,
                        letterSpacing = 0.sp
                    )
                ).size.height.toFloat()
            }
            return@forEach
        }

        wordLineCount++
        var lineWidthPx = 0f
        line.words.forEach { word ->
            val result = textMeasurer.measure(
                text = word.glyph,
                style = TextStyle(
                    fontFamily = getFontFamily(context, word.fontName),
                    fontSize = BASE_GLYPH_SIZE,
                    letterSpacing = 0.sp
                )
            )
            lineWidthPx += result.size.width + wordPaddingPx
            if (wordLineHeightPx == 0f) wordLineHeightPx = result.size.height.toFloat()
        }
        if (lineWidthPx > safeAvailableWidthPx) {
            val scale = safeAvailableWidthPx / lineWidthPx
            if (scale < minScale) minScale = scale
        }
    }

    // SurahHeaderRenderer's own vertical padding: padding(vertical=4dp) outside the
    // background + padding(vertical=8dp) inside it, doubled for top+bottom.
    val headerExtraPaddingPx = with(density) { (4.dp + 8.dp).toPx() * 2 }
    val naturalHeightPx = wordLineCount * (wordLineHeightPx + wordPaddingPx) +
        headerLineCount * (headerLineHeightPx + headerExtraPaddingPx)
    if (naturalHeightPx > safeAvailableHeightPx) {
        val heightScale = safeAvailableHeightPx / naturalHeightPx
        if (heightScale < minScale) minScale = heightScale
    }

    return BASE_GLYPH_SIZE * minScale
}

private fun isLastLineOfSurah(line: QcfLine, chapter: QcfChapter?): Boolean {
    if (chapter == null) return false
    val lastVerseKey = "${chapter.id}:${chapter.versesCount}"
    return line.words.any { it.type == "end" && it.verseKey == lastVerseKey }
}

@Composable
fun SurahHeaderRenderer(
    words: List<QcfWord>,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp)
            .background(MushafHeaderBg, shape = RoundedCornerShape(6.dp))
            .border(1.dp, MushafHeaderBorder, shape = RoundedCornerShape(6.dp))
            .padding(vertical = 8.dp),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically
    ) {
        words.forEach { word ->
            val glyph = word.glyph
            Text(
                text = glyph,
                fontFamily = getFontFamily(context, word.fontName),
                fontSize = 24.sp,
                letterSpacing = 0.sp, // must match the measurement TextStyle exactly — see uniformFontSizeForLines
                color = MushafGreen,
                textAlign = TextAlign.Center
            )
        }
    }
}

private val BASE_GLYPH_SIZE = 28.sp
private val WORD_PADDING = 2.dp // matches the per-word Box padding below

@Composable
fun MushafLineRenderer(
    line: QcfLine,
    fontSize: TextUnit,
    alignCenter: Boolean,
    selectedVerseKey: String?,
    onWordTapped: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current

    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = if (alignCenter) Arrangement.Center else Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        line.words.forEach { word ->
            val isHighlighted = word.verseKey != null && word.verseKey == selectedVerseKey
            val backgroundColor = if (isHighlighted) MushafGreen.copy(alpha = 0.24f) else Color.Transparent
            val onClick = remember(word, onWordTapped) {
                { word.verseKey?.let { onWordTapped(it) }; Unit }
            }

            Box(
                modifier = Modifier
                    .background(backgroundColor, shape = RoundedCornerShape(4.dp))
                    .clickable(
                        enabled = word.verseKey != null,
                        onClick = onClick,
                        interactionSource = remember { MutableInteractionSource() },
                        indication = null // No default ripple to keep text neat
                    )
                    .padding(horizontal = WORD_PADDING, vertical = WORD_PADDING)
            ) {
                val glyph = word.glyph
                // Fixed ink on the cream page (the page is always light, regardless of
                // app theme). Ayah-end markers get the green accent like the header.
                // Pure black + larger size: the QCF strokes are thin, so this is what
                // gives readable contrast on the cream background.
                val inkColor = if (word.type == "end") MushafGreen else MushafInk
                Text(
                    text = glyph,
                    fontFamily = getFontFamily(context, word.fontName),
                    fontSize = fontSize,
                    letterSpacing = 0.sp, // must match the measurement TextStyle exactly — see uniformFontSizeForLines
                    color = inkColor,
                    textAlign = TextAlign.Center
                )
            }
        }
    }
}

// Real word data from pages/003.json line 1 (Al-Baqarah 2:6) — the exact 9-word
// dense line that overlapped before the shrink-to-fit fix. Rendered here at a narrow
// width as a regression guard: if this ever overlaps again in the preview, the fix
// broke without needing a device build.
private val PreviewDenseLine = QcfLine(
    line = 1,
    words = listOf(
        QcfWord(code = 61776, fontName = "QCF4_Hafs_01", type = "word", verseKey = "2:6"),
        QcfWord(code = 61777, fontName = "QCF4_Hafs_01", type = "word", verseKey = "2:6"),
        QcfWord(code = 61778, fontName = "QCF4_Hafs_01", type = "word", verseKey = "2:6"),
        QcfWord(code = 61779, fontName = "QCF4_Hafs_01", type = "word", verseKey = "2:6"),
        QcfWord(code = 61780, fontName = "QCF4_Hafs_01", type = "word", verseKey = "2:6"),
        QcfWord(code = 61781, fontName = "QCF4_Hafs_01", type = "word", verseKey = "2:6"),
        QcfWord(code = 61782, fontName = "QCF4_Hafs_01", type = "word", verseKey = "2:6"),
        QcfWord(code = 61783, fontName = "QCF4_Hafs_01", type = "word", verseKey = "2:6"),
        QcfWord(code = 61784, fontName = "QCF4_Hafs_01", type = "word", verseKey = "2:6"),
    )
)

private val PreviewSparseLine = QcfLine(
    line = 4,
    words = listOf(
        QcfWord(code = 63232, fontName = "QCF4_Hafs_47", type = "word", verseKey = "112:4"),
        QcfWord(code = 63233, fontName = "QCF4_Hafs_47", type = "word", verseKey = "112:4"),
        QcfWord(code = 63234, fontName = "QCF4_Hafs_47", type = "word", verseKey = "112:4"),
        QcfWord(code = 63235, fontName = "QCF4_Hafs_47", type = "word", verseKey = "112:4"),
        QcfWord(code = 63236, fontName = "QCF4_Hafs_47", type = "word", verseKey = "112:4"),
        QcfWord(code = 63237, fontName = "QCF4_Hafs_47", type = "end", verseKey = "112:4"),
    )
)

// Preview width (320dp) minus the demo Box's 8dp padding on each side.
private val PREVIEW_AVAILABLE_WIDTH = 304.dp
// Generously tall — these single-line previews are only exercising the horizontal
// fit, so the height side of uniformFontSizeForLines should never be the binding one.
private val PREVIEW_TALL_HEIGHT = 2000.dp

@Preview(name = "Dense line (Baqarah 2:6, narrow width) — was overlapping pre-fix", showBackground = true, widthDp = 320)
@Composable
private fun MushafLineRendererDensePreview() {
    val density = LocalDensity.current
    val textMeasurer = rememberTextMeasurer()
    val context = LocalContext.current
    val availableWidthPx = with(density) { PREVIEW_AVAILABLE_WIDTH.toPx() }
    val availableHeightPx = with(density) { PREVIEW_TALL_HEIGHT.toPx() }
    val fontSize = remember {
        uniformFontSizeForLines(listOf(PreviewDenseLine), availableWidthPx, availableHeightPx, density, textMeasurer, context)
    }
    Box(modifier = Modifier.background(MushafPaper).padding(8.dp)) {
        MushafLineRenderer(
            line = PreviewDenseLine,
            fontSize = fontSize,
            alignCenter = false,
            selectedVerseKey = null,
            onWordTapped = {}
        )
    }
}

@Preview(name = "Sparse line, same width — should stay near base size", showBackground = true, widthDp = 320)
@Composable
private fun MushafLineRendererSparsePreview() {
    val density = LocalDensity.current
    val textMeasurer = rememberTextMeasurer()
    val context = LocalContext.current
    val availableWidthPx = with(density) { PREVIEW_AVAILABLE_WIDTH.toPx() }
    val availableHeightPx = with(density) { PREVIEW_TALL_HEIGHT.toPx() }
    val fontSize = remember {
        uniformFontSizeForLines(listOf(PreviewSparseLine), availableWidthPx, availableHeightPx, density, textMeasurer, context)
    }
    Box(modifier = Modifier.background(MushafPaper).padding(8.dp)) {
        MushafLineRenderer(
            line = PreviewSparseLine,
            fontSize = fontSize,
            alignCenter = false,
            selectedVerseKey = null,
            onWordTapped = {}
        )
    }
}

@Preview(name = "Surah header glyph", showBackground = true, widthDp = 320)
@Composable
private fun SurahHeaderRendererPreview() {
    SurahHeaderRenderer(
        words = listOf(
            QcfWord(code = 61697, fontName = "QCF4_QBSML", type = "surah_header", verseKey = null)
        )
    )
}

// Full-page preview: mixes the dense Baqarah line with the sparse Al-Ikhlas line on
// one page, demonstrating the uniform (not per-line) scaling — both lines render at
// the same size, matched to the denser line's worst-case shrink.
@Preview(name = "Page: dense + sparse line together", showBackground = true, widthDp = 320, heightDp = 500)
@Composable
private fun MushafPageRendererPreview() {
    val samplePage = QcfPage(
        page = 3,
        fontName = "QCF4_Hafs_01",
        lines = listOf(PreviewDenseLine, PreviewSparseLine)
    )
    MushafPageRenderer(
        page = samplePage,
        chapters = emptyList(),
        selectedVerseKey = null,
        onWordTapped = {}
    )
}

// Regression guard for the vertical counterpart of the overlap bug: a real, full
// 15-line page (not a 2-line stub) squeezed into a short height. Before the height
// check was added, this would overlap/clip lines top-to-bottom exactly like the
// dense Baqarah line did left-to-right pre-fix.
@Preview(name = "Full real page, short height — was clipping pre-fix", showBackground = true, widthDp = 360, heightDp = 380)
@Composable
private fun MushafPageRendererShortHeightPreview() {
    val context = LocalContext.current
    // Preview tooling only — runBlocking is fine here, no real frame to block.
    val page = remember { kotlinx.coroutines.runBlocking { QcfRepository(context).page(3) } } // Al-Baqarah, 15 lines
    MushafPageRenderer(
        page = page,
        chapters = emptyList(),
        selectedVerseKey = null,
        onWordTapped = {}
    )
}
