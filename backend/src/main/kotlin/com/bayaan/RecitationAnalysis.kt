package com.bayaan

import com.bayaan.data.repositories.MistakeRepository
import com.bayaan.data.repositories.SessionRepository
import io.ktor.client.HttpClient
import io.ktor.client.engine.cio.CIO
import io.ktor.client.request.forms.MultiPartFormDataContent
import io.ktor.client.request.forms.formData
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.client.statement.bodyAsText
import io.ktor.http.Headers
import io.ktor.http.HttpHeaders
import org.slf4j.LoggerFactory
import java.util.UUID

private val log = LoggerFactory.getLogger("com.bayaan.RecitationAnalysis")

data class EngineResponse(val statusCode: Int, val body: String)
typealias EngineAdapter = suspend (audio: ByteArray, sura: Int, aya: Int) -> EngineResponse

// The quran-muaalem engine deployed on Modal. Overridable via env for local/staging swaps.
private val MUAALEM_URL = System.getenv("MUAALEM_URL")
    ?: "https://abdalrahman-py--bayaan-muaalem-muaalem-correct.modal.run"

// One client for the app's lifetime. 60s timeout covers the engine's cold-start.
private val engineClient = HttpClient(CIO) {
    engine { requestTimeout = 60_000 }
}

val defaultEngineAdapter: EngineAdapter = { audio, sura, aya ->
    val resp = engineClient.post("$MUAALEM_URL?sura=$sura&aya=$aya") {
        setBody(MultiPartFormDataContent(formData {
            append("audio", audio, Headers.build {
                append(HttpHeaders.ContentDisposition, "filename=\"recording.wav\"")
            })
        }))
    }
    EngineResponse(resp.status.value, resp.bodyAsText())
}

sealed class AnalysisResult {
    data class Success(val body: String) : AnalysisResult()
    data class EngineError(val statusCode: Int, val body: String) : AnalysisResult()
    object EngineFailed : AnalysisResult()
    object PersistenceFailed : AnalysisResult()
}

class RecitationAnalysis(private val engine: EngineAdapter = defaultEngineAdapter) {

    suspend fun analyze(audio: ByteArray, sura: Int, aya: Int, userId: UUID): AnalysisResult {
        val engineResp = try {
            engine(audio, sura, aya)
        } catch (_: Exception) {
            return AnalysisResult.EngineFailed
        }

        if (engineResp.statusCode !in 200..299) {
            return AnalysisResult.EngineError(engineResp.statusCode, engineResp.body)
        }

        return try {
            val (allCorrect, mistakes) = EngineResponseParser.parse(engineResp.body)
            val sessionId = SessionRepository.insert(userId, sura, aya, allCorrect)
            MistakeRepository.insertBatch(sessionId, mistakes)
            AnalysisResult.Success(engineResp.body)
        } catch (e: Exception) {
            log.error("Persistence failed (sura=$sura aya=$aya): ${e.message}")
            AnalysisResult.PersistenceFailed
        }
    }
}
