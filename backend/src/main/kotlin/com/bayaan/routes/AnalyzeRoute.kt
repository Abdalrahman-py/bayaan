package com.bayaan.routes

import com.bayaan.AnalysisResult
import com.bayaan.ErrorResponse
import com.bayaan.RecitationAnalysis
import com.bayaan.plugins.userId
import io.ktor.http.ContentType
import io.ktor.http.HttpStatusCode
import io.ktor.http.content.PartData
import io.ktor.http.content.forEachPart
import io.ktor.server.request.receiveMultipart
import io.ktor.server.response.respond
import io.ktor.server.response.respondText
import io.ktor.server.routing.Route
import io.ktor.server.routing.post
import io.ktor.utils.io.readRemaining
import kotlinx.io.readByteArray

// Receives 16kHz WAV from Android, forwards to Muaalem, persists session + mistakes.
fun Route.analyzeRoute(analysis: RecitationAnalysis = RecitationAnalysis()) {
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
                    "aya"  -> part.value.toIntOrNull()?.let { aya  = it }
                }
                else -> {}
            }
            part.release()
        }

        val raw = audio
        if (raw == null || raw.isEmpty()) {
            return@post call.respond(HttpStatusCode.BadRequest,
                ErrorResponse("bad_request", "missing audio field"))
        }
        // ponytail: post-read 10MB cap. A multi-GB upload still buffers in memory before
        // this check. True fix is a streaming limit in receiveMultipart; acceptable while
        // the app is the only client.
        if (raw.size > 10 * 1024 * 1024) {
            return@post call.respond(HttpStatusCode.PayloadTooLarge,
                ErrorResponse("payload_too_large", "audio exceeds 10MB"))
        }

        val userId = call.userId()
        when (val result = analysis.analyze(raw, sura, aya, userId)) {
            is AnalysisResult.Success ->
                call.respondText(result.body, ContentType.Application.Json)
            is AnalysisResult.EngineError ->
                call.respondText(result.body, ContentType.Application.Json,
                    HttpStatusCode.fromValue(result.statusCode))
            AnalysisResult.EngineFailed ->
                call.respond(HttpStatusCode.ServiceUnavailable,
                    ErrorResponse("ml_unavailable", "recitation engine did not respond"))
            AnalysisResult.PersistenceFailed ->
                call.respond(HttpStatusCode.InternalServerError,
                    ErrorResponse("persistence_error", "failed to save session"))
        }
    }
}
