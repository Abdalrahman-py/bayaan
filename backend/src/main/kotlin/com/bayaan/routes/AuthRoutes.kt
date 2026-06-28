package com.bayaan.routes

import com.bayaan.data.repositories.UserRepository
import io.ktor.http.*
import io.ktor.server.auth.*
import io.ktor.server.auth.jwt.*
import io.ktor.server.response.*
import io.ktor.server.routing.*
import java.util.UUID

fun Route.authRoutes() {
    post("/auth/sync") {
        val principal = call.principal<JWTPrincipal>()!!
        val userId = try {
            UUID.fromString(principal.payload.subject)
        } catch (_: IllegalArgumentException) {
            return@post call.respondText(
                """{"error":"bad_request","message":"Invalid user ID in token"}""",
                ContentType.Application.Json, HttpStatusCode.BadRequest,
            )
        }
        val created = UserRepository.upsert(userId)
        call.respondText(
            """{"user_id":"$userId","created":$created}""",
            ContentType.Application.Json,
        )
    }
}
