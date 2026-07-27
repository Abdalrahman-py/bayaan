package com.bayaan

import com.bayaan.plugins.configureJwt
import com.bayaan.routes.analyzeRoute
import com.bayaan.routes.progressRoutes
import io.ktor.client.request.forms.MultiPartFormDataContent
import io.ktor.client.request.forms.formData
import io.ktor.client.request.get
import io.ktor.client.request.header
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.server.auth.authenticate
import io.ktor.serialization.kotlinx.json.json
import io.ktor.server.plugins.contentnegotiation.ContentNegotiation
import io.ktor.server.routing.routing
import io.ktor.server.testing.testApplication
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
    fun `analyze without audio is bad request`() = TestJwks.withServer { issuer -> testApplication {
        install(ContentNegotiation) { json() }
        application {
            configureJwt(issuer)
            routing {
                authenticate("auth-jwt") { analyzeRoute() }
            }
        }
        val response = client.post("/audio/analyze") {
            header(HttpHeaders.Authorization, "Bearer ${TestJwks.token(issuer)}")
            setBody(MultiPartFormDataContent(formData { append("sura", "1") }))
        }
        assertEquals(HttpStatusCode.BadRequest, response.status)
    } }

    // R7–R10 auth gate: no token → 401 (DB never touched; lazy init means no SUPABASE_DB_URL needed)
    @Test
    fun `progress summary requires auth`() = testApplication {
        application { configureJwt(); routing { authenticate("auth-jwt") { progressRoutes() } } }
        assertEquals(HttpStatusCode.Unauthorized, client.get("/progress").status)
    }

    @Test
    fun `progress sessions list requires auth`() = testApplication {
        application { configureJwt(); routing { authenticate("auth-jwt") { progressRoutes() } } }
        assertEquals(HttpStatusCode.Unauthorized, client.get("/progress/sessions").status)
    }

    @Test
    fun `progress session detail requires auth`() = testApplication {
        application { configureJwt(); routing { authenticate("auth-jwt") { progressRoutes() } } }
        // 404-on-wrong-owner and pagination boundary are covered in ProgressRoutesTest (needs live DB)
        assertEquals(HttpStatusCode.Unauthorized, client.get("/progress/sessions/${UUID.randomUUID()}").status)
    }
}
