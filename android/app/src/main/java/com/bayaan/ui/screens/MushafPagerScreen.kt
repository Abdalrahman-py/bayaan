package com.bayaan.ui.screens

import android.content.Context
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
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
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.bayaan.ui.mushaf.QcfChapter
import com.bayaan.ui.mushaf.QcfLine
import com.bayaan.ui.mushaf.QcfPage
import com.bayaan.ui.mushaf.QcfRepository
import com.bayaan.ui.mushaf.QcfWord

private val fontCache = mutableMapOf<String, FontFamily>()

fun getFontFamily(context: Context, name: String): FontFamily {
    return fontCache.getOrPut(name) {
        val fileName = if (name == "QCF4_QBSML") "QCF4_QBSML.ttf" else "${name}_W.ttf"
        val path = "qcf4/fonts/$fileName"
        FontFamily(Font(path, context.assets))
    }
}

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
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
        ) { pageIndex ->
            val pageNum = pageIndex + 1
            val pageData = remember(pageNum) {
                try {
                    qcfRepository.page(pageNum)
                } catch (e: Exception) {
                    null
                }
            }

            if (pageData != null) {
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
                        text = "Page $pageNum JSON or fonts not loaded.\n(Phase 1 Spike includes Page 1 only)",
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
    // Beautiful cream book-like paper background
    Box(
        modifier = modifier
            .fillMaxSize()
            .padding(12.dp)
            .background(Color(0xFFFDFBF7), shape = RoundedCornerShape(8.dp))
            .border(1.5.dp, Color(0xFFE8E2D5), shape = RoundedCornerShape(8.dp))
            .padding(16.dp),
        contentAlignment = Alignment.Center
    ) {
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
            .background(Color(0xFFF4EFE6), shape = RoundedCornerShape(6.dp))
            .border(1.dp, Color(0xFFDCD6C8), shape = RoundedCornerShape(6.dp))
            .padding(vertical = 8.dp),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically
    ) {
        words.forEach { word ->
            val glyph = String(Character.toChars(word.code))
            Text(
                text = glyph,
                fontFamily = getFontFamily(context, word.fontName),
                fontSize = 24.sp,
                color = Color(0xFF2C5E43), // Elegant Quranic Green
                textAlign = TextAlign.Center
            )
        }
    }
}

@Composable
fun MushafLineRenderer(
    line: QcfLine,
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
            val backgroundColor = if (isHighlighted) Color(0x3D2C5E43) else Color.Transparent
            
            Box(
                modifier = Modifier
                    .background(backgroundColor, shape = RoundedCornerShape(4.dp))
                    .clickable(
                        enabled = word.verseKey != null,
                        onClick = {
                            word.verseKey?.let { onWordTapped(it) }
                        },
                        interactionSource = remember { MutableInteractionSource() },
                        indication = null // No default ripple to keep text neat
                    )
                    .padding(horizontal = 2.dp, vertical = 2.dp)
            ) {
                val glyph = String(Character.toChars(word.code))
                // Fixed ink on the cream page (the page is always light, regardless of
                // app theme). Ayah-end markers get the green accent like the header.
                // Pure black + larger size: the QCF strokes are thin, so this is what
                // gives readable contrast on the cream background.
                val inkColor = if (word.type == "end") Color(0xFF2C5E43) else Color(0xFF000000)
                Text(
                    text = glyph,
                    fontFamily = getFontFamily(context, word.fontName),
                    fontSize = 28.sp,
                    color = inkColor,
                    textAlign = TextAlign.Center
                )
            }
        }
    }
}
