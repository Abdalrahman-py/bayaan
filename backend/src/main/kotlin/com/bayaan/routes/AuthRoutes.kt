package com.bayaan.routes

import com.bayaan.data.repositories.UserRepository
import com.bayaan.plugins.userId
import io.ktor.http.*
import io.ktor.server.auth.*
import io.ktor.server.response.*
import io.ktor.server.routing.*

fun Route.authRoutes() {
    post("/auth/sync") {
        val userId = call.userId()
        val created = UserRepository.upsert(userId)
        call.respondText(
            """{"user_id":"$userId","created":$created}""",
            ContentType.Application.Json,
        )
    }
}
