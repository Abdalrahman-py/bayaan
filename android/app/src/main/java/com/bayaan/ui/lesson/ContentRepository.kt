package com.bayaan.ui.lesson

import android.content.Context
import android.util.Log
import com.bayaan.ui.lesson.model.ExerciseItem
import com.bayaan.ui.lesson.model.ExerciseType
import com.bayaan.ui.lesson.model.Lesson
import com.bayaan.ui.lesson.model.TeachSegment
import org.json.JSONObject

/**
 * Loads the bundled content pack from `assets/content/` (emitted by
 * `scripts/build_content.py --out android/app/src/main/assets/content`). Parsing
 * uses org.json — the same dependency-free approach as RecitationViewModel.
 *
 * A lesson is cached after first read. Missing/unparseable content returns null and
 * logs — the caller degrades gracefully rather than crashing (a lesson never renders
 * a hard error if a pack is incomplete).
 */
object ContentRepository {
    private const val TAG = "ContentRepository"
    private val cache = HashMap<String, Lesson?>()

    fun lesson(context: Context, lessonId: String): Lesson? =
        cache.getOrPut(lessonId) { load(context, lessonId) }

    private fun load(context: Context, lessonId: String): Lesson? = try {
        val text = context.assets.open("content/lessons/$lessonId.json")
            .bufferedReader().use { it.readText() }
        parseLesson(JSONObject(text))
    } catch (e: Exception) {
        Log.w(TAG, "lesson $lessonId not in pack: ${e.message}")
        null
    }

    private fun parseLesson(o: JSONObject): Lesson {
        val teachObj = o.optJSONObject("teach")
        val teach = teachObj?.let {
            TeachSegment(
                narrationEn = it.optString("narration_en"),
                glyphs = it.optJSONArray("glyphs").toStringList(),
                focusEn = it.optString("focus_en").ifBlank { null },
                ruleNameEn = it.optString("rule_name_en").ifBlank { null },
                ruleNameAr = it.optString("rule_name_ar").ifBlank { null },
                audioCorrect = it.optString("audio_correct").ifBlank { null },
                audioIncorrect = it.optString("audio_incorrect").ifBlank { null },
            )
        }
        val itemsArr = o.optJSONArray("items")
        val items = (0 until (itemsArr?.length() ?: 0)).mapNotNull { i ->
            parseItem(itemsArr!!.getJSONObject(i))
        }
        return Lesson(
            lessonId = o.getString("lesson_id"),
            unitId = o.optString("unit_id"),
            titleEn = o.optString("title_en"),
            titleAr = o.optString("title_ar"),
            isCheckpoint = o.optBoolean("is_checkpoint"),
            teach = teach,
            items = items,
        )
    }

    private fun parseItem(o: JSONObject): ExerciseItem? {
        val type = runCatching { ExerciseType.valueOf(o.getString("type")) }.getOrNull()
            ?: return null  // unknown/newer type — skip, don't crash an old client
        return ExerciseItem(
            itemRef = o.getString("item_ref"),
            type = type,
            gradingTier = o.optInt("grading_tier"),
            promptAsset = o.optString("prompt_asset").ifBlank { null },
            promptTextAr = o.optString("prompt_text_ar").ifBlank { null },
            answer = o.optString("answer").ifBlank { null },
            options = o.optJSONArray("options").toStringList(),
            referenceText = o.optString("reference_text").ifBlank { null },
        )
    }

    private fun org.json.JSONArray?.toStringList(): List<String> =
        if (this == null) emptyList() else (0 until length()).map { getString(it) }
}
