package com.bayaan.data.repositories

import com.bayaan.MistakeInput
import com.bayaan.data.DatabaseFactory
import com.bayaan.data.tables.Mistakes
import com.bayaan.data.tables.Sessions
import kotlinx.datetime.Instant
import org.jetbrains.exposed.sql.*
import org.jetbrains.exposed.sql.SqlExpressionBuilder.eq
import java.util.UUID

data class Mistake(
    val id: UUID,
    val sessionId: UUID,
    val charStart: Int,
    val charEnd: Int,
    val errorType: String,
    val speechErrorType: String?,
    val ruleNameEn: String?,
    val ruleNameAr: String?,
    val expectedLen: Int?,
    val predictedLen: Int?,
    val createdAt: Instant
)

object MistakeRepository {

    suspend fun insertBatch(sessionId: UUID, mistakes: List<MistakeInput>) {
        if (mistakes.isEmpty()) return
        DatabaseFactory.dbQuery {
            Mistakes.batchInsert(mistakes) { m ->
                this[Mistakes.id] = UUID.randomUUID()
                this[Mistakes.sessionId] = sessionId
                this[Mistakes.charStart] = m.charStart
                this[Mistakes.charEnd] = m.charEnd
                this[Mistakes.errorType] = m.errorType
                this[Mistakes.speechErrorType] = m.speechErrorType
                this[Mistakes.ruleNameEn] = m.ruleNameEn
                this[Mistakes.ruleNameAr] = m.ruleNameAr
                this[Mistakes.expectedLen] = m.expectedLen
                this[Mistakes.predictedLen] = m.predictedLen
            }
        }
    }

    suspend fun findBySession(sessionId: UUID): List<Mistake> =
        DatabaseFactory.dbQuery {
            Mistakes.selectAll()
                .where { Mistakes.sessionId eq sessionId }
                .map { it.mapToMistake() }
        }

    suspend fun countBySession(sessionId: UUID): Long =
        DatabaseFactory.dbQuery {
            Mistakes.selectAll()
                .where { Mistakes.sessionId eq sessionId }
                .count()
        }

    suspend fun countByRuleForUser(userId: UUID): Map<String, Long> =
        DatabaseFactory.dbQuery {
            Sessions.innerJoin(Mistakes, { Sessions.id }, { Mistakes.sessionId })
                .select(Mistakes.ruleNameEn, Mistakes.id.count())
                .where { Sessions.userId eq userId }
                .groupBy(Mistakes.ruleNameEn)
                .associate { row ->
                    val rule = row[Mistakes.ruleNameEn] ?: "Other"
                    rule to row[Mistakes.id.count()]
                }
        }

    private fun ResultRow.mapToMistake(): Mistake =
        Mistake(
            id = this[Mistakes.id],
            sessionId = this[Mistakes.sessionId],
            charStart = this[Mistakes.charStart],
            charEnd = this[Mistakes.charEnd],
            errorType = this[Mistakes.errorType],
            speechErrorType = this[Mistakes.speechErrorType],
            ruleNameEn = this[Mistakes.ruleNameEn],
            ruleNameAr = this[Mistakes.ruleNameAr],
            expectedLen = this[Mistakes.expectedLen],
            predictedLen = this[Mistakes.predictedLen],
            createdAt = this[Mistakes.createdAt]
        )
}
