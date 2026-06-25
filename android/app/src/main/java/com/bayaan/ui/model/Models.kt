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

// Demo data
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

/** Looks up the canonical Verse for (sura, aya) from the hardcoded demo data. */
fun verseFor(sura: Int, aya: Int): Verse {
    val (surahNameAr, verses) = if (sura == 98) BAYYINAH else FATIHAH
    val surahNameEn = if (sura == 98) "Al-Bayyinah" else "Al-Fatihah"
    val uthmani = verses.getOrElse(aya - 1) { verses[0] }
    return Verse(sura, aya, surahNameEn, surahNameAr, uthmani)
}

val previewVerse = Verse(
    sura = 1, aya = 2,
    surahNameEn = "Al-Fatihah", surahNameAr = "الفاتحة",
    uthmani = "ٱلْحَمْدُ لِلَّهِ رَبِّ ٱلْعَـٰلَمِينَ",
)

val previewMistakes = listOf(
    Mistake(
        charRange = 10..13, // "لِلَّهِ"
        isTajweed = true,
        kind = "replace",
        ruleNameEn = "Aared Madd",
        ruleNameAr = "المد العارض للسكون",
        expectedLen = 4,
        gotLen = 2
    ),
    Mistake(
        charRange = 0..7, // "ٱلْحَمْدُ"
        isTajweed = false,
        kind = "delete",
        ruleNameEn = null,
        ruleNameAr = null,
        expectedLen = null,
        gotLen = null
    ),
)
