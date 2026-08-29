package com.bayaan.routes

import com.bayaan.ErrorResponse
import com.bayaan.data.Curriculum
import com.bayaan.data.repositories.LessonRepository
import com.bayaan.data.repositories.Profile
import com.bayaan.data.repositories.ProfileRepository
import com.bayaan.data.repositories.ReviewRepository
import com.bayaan.plugins.userId
import io.ktor.http.*
import io.ktor.server.auth.*
import io.ktor.server.request.*
import io.ktor.server.response.*
import io.ktor.server.routing.*
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.math.BigDecimal
import java.util.UUID

// Contracts are frozen in .scratch/mvp-tracks/ramzi-backend-tasks.md R3 (and docs/api-spec.md).
// Fixed constants — owner retunes, not the code:
private const val XP_LESSON_BASE = 10
private const val XP_CHECKPOINT_BASE = 20
private const val XP_PER_CORRECT = 2
private const val XP_REVIEW = 5
private val learnJson = Json { encodeDefaults = true }

@Serializable
data class HeaderResponse(
    val arabic_level: Int,
    val xp: Int,
    val streak_count: Int,
    val daily_goal_minutes: Int,
    val reviews_due: Int,
)

@Serializable
data class LessonNodeResponse(
    val lesson_id: String,
    val title_en: String,
    val title_ar: String,
    val is_checkpoint: Boolean,
    val status: String,
    val best_score: Double,
    val attempts: Int,
)

@Serializable
data class UnitResponse(
    val unit_id: String,
    val track: String,
    val title_en: String,
    val title_ar: String,
    val lessons: List<LessonNodeResponse>,
)

@Serializable
data class LearnPathResponse(val header: HeaderResponse, val units: List<UnitResponse>)

@Serializable
data class CompleteItemResult(val item_ref: String, val correct: Boolean, val first_try: Boolean = false)

@Serializable
data class LessonCompleteRequest(
    val lesson_id: String,
    val score: Double,
    val is_checkpoint: Boolean = false, // informational; curriculum is authoritative below
    val item_results: List<CompleteItemResult> = emptyList(),
)

@Serializable
data class LessonCompleteResponse(val header: HeaderResponse)

@Serializable
data class ReviewDueResponse(val review_id: String, val item_ref: String, val due_on: String)

@Serializable
data class ReviewsResponse(val reviews: List<ReviewDueResponse>)

@Serializable
data class ReviewResultRequest(val correct: Boolean)

@Serializable
data class ReviewResultResponse(val next_due_on: String, val reviews_due: Int)

@Serializable
data class PlacementItemResult(val item_ref: String, val difficulty: Int = 0, val correct: Boolean)

@Serializable
data class PlacementRequest(val item_results: List<PlacementItemResult> = emptyList())

@Serializable
data class PlacementResponse(val arabic_level: Int, val placement_message_key: String)

// Placement gating — how a learner's arabic_level (0–8, written by /learn/placement)
// turns into unlocked units. Level N means the learner demonstrated units 1..N, so those
// units plus the next one open immediately — available, never completed. Marking them
// completed would invent lesson_progress rows for work nobody did; the learner can still
// walk back through anything below their level. Only the arabic track is placed: nothing
// in the placement test measures tajweed. `position` is the unit's 1-based index in
// curriculum file order, matching curriculum_units.position in backend/sql/0005.
private fun placementUnlocks(track: String, position: Int, arabicLevel: Int): Boolean =
    track == "arabic" && position <= arabicLevel + 1

fun Route.learnRoutes() {

    get("/learn/path") {
        val userId = call.userId()
        val profile = ProfileRepository.ensure(userId)
        val progress = LessonRepository.progressForUser(userId)
        val reviewsDue = ReviewRepository.dueCount(userId)

        // Single global chain in curriculum file order: a lesson is available once the
        // immediately-preceding lesson (across the whole file) is completed. This also
        // gates the tajweed track behind the last Arabic lesson — graduation unlocks it.
        // Placement opens an additional prefix of the arabic track on top of that chain.
        var prevCompleted = true
        val units = Curriculum.file.units.withIndex().map { (index, unit) ->
            val unitPosition = index + 1
            UnitResponse(
                unit_id = unit.unit_id,
                track = unit.track,
                title_en = unit.title_en,
                title_ar = unit.title_ar,
                lessons = unit.lessons.map { lesson ->
                    val state = progress[lesson.lesson_id]
                    val status = when {
                        state?.status == "completed" -> "completed"
                        state?.status == "in_progress" -> "in_progress"
                        prevCompleted ||
                            placementUnlocks(unit.track, unitPosition, profile.arabicLevel) ->
                            "available"
                        else -> "locked"
                    }
                    prevCompleted = status == "completed"
                    LessonNodeResponse(
                        lesson_id = lesson.lesson_id,
                        title_en = lesson.title_en,
                        title_ar = lesson.title_ar,
                        is_checkpoint = lesson.is_checkpoint,
                        status = status,
                        best_score = state?.bestScore?.toDouble() ?: 0.0,
                        attempts = state?.attempts ?: 0,
                    )
                },
            )
        }
        call.respond(LearnPathResponse(profile.header(reviewsDue), units))
    }

    post("/learn/complete") {
        val userId = call.userId()
        val body = call.receive<LessonCompleteRequest>()
        val lesson = Curriculum.file.units.flatMap { it.lessons }.find { it.lesson_id == body.lesson_id }
            ?: return@post call.respond(HttpStatusCode.NotFound, ErrorResponse("not_found", "Unknown lesson_id"))

        val isCheckpoint = lesson.is_checkpoint // server truth, not the client's is_checkpoint
        val score = BigDecimal.valueOf(body.score.coerceIn(0.0, 1.0))
        LessonRepository.recordAttempt(userId, body.lesson_id, isCheckpoint, score, learnJson.encodeToString(body.item_results))

        // XP = base + XP_PER_CORRECT per item answered correctly on the first try.
        val firstTryCorrect = body.item_results.count { it.correct && it.first_try }
        val base = if (isCheckpoint) XP_CHECKPOINT_BASE else XP_LESSON_BASE
        val xpAwarded = base + XP_PER_CORRECT * firstTryCorrect
        val reason = if (isCheckpoint) "checkpoint_complete" else "lesson_complete"

        ProfileRepository.addXp(userId, xpAwarded, reason)
        val profile = ProfileRepository.bumpStreak(userId) // idempotent per UTC day
        val weakRefs = body.item_results.filter { !it.correct }.map { it.item_ref }
        if (weakRefs.isNotEmpty()) ReviewRepository.pushWeak(userId, weakRefs)

        call.respond(LessonCompleteResponse(profile.header(ReviewRepository.dueCount(userId))))
    }

    get("/learn/reviews") {
        val userId = call.userId()
        val limit = (call.request.queryParameters["limit"]?.toIntOrNull() ?: 20).coerceIn(1, 100)
        val reviews = ReviewRepository.due(userId, limit).map {
            ReviewDueResponse(it.id.toString(), it.itemRef, it.dueOn.toString())
        }
        call.respond(ReviewsResponse(reviews))
    }

    post("/learn/reviews/{id}/result") {
        val userId = call.userId()
        val reviewId = try {
            UUID.fromString(call.parameters["id"])
        } catch (_: IllegalArgumentException) {
            return@post call.respond(HttpStatusCode.NotFound, ErrorResponse("not_found", "Review item not found"))
        }
        val body = call.receive<ReviewResultRequest>()
        val updated = ReviewRepository.recordResult(userId, reviewId, body.correct)
            ?: return@post call.respond(HttpStatusCode.NotFound, ErrorResponse("not_found", "Review item not found"))
        // ponytail: flat per-review XP, no cap/dedup — owner call (not MVP-critical, tune in prod).
        if (body.correct) ProfileRepository.addXp(userId, XP_REVIEW, "review_correct")
        call.respond(ReviewResultResponse(updated.dueOn.toString(), ReviewRepository.dueCount(userId)))
    }

    post("/learn/placement") {
        val userId = call.userId()
        val body = call.receive<PlacementRequest>()

        // Server computes the level deterministically — the client result is not trusted.
        var level = 3
        var hits = 0
        var misses = 0
        for (r in body.item_results) {
            if (r.correct) { hits++; misses = 0 } else { misses++; hits = 0 }
            if (misses == 2) { level = (level - 1).coerceAtLeast(0); misses = 0 }
            if (hits == 3) { level = (level + 1).coerceAtMost(8); hits = 0 }
        }
        ProfileRepository.recordPlacement(userId, level, learnJson.encodeToString(body.item_results))
        call.respond(PlacementResponse(level, "placement.level.$level"))
    }
}

private fun Profile.header(reviewsDue: Int) =
    HeaderResponse(arabicLevel, xp, streakCount, dailyGoalMinutes, reviewsDue)
