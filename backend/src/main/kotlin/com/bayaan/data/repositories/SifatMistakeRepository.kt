package com.bayaan.data.repositories

import com.bayaan.SifatMistakeInput
import com.bayaan.data.DatabaseFactory
import com.bayaan.data.tables.Sessions
import com.bayaan.data.tables.SifatMistakes
import org.jetbrains.exposed.sql.*
import org.jetbrains.exposed.sql.SqlExpressionBuilder.eq
import java.math.BigDecimal
import java.util.UUID

// Mirrors MistakeRepository: persist the engine's sifat_errors and aggregate them per user.
object SifatMistakeRepository {

    suspend fun insertBatch(sessionId: UUID, rows: List<SifatMistakeInput>) {
        if (rows.isEmpty()) return
        DatabaseFactory.dbQuery {
            SifatMistakes.batchInsert(rows) { r ->
                this[SifatMistakes.id] = UUID.randomUUID()
                this[SifatMistakes.sessionId] = sessionId
                this[SifatMistakes.phonemesGroup] = r.phonemesGroup
                this[SifatMistakes.attribute] = r.attribute
                this[SifatMistakes.predicted] = r.predicted
                this[SifatMistakes.expected] = r.expected
                this[SifatMistakes.confidence] = r.confidence?.let { BigDecimal.valueOf(it) }
            }
        }
    }

    // GROUP BY attribute across all the user's sessions → {attribute: count}.
    suspend fun countByAttributeForUser(userId: UUID): Map<String, Long> =
        DatabaseFactory.dbQuery {
            Sessions.innerJoin(SifatMistakes, { Sessions.id }, { SifatMistakes.sessionId })
                .select(SifatMistakes.attribute, SifatMistakes.id.count())
                .where { Sessions.userId eq userId }
                .groupBy(SifatMistakes.attribute)
                .associate { row ->
                    row[SifatMistakes.attribute] to row[SifatMistakes.id.count()]
                }
        }
}
