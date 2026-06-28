package com.bayaan.data.repositories

import com.bayaan.data.DatabaseFactory
import com.bayaan.data.tables.Sessions
import org.jetbrains.exposed.sql.insert
import java.util.UUID

object SessionRepository {

    suspend fun insert(userId: UUID, sura: Int, aya: Int, allCorrect: Boolean): UUID =
        DatabaseFactory.dbQuery {
            val id = UUID.randomUUID()
            Sessions.insert {
                it[Sessions.id] = id
                it[Sessions.userId] = userId
                it[Sessions.sura] = sura
                it[Sessions.aya] = aya
                it[Sessions.allCorrect] = allCorrect
            }
            id
        }
}
