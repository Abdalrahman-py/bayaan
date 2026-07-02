package com.bayaan.plugins

import com.auth0.jwt.JWT
import com.auth0.jwt.algorithms.Algorithm
import io.ktor.http.*
import io.ktor.server.application.*
import io.ktor.server.auth.*
import io.ktor.server.auth.jwt.*
import io.ktor.server.response.*
import java.util.Base64

fun Application.configureJwt() {
    val secret = System.getenv("SUPABASE_JWT_SECRET")
        ?: throw IllegalStateException("SUPABASE_JWT_SECRET env var is required")
    val projectRef = System.getenv("SUPABASE_PROJECT_REF")
        ?: throw IllegalStateException("SUPABASE_PROJECT_REF env var is required")
    val issuer = "https://$projectRef.supabase.co/auth/v1"

    // Supabase's new JWT signing keys store the HS256 secret as base64-encoded key
    // material — the token is signed with the DECODED bytes, not the base64 string.
    // Decode when the secret is valid base64; fall back to raw bytes for a legacy
    // plain-string secret.
    // ponytail: heuristic — a legacy secret that happens to be valid base64 would be
    // decoded too. Fine for this single Supabase project; revisit if the secret format
    // is ever ambiguous (then key off the token header `kid`).
    val secretBytes = try {
        Base64.getDecoder().decode(secret)
    } catch (e: IllegalArgumentException) {
        secret.toByteArray(Charsets.UTF_8)
    }

    authentication {
        jwt("auth-jwt") {
            verifier(
                JWT.require(Algorithm.HMAC256(secretBytes))
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
