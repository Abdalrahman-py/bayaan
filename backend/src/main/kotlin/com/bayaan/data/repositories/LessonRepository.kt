package com.bayaan.data.repositories

import com.bayaan.data.DatabaseFactory
import com.bayaan.data.tables.LessonAttempts
import com.bayaan.data.tables.LessonProgress
import kotlinx.datetime.Clock
import org.jetbrains.exposed.sql.*
import java.math.BigDecimal
import java.util.UUID

data class LessonState(val lessonId: String, val status: String, val bestScore: BigDecimal, val attempts: Int)

// Owns `lesson_progress` (per-lesson status) and `lesson_attempts` (the append-only
// attempt log) — always written together by /learn/complete.
object LessonRepository {

    suspend fun progressForUser(userId: UUID): Map<String, LessonState> = DatabaseFactory.dbQuery {
        LessonProgress.selectAll().where { LessonProgress.userId eq userId }
            .associate {
                it[LessonProgress.lessonId] to LessonState(
                    lessonId = it[LessonProgress.lessonId],
                    status = it[LessonProgress.status],
                    bestScore = it[LessonProgress.bestScore],
                    attempts = it[LessonProgress.attempts]
                )
            }
    }

    // Mastery thresholds from PRODUCTION_PLAN.md §4.x: 0.80 lesson, 0.85 checkpoint.
    suspend fun recordAttempt(
        userId: UUID,
        lessonId: String,
        isCheckpoint: Boolean,
        score: BigDecimal,
        itemResultsJson: String
    ): LessonState = DatabaseFactory.dbQuery {
        ProfileRepository.ensure(userId)
        LessonAttempts.insert {
            it[id] = UUID.randomUUID()
            it[LessonAttempts.userId] = userId
            it[LessonAttempts.lessonId] = lessonId
            it[LessonAttempts.score] = score
            it[itemResults] = itemResultsJson
        }

        val threshold = if (isCheckpoint) BigDecimal("0.85") else BigDecimal("0.80")
        val passed = score >= threshold
        val existing = LessonProgress.selectAll()
            .where { (LessonProgress.userId eq userId) and (LessonProgress.lessonId eq lessonId) }
            .singleOrNull()

        val newBest = existing?.get(LessonProgress.bestScore)?.max(score) ?: score
        val newAttempts = (existing?.get(LessonProgress.attempts) ?: 0) + 1
        val newStatus = if (passed) "completed" else (existing?.get(LessonProgress.status) ?: "in_progress")
        val alreadyCompleted = existing?.get(LessonProgress.status) == "completed"

        if (existing == null) {
            LessonProgress.insert {
                it[LessonProgress.userId] = userId
                it[LessonProgress.lessonId] = lessonId
                it[status] = newStatus
                it[bestScore] = newBest
                it[attempts] = newAttempts
                if (passed) it[completedAt] = Clock.System.now()
            }
        } else {
            LessonProgress.update({ (LessonProgress.userId eq userId) and (LessonProgress.lessonId eq lessonId) }) {
                it[status] = newStatus
                it[bestScore] = newBest
                it[attempts] = newAttempts
                if (passed && !alreadyCompleted) it[completedAt] = Clock.System.now()
            }
        }
        LessonState(lessonId, newStatus, newBest, newAttempts)
    }
}
