package com.bayaan.ui.lesson.model

/**
 * On-device shape of the content pack (content/README.md is the contract). Parsed
 * from bundled assets by [com.bayaan.ui.lesson.ContentRepository]. The app renders
 * whatever the frozen schema gives — it does not author or validate content
 * (build_content.py already did that at pack time).
 */
enum class ExerciseType {
    LISTEN_PICK, READ_PICK, DISCRIMINATE, ODD_ONE_OUT, ECHO, READ_ALOUD_SYLLABLE;

    /** Tier-1 spoken items — mic exercises. M2 stubs these (complete-on-tap); M3 grades them. */
    val isSpoken: Boolean get() = this == ECHO || this == READ_ALOUD_SYLLABLE
}

data class TeachSegment(
    val narrationEn: String,
    val glyphs: List<String>,
    val focusEn: String?,
    val ruleNameEn: String? = null,
    val ruleNameAr: String? = null,
    val audioCorrect: String? = null,
    val audioIncorrect: String? = null,
)

data class ExerciseItem(
    val itemRef: String,
    val type: ExerciseType,
    val gradingTier: Int,
    val promptAsset: String? = null,
    val promptTextAr: String? = null,
    val answer: String? = null,
    val options: List<String> = emptyList(),
    val referenceText: String? = null,
)

data class Lesson(
    val lessonId: String,
    val unitId: String,
    val titleEn: String,
    val titleAr: String,
    val isCheckpoint: Boolean,
    val teach: TeachSegment?,
    val items: List<ExerciseItem>,
) {
    val isStub: Boolean get() = items.isEmpty()
}
