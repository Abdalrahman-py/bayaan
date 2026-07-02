package com.bayaan.ui.mushaf

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
)

data class QcfLine(
    val line: Int,
    val words: List<QcfWord>
)

data class QcfPage(
    val page: Int,
    val fontName: String,
    val lines: List<QcfLine>
)
