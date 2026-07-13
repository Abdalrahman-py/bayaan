package com.bayaan.routes

import com.bayaan.ErrorResponse
import com.bayaan.SpeechGrade
import com.bayaan.SpeechGradeResult
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
import io.ktor.http.ContentType

/**
 * POST /speech/grade — M3 Path A echo grading (docs/api-spec.md).
 *
 * multipart: audio + tier + reference_text + item_ref → {verdict, score, phoneme_issues, item_ref}.
 * Auth is required by the surrounding authenticate("auth-jwt") block in Application.kt.
 * Does NOT persist the clip (privacy §12) — lesson_attempts gets the outcome via
 * /learn/complete later, not here.
 */
fun Route.speechGradeRoute(grade: SpeechGrade = SpeechGrade()) {
    post("/speech/grade") {
        var audio: ByteArray? = null
        var tier = 1
        var referenceText = ""
        var itemRef = ""

        call.receiveMultipart().forEachPart { part ->
            when (part) {
                is PartData.FileItem ->
                    if (part.name == "audio") audio = part.provider().readRemaining().readByteArray()
                is PartData.FormItem -> when (part.name) {
                    "tier" -> part.value.toIntOrNull()?.let { tier = it }
                    "reference_text" -> referenceText = part.value
                    "item_ref" -> itemRef = part.value
                }
                else -> {}
            }
            part.release()
        }

        val raw = audio
        if (raw == null || raw.isEmpty()) {
            return@post call.respond(
                HttpStatusCode.BadRequest,
                ErrorResponse("bad_request", "missing audio field"),
            )
        }
        // Lesson clips are ≤4s / small; 2MB is generous while still protecting the host.
        if (raw.size > 2 * 1024 * 1024) {
            return@post call.respond(
                HttpStatusCode.PayloadTooLarge,
                ErrorResponse("payload_too_large", "audio exceeds 2MB"),
            )
        }
        if (referenceText.isBlank()) {
            return@post call.respond(
                HttpStatusCode.BadRequest,
                ErrorResponse("bad_request", "missing reference_text"),
            )
        }
        if (itemRef.isBlank()) {
            return@post call.respond(
                HttpStatusCode.BadRequest,
                ErrorResponse("bad_request", "missing item_ref"),
            )
        }

        when (val result = grade.grade(raw, tier, referenceText, itemRef)) {
            is SpeechGradeResult.Success -> call.respond(result.body)
            is SpeechGradeResult.EngineError ->
                call.respondText(
                    result.body,
                    ContentType.Application.Json,
                    HttpStatusCode.fromValue(result.statusCode),
                )
            SpeechGradeResult.EngineFailed ->
                call.respond(
                    HttpStatusCode.ServiceUnavailable,
                    ErrorResponse("ml_unavailable", "recitation engine did not respond"),
                )
        }
    }
}
