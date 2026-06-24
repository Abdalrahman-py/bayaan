package com.bayaan

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
import io.ktor.server.application.Application
import io.ktor.server.request.receiveMultipart
import io.ktor.server.response.respondText
import io.ktor.server.routing.routing
import io.ktor.server.routing.get
import io.ktor.server.routing.post
import io.ktor.utils.io.readRemaining
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.io.readByteArray
import java.io.File

// The quran-muaalem engine, deployed on Modal (see ../ml/muaalem_modal.py).
// Public endpoint, not a secret — overridable via env for local/staging swaps.
private val MUAALEM_URL = System.getenv("MUAALEM_URL")
    ?: "https://abdalrahman-py--bayaan-muaalem-muaalem-correct.modal.run"

// One client for the app's lifetime. 60s request timeout so the engine's
// ~24s cold start doesn't trip CIO's 15s default.
private val engineClient = HttpClient(CIO) {
    engine { requestTimeout = 60_000 }
}

private fun err(code: String, msg: String) = """{"error":"$code","message":"$msg"}"""

fun Application.configureRouting() {
    routing {
        get("/health") {
            call.respondText("""{"status":"ok"}""", ContentType.Application.Json)
        }

        // Demo proxy: audio (any format ffmpeg reads) + sura/aya  ->  16kHz WAV
        // -> muaalem engine -> structured mistake JSON, passed straight through.
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
                part.dispose()
            }

            val raw = audio
            if (raw == null || raw.isEmpty()) {
                return@post call.respondText(
                    err("bad_request", "missing audio field"),
                    ContentType.Application.Json, HttpStatusCode.BadRequest,
                )
            }
            // ponytail: post-read 10MB cap. A multi-GB upload still buffers in memory
            // before this check — true fix is a streaming limit in receiveMultipart.
            // Acceptable while the app is the only client; revisit if exposed publicly.
            if (raw.size > 10 * 1024 * 1024) {
                return@post call.respondText(
                    err("payload_too_large", "audio exceeds 10MB"),
                    ContentType.Application.Json, HttpStatusCode.PayloadTooLarge,
                )
            }

            val wav = try {
                convertToWav(raw)
            } catch (e: Exception) {
                return@post call.respondText(
                    err("unprocessable_audio", "could not decode audio"),
                    ContentType.Application.Json, HttpStatusCode.UnprocessableEntity,
                )
            }

            val resp = try {
                engineClient.post("$MUAALEM_URL?sura=$sura&aya=$aya") {
                    setBody(MultiPartFormDataContent(formData {
                        append("audio", wav, Headers.build {
                            append(HttpHeaders.ContentDisposition, "filename=\"recording.wav\"")
                        })
                    }))
                }
            } catch (e: Exception) {
                // Engine unreachable or timed out (e.g. cold start > 60s).
                return@post call.respondText(
                    err("ml_unavailable", "recitation engine did not respond"),
                    ContentType.Application.Json, HttpStatusCode.ServiceUnavailable,
                )
            }
            // The engine always returns JSON (success or its own error envelope),
            // so piping body + status through is safe.
            call.respondText(resp.bodyAsText(), ContentType.Application.Json, resp.status)
        }
    }
}

/**
 * Convert any ffmpeg-readable audio (Android sends M4A/AAC) to 16kHz mono WAV.
 * Input goes via a temp file and only stdout is piped, so there's no
 * stdin/stdout deadlock. Throws if ffmpeg exits non-zero.
 */
private suspend fun convertToWav(input: ByteArray): ByteArray = withContext(Dispatchers.IO) {
    val tmp = File.createTempFile("bayaan-rec", ".bin")
    try {
        tmp.writeBytes(input)
        val process = ProcessBuilder(
            "ffmpeg", "-i", tmp.absolutePath,
            "-ar", "16000", "-ac", "1", "-f", "wav",
            "-v", "error", "pipe:1",
        ).redirectError(ProcessBuilder.Redirect.DISCARD).start()

        val wav = process.inputStream.readBytes()
        if (process.waitFor() != 0 || wav.isEmpty()) {
            throw IllegalStateException("ffmpeg exit ${process.exitValue()}")
        }
        wav
    } finally {
        tmp.delete()
    }
}
