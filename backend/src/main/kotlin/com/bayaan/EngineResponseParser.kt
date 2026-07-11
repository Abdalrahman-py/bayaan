package com.bayaan

import com.bayaan.MistakeInput
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.doubleOrNull
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

// allCorrect + mistakes stay componentN-destructurable (component1/2) so existing
// `val (allCorrect, mistakes) = parse(...)` callers keep working; sifatErrors is component3.
data class ParsedEngineResponse(
    val allCorrect: Boolean,
    val mistakes: List<MistakeInput>,
    val sifatErrors: List<SifatMistakeInput>,
)

object EngineResponseParser {

    fun parse(body: String): ParsedEngineResponse {
        val json = Json.parseToJsonElement(body).jsonObject
        val allCorrect = json["all_correct"]?.jsonPrimitive?.booleanOrNull ?: true
        val mistakes = json["errors"]?.jsonArray?.mapNotNull { el ->
            try {
                val obj = el.jsonObject
                val pos = obj["uthmani_pos"]!!.jsonArray
                val ruleName = obj["ref_tajweed_rules"]?.jsonArray
                    ?.firstOrNull()?.jsonObject?.get("name")?.jsonObject
                MistakeInput(
                    charStart = pos[0].jsonPrimitive.content.toInt(),
                    charEnd = pos[1].jsonPrimitive.content.toInt(),
                    errorType = obj["error_type"]!!.jsonPrimitive.content,
                    speechErrorType = obj["speech_error_type"].asString(),
                    ruleNameEn = ruleName?.get("en").asString(),
                    ruleNameAr = ruleName?.get("ar").asString(),
                    expectedLen = obj["expected_len"]?.jsonPrimitive?.intOrNull,
                    predictedLen = obj["predicted_len"]?.jsonPrimitive?.intOrNull,
                )
            } catch (_: Exception) { null }
        } ?: emptyList()
        val sifatErrors = json["sifat_errors"]?.jsonArray?.mapNotNull { el ->
            try {
                val obj = el.jsonObject
                SifatMistakeInput(
                    phonemesGroup = obj["phonemes_group"]!!.jsonPrimitive.content,
                    attribute = obj["attribute"]!!.jsonPrimitive.content,
                    predicted = obj["predicted"]!!.jsonPrimitive.content,
                    expected = obj["expected"]!!.jsonPrimitive.content,
                    confidence = obj["confidence"]?.jsonPrimitive?.doubleOrNull,
                )
            } catch (_: Exception) { null }
        } ?: emptyList()
        return ParsedEngineResponse(allCorrect, mistakes, sifatErrors)
    }

    private fun JsonElement?.asString(): String? =
        takeIf { it != null && it !is JsonNull }?.jsonPrimitive?.content
}
