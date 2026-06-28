package com.bayaan.data.repositories

import com.bayaan.data.DatabaseFactory
import com.bayaan.data.tables.Mistakes
import org.jetbrains.exposed.sql.batchInsert
import java.util.UUID

data class MistakeInput(
    val charStart: Int,
    val charEnd: Int,
    val errorType: String,
    val speechErrorType: String?,
    val ruleNameEn: String?,
    val ruleNameAr: String?,
    val expectedLen: Int?,
    val predictedLen: Int?,
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
}
