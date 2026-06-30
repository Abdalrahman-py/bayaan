package com.bayaan

import com.bayaan.MistakeInput
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

object EngineResponseParser {

    fun parse(body: String): Pair<Boolean, List<MistakeInput>> {
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
        return allCorrect to mistakes
    }

    private fun JsonElement?.asString(): String? =
        takeIf { it != null && it !is JsonNull }?.jsonPrimitive?.content
}
