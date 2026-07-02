package com.bayaan.plugins

import com.auth0.jwk.JwkProviderBuilder
import io.ktor.http.*
import io.ktor.server.application.*
import io.ktor.server.auth.*
import io.ktor.server.auth.jwt.*
import io.ktor.server.response.*
import java.net.URI
import java.util.concurrent.TimeUnit

fun Application.configureJwt() {
    val projectRef = System.getenv("SUPABASE_PROJECT_REF")
        ?: throw IllegalStateException("SUPABASE_PROJECT_REF env var is required")
    val issuer = "https://$projectRef.supabase.co/auth/v1"

    // Verify tokens against the project's asymmetric signing key (ES256) via the public
    // JWKS endpoint — no shared secret to manage. Ktor resolves the key by the token's
    // `kid` and picks the algorithm automatically. Requires the ECC key to be the
    // *current* signing key in Supabase (Settings → JWT Keys → Rotate keys).
    val jwkProvider = JwkProviderBuilder(URI("$issuer/.well-known/jwks.json").toURL())
        .cached(10, 24, TimeUnit.HOURS)
        .rateLimited(10, 1, TimeUnit.MINUTES)
        .build()

    authentication {
        jwt("auth-jwt") {
            verifier(jwkProvider, issuer) {
                withAudience("authenticated")
            }
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
