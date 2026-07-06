package com.bayaan.ui.mushaf

import androidx.compose.runtime.Immutable

data class QcfChapter(
    val id: Int,
    val nameEn: String,
    val nameAr: String,
    val versesCount: Int,
    val startPage: Int,
    val endPage: Int
)

data class QcfWord(
    val code: Int,          // decimal PUA codepoint, e.g. 61696 == U+F100
    val fontName: String,   // "QCF4_Hafs_01" | "QCF4_QBSML"
    val type: String,       // "word" | "end" | "surah_header" | "bismillah"
    val verseKey: String?,  // "1:1" (null for surah_header)
) {
    // Computed once here instead of at each of the 3 render/measure call sites.
    val glyph: String = String(Character.toChars(code))
}

// @Immutable: List fields would otherwise make Compose treat these as unstable,
// forcing every line/word Composable to recompose whenever anything in the parent
// changes (e.g. tapping a word to select it). QcfRepository builds these once and
// caches them — the lists are never mutated after construction, so the promise holds.
@Immutable
data class QcfLine(
    val line: Int,
    val words: List<QcfWord>
)

@Immutable
data class QcfPage(
    val page: Int,
    val fontName: String,
    val lines: List<QcfLine>
)
