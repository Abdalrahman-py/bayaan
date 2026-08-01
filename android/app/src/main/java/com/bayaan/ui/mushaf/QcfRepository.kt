package com.bayaan.ui.mushaf

import android.content.Context
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.createFontFamilyResolver
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.util.Locale
import java.util.concurrent.ConcurrentHashMap

// Each page uses one dedicated QCF glyph font, ~2MB each (48 bundled). Resolving
// a FontFamily (Typeface parse of that ~2MB file) happens synchronously the first
// time anything measures/draws it — moved here so it happens on ioDispatcher via
// preload(), not on the main thread mid-swipe. Keyed by name so both the repo and
// the renderer share one cache instead of parsing/decoding the same font twice.
//
// Concurrent because this is genuinely touched from several threads: preloadFonts()
// runs on ioDispatcher (and the Pager can have two page loads in flight — current +
// beyondViewportPageCount neighbour), while MushafPagerScreen measures and draws with
// it on the main thread. A plain mutableMapOf is a LinkedHashMap, which can corrupt
// its own table if two threads resize it at once — that is the bug being fixed here.
//
// computeIfAbsent rather than getOrPut because getOrPut is read-then-write, so two
// threads can both miss and both construct. That matters more than it looks:
// AndroidAssetFont does `init { typeface = doLoad(null) }`, i.e. the ~2MB
// Typeface.createFromAsset happens inside the Font(...) constructor, NOT lazily at
// resolve() time. So a duplicated construction is a duplicated 2MB parse.
// computeIfAbsent holds the bin lock across that parse, which is the right trade: the
// alternative is not "nobody blocks", it is "both threads parse". One waiter beats two
// parsers, and the loser's Typeface would have been thrown away regardless.
//
// (Note the duplicate instances would NOT break caching — AndroidAssetFont.equals
// compares path, and FontListFontFamily.hashCode is fonts.hashCode(), so two
// independently built instances for one name are equal and hash alike. The cost is
// the wasted parse, not a cache miss.)
private val fontCache = ConcurrentHashMap<String, FontFamily>()

fun getFontFamily(context: Context, name: String): FontFamily {
    // applicationContext: this map lives for the process, but a Context from
    // LocalContext.current is the Activity, whose AssetManager is replaced on
    // configuration change — caching that one strands the FontFamily on a dead
    // AssetManager after a rotation.
    val assets = context.applicationContext.assets
    return fontCache.computeIfAbsent(name) { n ->
        val fileName = if (n == "QCF4_QBSML") "QCF4_QBSML.ttf" else "${n}_W.ttf"
        FontFamily(Font("qcf4/fonts/$fileName", assets))
    }
}

class QcfRepository(
    private val context: Context,
    private val ioDispatcher: CoroutineDispatcher = Dispatchers.IO
) {
    // Not tied to composition — resolving here (and reading from the same font/typeface
    // cache Compose uses internally) is what lets preload() on ioDispatcher actually
    // warm the font a real Text() later draws with, instead of two separate caches.
    private val fontFamilyResolver = createFontFamilyResolver(context)
    private var cachedChapters: List<QcfChapter>? = null
    // ConcurrentHashMap: pages load on ioDispatcher, and the Pager can have two
    // page slots (current + beyondViewportPageCount neighbor) loading at once.
    private val cachedPages = ConcurrentHashMap<Int, QcfPage>()

    fun chapters(): List<QcfChapter> {
        cachedChapters?.let { return it }
        val jsonStr = context.assets.open("qcf4/index.json").bufferedReader().use { it.readText() }
        val rootObj = JSONObject(jsonStr)
        val chaptersArray = rootObj.getJSONArray("chapters")
        val list = mutableListOf<QcfChapter>()
        for (i in 0 until chaptersArray.length()) {
            val chObj = chaptersArray.getJSONObject(i)
            val pagesArr = chObj.getJSONArray("pages")
            list.add(
                QcfChapter(
                    id = chObj.getInt("id"),
                    nameEn = chObj.getString("name"),
                    nameAr = chObj.getString("name_arabic"),
                    versesCount = chObj.getInt("verses_count"),
                    startPage = pagesArr.getInt(0),
                    endPage = pagesArr.getInt(1)
                )
            )
        }
        cachedChapters = list
        return list
    }

    // Synchronous peek, for seeding produceState. Without it, an already-parsed page
    // still renders one blank frame: produceState's block runs in a LaunchedEffect,
    // which dispatches on AndroidUiDispatcher.Main, so even a pure cache hit arrives
    // a frame late. Returns null (never parses) so this stays safe to call in
    // composition.
    fun cachedPage(n: Int): QcfPage? = cachedPages[n]

    // Main-safe: asset IO + JSON parsing + font decode happen on ioDispatcher, so
    // callers can invoke this from a Composable (e.g. produceState) without
    // blocking a frame — including the ~2MB Typeface parse for a page's first use.
    suspend fun page(n: Int): QcfPage {
        cachedPages[n]?.let { return it }
        return withContext(ioDispatcher) {
            val page = parsePage(n)
            preloadFonts(page)
            page
        }
    }

    private suspend fun preloadFonts(page: QcfPage) {
        val fontNames = page.lines.asSequence()
            .flatMap { it.words.asSequence() }
            .map { it.fontName }
            .distinct()
        for (name in fontNames) {
            fontFamilyResolver.preload(getFontFamily(context, name))
        }
    }

    private fun parsePage(n: Int): QcfPage {
        cachedPages[n]?.let { return it }
        val fileName = String.format(Locale.US, "qcf4/pages/%03d.json", n)
        val jsonStr = context.assets.open(fileName).bufferedReader().use { it.readText() }
        val rootObj = JSONObject(jsonStr)
        
        val pageNum = rootObj.getInt("page")
        val pageFont = rootObj.getString("font")
        val linesArray = rootObj.getJSONArray("lines")
        val linesList = mutableListOf<QcfLine>()
        
        for (i in 0 until linesArray.length()) {
            val lineObj = linesArray.getJSONObject(i)
            val lineNum = lineObj.getInt("line")
            val wordsArray = lineObj.getJSONArray("words")
            val wordsList = mutableListOf<QcfWord>()
            
            for (j in 0 until wordsArray.length()) {
                val wObj = wordsArray.getJSONObject(j)
                val code = wObj.getInt("code")
                val font = wObj.getString("font")
                val type = wObj.getString("type")
                val verseKey = if (wObj.has("verse_key") && !wObj.isNull("verse_key")) {
                    wObj.getString("verse_key")
                } else {
                    null
                }
                wordsList.add(
                    QcfWord(
                        code = code,
                        fontName = font,
                        type = type,
                        verseKey = verseKey
                    )
                )
            }
            linesList.add(QcfLine(lineNum, wordsList))
        }
        
        val qcfPage = QcfPage(pageNum, pageFont, linesList)
        cachedPages[n] = qcfPage
        return qcfPage
    }
}
