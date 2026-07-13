package com.bayaan.ui.lesson

import android.util.Log
import com.bayaan.BuildConfig
import io.ktor.client.HttpClient
import io.ktor.client.engine.cio.CIO
import io.ktor.client.request.HttpRequestBuilder
import io.ktor.client.request.forms.MultiPartFormDataContent
import io.ktor.client.request.forms.formData
import io.ktor.client.request.get
import io.ktor.client.request.header
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.client.statement.bodyAsText
import io.ktor.http.ContentType
import io.ktor.http.Headers
import io.ktor.http.HttpHeaders
import io.ktor.http.contentType
import io.ktor.http.isSuccess
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject

class LearnApi(private val tokenProvider: () -> String?) {
    private val TAG = "LearnApi"
    private val baseUrl = BuildConfig.BACKEND_URL

    private val client = HttpClient(CIO) {
        engine { requestTimeout = 60_000 }
    }

    data class Header(
        val arabicLevel: Int,
        val xp: Int,
        val streak: Int,
        val dailyGoalMinutes: Int,
        val reviewsDue: Int,
    )

    data class LessonNode(
        val lessonId: String,
        val titleEn: String,
        val titleAr: String,
        val isCheckpoint: Boolean,
        val status: String,
        val bestScore: Double,
        val attempts: Int,
    )

    data class UnitNode(
        val unitId: String,
        val track: String,
        val titleEn: String,
        val titleAr: String,
        val lessons: List<LessonNode>,
    )

    data class LearnPath(val header: Header, val units: List<UnitNode>)

    data class ItemResult(val itemRef: String, val correct: Boolean, val firstTry: Boolean)

    data class CompleteResult(val header: Header)

    data class ReviewDue(val reviewId: String, val itemRef: String, val dueOn: String)

    data class ReviewResult(val nextDueOn: String, val reviewsDue: Int)

    data class SpeechGradeVerdict(
        val verdict: String,
        val score: Double,
        val phonemeIssues: List<Map<String, Any>>,
        val itemRef: String,
    )

    data class ProgressSummary(
        val totalSessions: Long,
        val perfectSessions: Long,
        val overallAccuracy: Double,
        val totalMistakes: Long,
        val mistakeBreakdown: Map<String, Long>,
        val sifatBreakdown: Map<String, Long>
    )

    suspend fun learnPath(): LearnPath? = guard {
        val resp = client.get("$baseUrl/learn/path") { addAuth() }
        if (!resp.status.isSuccess()) return@guard null
        parseLearnPath(resp.bodyAsText())
    }

    suspend fun complete(lessonId: String, score: Double, isCheckpoint: Boolean, items: List<ItemResult>): CompleteResult? = guard {
        val body = JSONObject().apply {
            put("lesson_id", lessonId)
            put("score", score)
            put("is_checkpoint", isCheckpoint)
            put("item_results", JSONArray().apply {
                items.forEach { put(JSONObject().apply {
                    put("item_ref", it.itemRef)
                    put("correct", it.correct)
                    put("first_try", it.firstTry)
                })}
            })
        }
        val resp = client.post("$baseUrl/learn/complete") {
            addAuth()
            contentType(ContentType.Application.Json)
            setBody(body.toString())
        }
        if (!resp.status.isSuccess()) return@guard null
        val j = JSONObject(resp.bodyAsText()).getJSONObject("header")
        CompleteResult(parseHeader(j))
    }

    suspend fun reviewsDue(limit: Int = 20): List<ReviewDue> = guard {
        val resp = client.get("$baseUrl/learn/reviews?limit=$limit") { addAuth() }
        if (!resp.status.isSuccess()) return@guard emptyList()
        val arr = JSONObject(resp.bodyAsText()).getJSONArray("reviews")
        val result = mutableListOf<ReviewDue>()
        for (i in 0 until arr.length()) {
            val j = arr.getJSONObject(i)
            result.add(ReviewDue(j.getString("review_id"), j.getString("item_ref"), j.getString("due_on")))
        }
        result
    } ?: emptyList()

    suspend fun reviewResult(reviewId: String, correct: Boolean): ReviewResult? = guard {
        val body = JSONObject().apply { put("correct", correct) }
        val resp = client.post("$baseUrl/learn/reviews/$reviewId/result") {
            addAuth()
            contentType(ContentType.Application.Json)
            setBody(body.toString())
        }
        if (!resp.status.isSuccess()) return@guard null
        val j = JSONObject(resp.bodyAsText())
        ReviewResult(j.getString("next_due_on"), j.getInt("reviews_due"))
    }

    suspend fun gradeSpeech(audio: ByteArray, tier: Int, referenceText: String, itemRef: String): SpeechGradeVerdict? = guard {
        val resp = client.post("$baseUrl/speech/grade") {
            addAuth()
            setBody(MultiPartFormDataContent(formData {
                append("audio", audio, Headers.build {
                    append(HttpHeaders.ContentDisposition, "filename=\"echo.wav\"")
                })
                append("tier", tier.toString())
                append("reference_text", referenceText)
                append("item_ref", itemRef)
            }))
        }
        if (!resp.status.isSuccess()) return@guard null
        val j = JSONObject(resp.bodyAsText())
        val issues = mutableListOf<Map<String, Any>>()
        j.optJSONArray("phoneme_issues")?.let { arr ->
            for (i in 0 until arr.length()) {
                val obj = arr.getJSONObject(i)
                issues.add(mapOf(
                    "uthmani_pos" to listOf(obj.getJSONArray("uthmani_pos").getInt(0), obj.getJSONArray("uthmani_pos").getInt(1)),
                    "issue_type" to obj.getString("issue_type"),
                    "feedback_key" to obj.getString("feedback_key"),
                ))
            }
        }
        SpeechGradeVerdict(j.getString("verdict"), j.getDouble("score"), issues, j.getString("item_ref"))
    }

    suspend fun progress(): ProgressSummary? = guard {
        val resp = client.get("$baseUrl/progress") { addAuth() }
        if (!resp.status.isSuccess()) return@guard null
        val j = JSONObject(resp.bodyAsText())
        val mistakeBreakdown = mutableMapOf<String, Long>()
        j.optJSONObject("mistake_breakdown")?.let { obj ->
            obj.keys().forEach { key -> mistakeBreakdown[key] = obj.getLong(key) }
        }
        val sifatBreakdown = mutableMapOf<String, Long>()
        j.optJSONObject("sifat_breakdown")?.let { obj ->
            obj.keys().forEach { key -> sifatBreakdown[key] = obj.getLong(key) }
        }
        ProgressSummary(
            totalSessions = j.getLong("total_sessions"),
            perfectSessions = j.getLong("perfect_sessions"),
            overallAccuracy = j.getDouble("overall_accuracy"),
            totalMistakes = j.getLong("total_mistakes"),
            mistakeBreakdown = mistakeBreakdown,
            sifatBreakdown = sifatBreakdown
        )
    }

    fun close() = client.close()

    private fun parseLearnPath(raw: String): LearnPath {
        val root = JSONObject(raw)
        val header = parseHeader(root.getJSONObject("header"))
        val units = mutableListOf<UnitNode>()
        root.getJSONArray("units").let { arr ->
            for (i in 0 until arr.length()) {
                val u = arr.getJSONObject(i)
                val lessons = mutableListOf<LessonNode>()
                u.getJSONArray("lessons").let { larr ->
                    for (li in 0 until larr.length()) {
                        val l = larr.getJSONObject(li)
                        lessons.add(LessonNode(
                            l.getString("lesson_id"), l.getString("title_en"), l.getString("title_ar"),
                            l.getBoolean("is_checkpoint"), l.getString("status"),
                            l.getDouble("best_score"), l.getInt("attempts"),
                        ))
                    }
                }
                units.add(UnitNode(u.getString("unit_id"), u.getString("track"), u.getString("title_en"), u.getString("title_ar"), lessons))
            }
        }
        return LearnPath(header, units)
    }

    private fun parseHeader(j: JSONObject) = Header(
        j.getInt("arabic_level"), j.getInt("xp"), j.getInt("streak_count"),
        j.optInt("daily_goal_minutes", 10), j.optInt("reviews_due", 0),
    )

    private suspend fun <T> guard(block: suspend () -> T): T? = withContext(Dispatchers.IO) {
        try { block() } catch (e: Exception) {
            Log.w(TAG, "learn api error: ${e.message}")
            null
        }
    }

    private suspend fun HttpRequestBuilder.addAuth() {
        val token = tokenProvider()
        if (token != null) header(HttpHeaders.Authorization, "Bearer $token")
    }
}
