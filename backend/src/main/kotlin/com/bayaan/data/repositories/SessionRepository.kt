package com.bayaan.data.repositories

import com.bayaan.data.DatabaseFactory
import com.bayaan.data.tables.Mistakes
import com.bayaan.data.tables.Sessions
import kotlinx.datetime.Instant
import org.jetbrains.exposed.sql.*
import java.util.UUID

data class Session(
    val id: UUID,
    val userId: UUID,
    val sura: Int,
    val aya: Int,
    val allCorrect: Boolean,
    val createdAt: Instant
)

data class SessionWithCount(
    val id: UUID,
    val userId: UUID,
    val sura: Int,
    val aya: Int,
    val allCorrect: Boolean,
    val createdAt: Instant,
    val mistakesCount: Long
)

object SessionRepository {

    suspend fun insert(userId: UUID, sura: Int, aya: Int, allCorrect: Boolean): UUID =
        DatabaseFactory.dbQuery {
            val sessionId = UUID.randomUUID()
            Sessions.insert {
                it[id] = sessionId
                it[Sessions.userId] = userId
                it[Sessions.sura] = sura
                it[Sessions.aya] = aya
                it[Sessions.allCorrect] = allCorrect
            }
            sessionId
        }

    suspend fun findById(sessionId: UUID): Session? =
        DatabaseFactory.dbQuery {
            Sessions.selectAll()
                .where { Sessions.id eq sessionId }
                .singleOrNull()
                ?.mapToSession()
        }

    suspend fun findByUser(userId: UUID, limit: Int = 20, offset: Int = 0): List<Session> =
        DatabaseFactory.dbQuery {
            Sessions.selectAll()
                .where { Sessions.userId eq userId }
                .orderBy(Sessions.createdAt to SortOrder.DESC)
                .limit(limit)
                .offset(offset.toLong())
                .map { it.mapToSession() }
        }

    suspend fun findWithMistakeCounts(userId: UUID, limit: Int = 20, offset: Int = 0): List<SessionWithCount> =
        DatabaseFactory.dbQuery {
            Sessions
                .join(Mistakes, JoinType.LEFT, Sessions.id, Mistakes.sessionId)
                .select(
                    Sessions.id, Sessions.userId, Sessions.sura, Sessions.aya,
                    Sessions.allCorrect, Sessions.createdAt, Mistakes.id.count()
                )
                .where { Sessions.userId eq userId }
                .groupBy(Sessions.id, Sessions.userId, Sessions.sura, Sessions.aya,
                    Sessions.allCorrect, Sessions.createdAt)
                .orderBy(Sessions.createdAt to SortOrder.DESC)
                .limit(limit)
                .offset(offset.toLong())
                .map {
                    SessionWithCount(
                        id           = it[Sessions.id],
                        userId       = it[Sessions.userId],
                        sura         = it[Sessions.sura],
                        aya          = it[Sessions.aya],
                        allCorrect   = it[Sessions.allCorrect],
                        createdAt    = it[Sessions.createdAt],
                        mistakesCount = it[Mistakes.id.count()]
                    )
                }
        }

    suspend fun countByUser(userId: UUID): Long =
        DatabaseFactory.dbQuery {
            Sessions.selectAll().where { Sessions.userId eq userId }.count()
        }

    suspend fun countPerfectByUser(userId: UUID): Long =
        DatabaseFactory.dbQuery {
            Sessions.selectAll()
                .where { (Sessions.userId eq userId) and (Sessions.allCorrect eq true) }
                .count()
        }

    private fun ResultRow.mapToSession(): Session =
        Session(
            id = this[Sessions.id],
            userId = this[Sessions.userId],
            sura = this[Sessions.sura],
            aya = this[Sessions.aya],
            allCorrect = this[Sessions.allCorrect],
            createdAt = this[Sessions.createdAt]
        )
}
