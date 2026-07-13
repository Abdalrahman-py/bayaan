package com.bayaan.data

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

@Serializable
data class CurriculumLesson(
    val lesson_id: String,
    val title_en: String,
    val title_ar: String,
    val is_checkpoint: Boolean
)

@Serializable
data class CurriculumUnit(
    val unit_id: String,
    val track: String,
    val title_en: String,
    val title_ar: String,
    val lessons: List<CurriculumLesson>
)

@Serializable
data class CurriculumFile(
    val version: Int,
    val units: List<CurriculumUnit>
)

// ponytail: curriculum.json is copied from repo-root content/ into resources/ by hand today.
// M1's build_content.py should copy it as a build step once that pipeline exists.
object Curriculum {
    // Lenient: the backend reads a subset of the content-pack schema, so unknown keys
    // (e.g. content/'s "_note", or future per-lesson fields) are ignored, not fatal.
    private val json = Json { ignoreUnknownKeys = true }

    val file: CurriculumFile by lazy {
        val text = requireNotNull(javaClass.getResourceAsStream("/curriculum.json")) {
            "curriculum.json missing from backend resources"
        }.bufferedReader().readText()
        json.decodeFromString(text)
    }

    val lessonOrder: List<String> by lazy {
        file.units.flatMap { it.lessons.map(CurriculumLesson::lesson_id) }
    }
}
