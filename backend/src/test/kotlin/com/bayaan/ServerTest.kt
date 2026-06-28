package com.bayaan

import com.auth0.jwt.JWT
import com.auth0.jwt.algorithms.Algorithm
import com.bayaan.plugins.configureJwt
import io.ktor.client.request.forms.MultiPartFormDataContent
import io.ktor.client.request.forms.formData
import io.ktor.client.request.get
import io.ktor.client.request.header
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.server.auth.authenticate
import io.ktor.server.routing.routing
import io.ktor.server.testing.testApplication
import java.util.Date
import java.util.UUID
import kotlin.test.Test
import kotlin.test.assertEquals

class ServerTest {

    @Test
    fun `health returns ok`() = testApplication {
        application { routing { healthRoute() } }
        assertEquals(HttpStatusCode.OK, client.get("/health").status)
    }

    // Boundary check: valid JWT + no audio part -> 400 (without touching engine or DB).
    @Test
    fun `analyze without audio is bad request`() = testApplication {
        application {
            configureJwt()
            routing {
                authenticate("auth-jwt") { analyzeRoute() }
            }
        }
        val response = client.post("/audio/analyze") {
            header(HttpHeaders.Authorization, "Bearer $testJwt")
            setBody(MultiPartFormDataContent(formData { append("sura", "1") }))
        }
        assertEquals(HttpStatusCode.BadRequest, response.status)
    }

    companion object {
        // Must match the env vars set in tasks.withType<Test> in build.gradle.kts.
        private val testJwt: String = JWT.create()
            .withSubject(UUID.randomUUID().toString())
            .withIssuer("https://test-project.supabase.co/auth/v1")
            .withAudience("authenticated")
            .withExpiresAt(Date(System.currentTimeMillis() + 3_600_000))
            .sign(Algorithm.HMAC256("test-secret-for-bayaan-junit-testing-only-xx"))
    }
}
