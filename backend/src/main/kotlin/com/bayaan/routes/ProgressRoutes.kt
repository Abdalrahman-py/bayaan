package com.bayaan.routes

import com.bayaan.ErrorResponse
import com.bayaan.data.repositories.MistakeRepository
import com.bayaan.data.repositories.SessionRepository
import io.ktor.http.*
import com.bayaan.plugins.userId
import io.ktor.server.auth.*
import io.ktor.server.auth.jwt.*
import io.ktor.server.response.*
import io.ktor.server.routing.*
import kotlinx.serialization.Serializable
import java.util.UUID

@Serializable
data class ProgressSummaryResponse(
    val total_sessions: Long,
    val perfect_sessions: Long,
    val overall_accuracy: Double,
    val total_mistakes: Long,
    val mistake_breakdown: Map<String, Long>
)

@Serializable
data class SessionSummaryResponse(
    val session_id: String,
    val sura: Int,
    val aya: Int,
    val all_correct: Boolean,
    val mistakes_count: Long,
    val created_at: String
)

@Serializable
data class SessionListResponse(
    val sessions: List<SessionSummaryResponse>,
    val total: Long,
    val limit: Int,
    val offset: Int
)

@Serializable
data class MistakeDetailResponse(
    val id: String,
    val char_start: Int,
    val char_end: Int,
    val error_type: String,
    val speech_error_type: String?,
    val rule_name_en: String?,
    val rule_name_ar: String?,
    val expected_len: Int?,
    val predicted_len: Int?
)

@Serializable
data class SessionDetailResponse(
    val session_id: String,
    val sura: Int,
    val aya: Int,
    val all_correct: Boolean,
    val created_at: String,
    val mistakes: List<MistakeDetailResponse>
)

fun Route.progressRoutes() {

    get("/progress") {
        val userId = call.userId()
        val totalSessions   = SessionRepository.countByUser(userId)
        val perfectSessions = SessionRepository.countPerfectByUser(userId)
        val breakdown       = MistakeRepository.countByRuleForUser(userId)
        val totalMistakes   = breakdown.values.sum()
        val accuracy        = if (totalSessions == 0L) 0.0
                              else perfectSessions.toDouble() / totalSessions
        call.respond(
            ProgressSummaryResponse(
                total_sessions    = totalSessions,
                perfect_sessions  = perfectSessions,
                overall_accuracy  = accuracy,
                total_mistakes    = totalMistakes,
                mistake_breakdown = breakdown
            )
        )
    }

    get("/progress/sessions") {
        val userId = call.userId()
        val limit  = (call.request.queryParameters["limit"]?.toIntOrNull()  ?: 20).coerceIn(1, 100)
        val offset = (call.request.queryParameters["offset"]?.toIntOrNull() ?: 0).coerceAtLeast(0)
        val total  = SessionRepository.countByUser(userId)
        val sessions = SessionRepository.findWithMistakeCounts(userId, limit, offset).map {
            SessionSummaryResponse(
                session_id     = it.id.toString(),
                sura           = it.sura,
                aya            = it.aya,
                all_correct    = it.allCorrect,
                mistakes_count = it.mistakesCount,
                created_at     = it.createdAt.toString()
            )
        }
        call.respond(SessionListResponse(sessions = sessions, total = total, limit = limit, offset = offset))
    }

    get("/progress/sessions/{session_id}") {
        val userId = call.userId()
        val sessionId = try {
            UUID.fromString(call.parameters["session_id"])
        } catch (_: IllegalArgumentException) {
            return@get call.respond(HttpStatusCode.NotFound,
                ErrorResponse("not_found", "Session not found"))
        }
        val session = SessionRepository.findById(sessionId)
        if (session == null || session.userId != userId) {
            return@get call.respond(HttpStatusCode.NotFound,
                ErrorResponse("not_found", "Session not found"))
        }
        val mistakes = MistakeRepository.findBySession(sessionId).map { m ->
            MistakeDetailResponse(
                id                = m.id.toString(),
                char_start        = m.charStart,
                char_end          = m.charEnd,
                error_type        = m.errorType,
                speech_error_type = m.speechErrorType,
                rule_name_en      = m.ruleNameEn,
                rule_name_ar      = m.ruleNameAr,
                expected_len      = m.expectedLen,
                predicted_len     = m.predictedLen
            )
        }
        call.respond(
            SessionDetailResponse(
                session_id  = session.id.toString(),
                sura        = session.sura,
                aya         = session.aya,
                all_correct = session.allCorrect,
                created_at  = session.createdAt.toString(),
                mistakes    = mistakes
            )
        )
    }
}

