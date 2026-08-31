package com.bayaan

import io.ktor.client.HttpClient
import io.ktor.client.engine.cio.CIO
import io.ktor.client.request.forms.MultiPartFormDataContent
import io.ktor.client.request.forms.formData
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.client.statement.bodyAsText
import io.ktor.http.Headers
import io.ktor.http.HttpHeaders
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.slf4j.LoggerFactory

private val log = LoggerFactory.getLogger("com.bayaan.SpeechGrade")

// Path-A grade-text endpoint on the same Modal app as /correct. Method name
// grade_text → Modal public URL ...-muaalem-grade-text.modal.run.
// Overridable for local modal serve / staging.
private val MUAALEM_GRADE_TEXT_URL = System.getenv("MUAALEM_GRADE_TEXT_URL")
    ?: "https://abdalrahman-py--bayaan-muaalem-muaalem-grade-text.modal.run"

private val engineClient = HttpClient(CIO) {
    engine { requestTimeout = 60_000 }
}

data class GradeEngineResponse(val statusCode: Int, val body: String)

typealias GradeTextEngineAdapter = suspend (audio: ByteArray, referenceText: String) -> GradeEngineResponse

val defaultGradeTextAdapter: GradeTextEngineAdapter = { audio, referenceText ->
    val resp = engineClient.post(MUAALEM_GRADE_TEXT_URL) {
        setBody(MultiPartFormDataContent(formData {
            append("audio", audio, Headers.build {
                append(HttpHeaders.ContentDisposition, "filename=\"recording.wav\"")
            })
            append("reference_text", referenceText)
        }))
    }
    GradeEngineResponse(resp.status.value, resp.bodyAsText())
}

@Serializable
data class PhonemeIssue(
    val uthmani_pos: List<Int>,
    val issue_type: String,
    val expected_phoneme: String,
    val predicted_phoneme: String,
    val feedback_key: String,
)

@Serializable
data class SpeechGradeResponse(
    val verdict: String,
    val score: Double,
    val phoneme_issues: List<PhonemeIssue>,
    val item_ref: String,
)

sealed class SpeechGradeResult {
    data class Success(val body: SpeechGradeResponse) : SpeechGradeResult()
    data class EngineError(val statusCode: Int, val body: String) : SpeechGradeResult()
    object EngineFailed : SpeechGradeResult()
}

/**
 * M3 speech grading (docs/api-spec.md POST /speech/grade, decisions/grading-tiers.md).
 *
 * Forwards audio + arbitrary Uthmani reference to Modal /grade-text, then normalizes
 * the raw phoneme/sifat diff into {verdict, score, phoneme_issues[], item_ref} with the
 * tolerance policy: drop edge inserts, single minor → retry, decode crash → retry.
 */
class SpeechGrade(private val engine: GradeTextEngineAdapter = defaultGradeTextAdapter) {

    suspend fun grade(
        audio: ByteArray,
        tier: Int,
        referenceText: String,
        itemRef: String,
    ): SpeechGradeResult {
        // Tier is currently informational — Path A grades both short echoes (1) and
        // short Quranic phrases (2) against reference_text. Full-ayah /audio/analyze
        // remains the Tajweed-track path.
        if (tier !in 1..2) {
            return SpeechGradeResult.EngineError(
                400,
                """{"error":"bad_request","message":"tier must be 1 or 2"}""",
            )
        }
        val text = referenceText.trim()
        if (text.isEmpty()) {
            return SpeechGradeResult.EngineError(
                400,
                """{"error":"bad_request","message":"missing reference_text"}""",
            )
        }

        val engineResp = try {
            engine(audio, text)
        } catch (e: Exception) {
            log.error("grade-text engine call failed: ${e.message}")
            return SpeechGradeResult.EngineFailed
        }

        // Decode crash on short clips → verdict retry (never 500). Modal returns 422
        // with error=decode_failed for multilevel_greedy_decode RuntimeError.
        if (engineResp.statusCode == 422 && engineResp.body.contains("decode_failed")) {
            return SpeechGradeResult.Success(
                SpeechGradeResponse(
                    verdict = "retry",
                    score = 0.0,
                    phoneme_issues = emptyList(),
                    item_ref = itemRef,
                ),
            )
        }

        if (engineResp.statusCode !in 200..299) {
            return SpeechGradeResult.EngineError(engineResp.statusCode, engineResp.body)
        }

        return try {
            SpeechGradeResult.Success(SpeechGradeNormalizer.normalize(engineResp.body, text, itemRef))
        } catch (e: Exception) {
            log.error("grade-text response unparseable: ${e.message}")
            SpeechGradeResult.EngineFailed
        }
    }
}

/**
 * Turns Muaalem's raw error/sifat JSON into the frozen /speech/grade client contract.
 * Pure / unit-testable — no I/O.
 */
object SpeechGradeNormalizer {
    private val json = Json { ignoreUnknownKeys = true }

    // Minimal-pair confusions measured in Spike S1 (docs/decisions/grading-tiers.md).
    private val PAIR_FEEDBACK = listOf(
        setOf('ص', 'س') to "swap_sad_seen",
        setOf('ط', 'ت') to "swap_taa_ta",
        setOf('ح', 'ه') to "swap_haa_ha",
        setOf('ق', 'ك') to "swap_qaf_kaf",
    )

    fun normalize(engineBody: String, referenceText: String, itemRef: String): SpeechGradeResponse {
        val root = json.parseToJsonElement(engineBody).jsonObject
        val rawErrors = root["errors"]?.jsonArray ?: JsonArray(emptyList())
        val sifatErrors = root["sifat_errors"]?.jsonArray ?: JsonArray(emptyList())

        val issues = mutableListOf<PhonemeIssue>()
        for (el in rawErrors) {
            val obj = el.jsonObject
            val issue = mapPhonemeError(obj, referenceText) ?: continue
            issues += issue
        }
        for (el in sifatErrors) {
            mapSifatError(el.jsonObject)?.let { issues += it }
        }

        val verdict = when {
            issues.isEmpty() -> "pass"
            issues.size == 1 && !isMajor(issues[0]) -> "retry"
            else -> "fail"
        }
        val score = when (verdict) {
            "pass" -> 1.0
            "retry" -> 0.62
            else -> (1.0 - 0.25 * issues.size).coerceIn(0.0, 0.45)
        }
        return SpeechGradeResponse(
            verdict = verdict,
            score = score,
            phoneme_issues = issues,
            item_ref = itemRef,
        )
    }

    private fun isMajor(issue: PhonemeIssue): Boolean =
        issue.issue_type == "length_short" || issue.issue_type == "length_long"

    private fun mapPhonemeError(obj: JsonObject, referenceText: String): PhonemeIssue? {
        val speechType = obj.str("speech_error_type") ?: return null
        val pos = obj["uthmani_pos"]?.jsonArray?.mapNotNull { it.jsonPrimitive.intOrNull }
            ?: return null
        if (pos.size < 2) return null
        val start = pos[0]
        val end = pos[1]

        // Edge inserts (breath/noise at clip boundaries) — drop before scoring.
        if (speechType == "insert" && isEdgeInsert(start, end, referenceText.length)) {
            return null
        }

        val expected = obj.str("expected_ph") ?: obj.str("expected_phoneme") ?: ""
        // Upstream misspells the field as preditected_ph (see Spike S1 raw output).
        val predicted = obj.str("preditected_ph")
            ?: obj.str("predicted_ph")
            ?: obj.str("predicted_phoneme")
            ?: ""

        val expectedLen = obj["expected_len"]?.jsonPrimitive?.intOrNull
        val predictedLen = obj["predicted_len"]?.jsonPrimitive?.intOrNull

        val (issueType, feedbackKey) = classify(expected, predicted, speechType, expectedLen, predictedLen)
        return PhonemeIssue(
            uthmani_pos = listOf(start, end),
            issue_type = issueType,
            expected_phoneme = expected,
            predicted_phoneme = predicted,
            feedback_key = feedbackKey,
        )
    }

    private fun mapSifatError(obj: JsonObject): PhonemeIssue? {
        val attribute = obj.str("attribute") ?: return null
        val expected = obj.str("expected") ?: return null
        val predicted = obj.str("predicted") ?: return null
        if (predicted.trim().lowercase() in listOf("[pad]", "<pad>", "pad", "none", "")) {
            return null
        }
        val group = obj.str("phonemes_group") ?: ""

        // Only surface the sifat heads that map cleanly to client feedback keys.
        val (issueType, feedbackKey) = when (attribute) {
            "qalqla" -> "missing_qalqalah" to "missing_qalqalah"
            "ghonna" -> "missing_ghunnah" to "missing_ghunnah"
            "tafkheem_or_taqeeq" -> {
                // light lam specifically is messily signalled in Tier 1 — flag only.
                if (group.contains('ل') || expected.contains("moraqaq") || predicted.contains("moraqaq")) {
                    "consonant_swap" to "light_lam"
                } else {
                    "consonant_swap" to "swap_consonant_other"
                }
            }
            else -> return null
        }
        return PhonemeIssue(
            uthmani_pos = listOf(0, group.length.coerceAtLeast(1)),
            issue_type = issueType,
            expected_phoneme = expected,
            predicted_phoneme = predicted,
            feedback_key = feedbackKey,
        )
    }

    private fun classify(
        expected: String,
        predicted: String,
        speechType: String,
        expectedLen: Int?,
        predictedLen: Int?,
    ): Pair<String, String> {
        if (expectedLen != null && predictedLen != null && expectedLen != predictedLen) {
            return if (predictedLen < expectedLen) {
                "length_short" to "length_short"
            } else {
                "length_long" to "length_long"
            }
        }

        // Length cues without expected_len: missing madd letters in the prediction.
        val expHasMadd = expected.any { it in "اويۦٰۥ" } || expected.contains("اا")
        val predHasMadd = predicted.any { it in "اويۦٰۥ" } || predicted.contains("اا")
        if (expHasMadd && !predHasMadd) return "length_short" to "length_short"
        if (!expHasMadd && predHasMadd) return "length_long" to "length_long"

        val pairKey = pairFeedback(expected, predicted)
        if (pairKey != null) return "consonant_swap" to pairKey

        if (speechType == "replace" || speechType == "delete" || speechType == "insert") {
            val expCons = stripTashkeel(expected)
            val predCons = stripTashkeel(predicted)
            if (expCons != predCons && expCons.isNotEmpty() && predCons.isNotEmpty()) {
                return "consonant_swap" to "swap_consonant_other"
            }
            if (expCons == predCons && expected != predicted) {
                return "vowel_swap" to "vowel_mismatch"
            }
        }

        // tashkeel-labelled errors are vowel changes.
        return "vowel_swap" to "vowel_mismatch"
    }

    private fun pairFeedback(expected: String, predicted: String): String? {
        val exp = expected.toSet()
        val pred = predicted.toSet()
        for ((pair, key) in PAIR_FEEDBACK) {
            if (pair.any { it in exp } && pair.any { it in pred } && exp != pred) {
                return key
            }
        }
        return null
    }

    private fun isEdgeInsert(start: Int, end: Int, refLen: Int): Boolean {
        if (refLen <= 0) return true
        if (start <= 0) return true
        if (start >= refLen) return true
        if (end >= refLen && start == end) return true
        return false
    }

    private fun stripTashkeel(s: String): String =
        s.filterNot { it in "ًٌٍَُِّْٰٕٓٔ" }

    private fun JsonObject.str(key: String): String? {
        val el = this[key] ?: return null
        if (el is JsonNull) return null
        return el.jsonPrimitive.content
    }
}
