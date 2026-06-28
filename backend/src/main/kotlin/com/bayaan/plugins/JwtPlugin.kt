package com.bayaan.plugins

import com.auth0.jwt.JWT
import com.auth0.jwt.algorithms.Algorithm
import io.ktor.http.*
import io.ktor.server.application.*
import io.ktor.server.auth.*
import io.ktor.server.auth.jwt.*
import io.ktor.server.response.*

fun Application.configureJwt() {
    val secret = System.getenv("SUPABASE_JWT_SECRET")
        ?: throw IllegalStateException("SUPABASE_JWT_SECRET env var is required")
    val projectRef = System.getenv("SUPABASE_PROJECT_REF")
        ?: throw IllegalStateException("SUPABASE_PROJECT_REF env var is required")
    val issuer = "https://$projectRef.supabase.co/auth/v1"

    authentication {
        jwt("auth-jwt") {
            verifier(
                JWT.require(Algorithm.HMAC256(secret))
                    .withIssuer(issuer)
                    .withAudience("authenticated")
                    .build()
            )
            validate { credential ->
                val sub = credential.payload.subject
                if (sub.isNullOrBlank()) null else JWTPrincipal(credential.payload)
            }
            challenge { _, _ ->
                call.respondText(
                    """{"error":"unauthorized","message":"Invalid or expired token"}""",
                    ContentType.Application.Json, HttpStatusCode.Unauthorized,
                )
            }
        }
    }
}
