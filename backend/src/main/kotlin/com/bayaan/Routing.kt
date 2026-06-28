package com.bayaan

import com.bayaan.data.repositories.MistakeInput
import com.bayaan.data.repositories.MistakeRepository
import com.bayaan.data.repositories.SessionRepository
import io.ktor.client.HttpClient
import io.ktor.client.engine.cio.CIO
import io.ktor.client.request.forms.MultiPartFormDataContent
import io.ktor.client.request.forms.formData
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.client.statement.bodyAsText
import io.ktor.http.ContentType
import io.ktor.http.Headers
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.content.PartData
import io.ktor.http.content.forEachPart
import io.ktor.server.auth.jwt.JWTPrincipal
import io.ktor.server.auth.principal
import io.ktor.server.request.receiveMultipart
import io.ktor.server.response.respondText
import io.ktor.server.routing.Route
import io.ktor.server.routing.get
import io.ktor.server.routing.post
import io.ktor.utils.io.readRemaining
import kotlinx.io.readByteArray
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.slf4j.LoggerFactory
import java.util.UUID

private val log = LoggerFactory.getLogger("com.bayaan.Routing")

// The quran-muaalem engine deployed on Modal. Overridable via env for local/staging swaps.
private val MUAALEM_URL = System.getenv("MUAALEM_URL")
    ?: "https://abdalrahman-py--bayaan-muaalem-muaalem-correct.modal.run"

// One client for the app's lifetime. 60s timeout covers the engine's cold-start.
private val engineClient = HttpClient(CIO) {
    engine { requestTimeout = 60_000 }
}

private fun err(code: String, msg: String) = """{"error":"$code","message":"$msg"}"""

fun Route.healthRoute() {
    get("/health") {
        call.respondText("""{"status":"ok"}""", ContentType.Application.Json)
    }
}

// Receives 16kHz WAV from Android, forwards to Muaalem, persists session + mistakes.
fun Route.analyzeRoute() {
    post("/audio/analyze") {
        var audio: ByteArray? = null
        var sura = 1
        var aya = 1
        call.receiveMultipart().forEachPart { part ->
            when (part) {
                is PartData.FileItem ->
                    if (part.name == "audio") audio = part.provider().readRemaining().readByteArray()
                is PartData.FormItem -> when (part.name) {
                    "sura" -> part.value.toIntOrNull()?.let { sura = it }
                    "aya" -> part.value.toIntOrNull()?.let { aya = it }
                }
                else -> {}
            }
            part.release()
        }

        val raw = audio
        if (raw == null || raw.isEmpty()) {
            return@post call.respondText(
                err("bad_request", "missing audio field"),
                ContentType.Application.Json, HttpStatusCode.BadRequest,
            )
        }
        // ponytail: post-read 10MB cap. A multi-GB upload still buffers in memory before
        // this check. True fix is a streaming limit in receiveMultipart; acceptable while
        // the app is the only client.
        if (raw.size > 10 * 1024 * 1024) {
            return@post call.respondText(
                err("payload_too_large", "audio exceeds 10MB"),
                ContentType.Application.Json, HttpStatusCode.PayloadTooLarge,
            )
        }

        val resp = try {
            engineClient.post("$MUAALEM_URL?sura=$sura&aya=$aya") {
                setBody(MultiPartFormDataContent(formData {
                    append("audio", raw, Headers.build {
                        append(HttpHeaders.ContentDisposition, "filename=\"recording.wav\"")
                    })
                }))
            }
        } catch (_: Exception) {
            return@post call.respondText(
                err("ml_unavailable", "recitation engine did not respond"),
                ContentType.Application.Json, HttpStatusCode.ServiceUnavailable,
            )
        }

        val bodyText = resp.bodyAsText()

        if (resp.status.value in 200..299) {
            try {
                val userId = UUID.fromString(call.principal<JWTPrincipal>()!!.payload.subject)
                val (allCorrect, mistakes) = parseEngineResponse(bodyText)
                val sessionId = SessionRepository.insert(userId, sura, aya, allCorrect)
                MistakeRepository.insertBatch(sessionId, mistakes)
            } catch (e: Exception) {
                log.error("Persistence failed (sura=$sura aya=$aya): ${e.message}")
            }
        }

        call.respondText(bodyText, ContentType.Application.Json, resp.status)
    }
}

private fun parseEngineResponse(body: String): Pair<Boolean, List<MistakeInput>> {
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
