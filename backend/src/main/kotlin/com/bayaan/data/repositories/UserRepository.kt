package com.bayaan.data.repositories

import com.bayaan.data.DatabaseFactory
import com.bayaan.data.tables.Users
import org.jetbrains.exposed.sql.insert
import org.jetbrains.exposed.sql.selectAll
import java.util.UUID

object UserRepository {

    suspend fun upsert(userId: UUID): Boolean = DatabaseFactory.dbQuery {
        val exists = Users.selectAll().where { Users.id eq userId }.singleOrNull() != null
        if (!exists) {
            Users.insert { it[id] = userId }
        }
        !exists
    }
}
