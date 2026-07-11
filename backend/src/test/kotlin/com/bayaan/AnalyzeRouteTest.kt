package com.bayaan

import com.bayaan.plugins.configureJwt
import com.bayaan.routes.analyzeRoute
import io.ktor.client.request.forms.MultiPartFormDataContent
import io.ktor.client.request.forms.formData
import io.ktor.client.request.header
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.client.statement.bodyAsText
import io.ktor.http.Headers
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.serialization.kotlinx.json.json
import io.ktor.server.auth.authenticate
import io.ktor.server.plugins.contentnegotiation.ContentNegotiation
import io.ktor.server.routing.routing
import io.ktor.server.testing.testApplication
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertContains

class AnalyzeRouteTest {

    // ── engine error statuses ────────────────────────────────────────────────

    @Test
    fun `engine non-2xx status is forwarded unchanged`() = TestJwks.withServer { issuer -> testApplication {
        install(ContentNegotiation) { json() }
        application {
            configureJwt(issuer)
            routing {
                authenticate("auth-jwt") {
                    analyzeRoute(RecitationAnalysis(engine = { _, _, _ ->
                        EngineResponse(422, """{"error":"unprocessable"}""")
                    }))
                }
            }
        }
        val resp = client.post("/audio/analyze") {
            header(HttpHeaders.Authorization, "Bearer ${TestJwks.token(issuer)}")
            setBody(audioMultipart())
        }
        assertEquals(422, resp.status.value)
        assertEquals("""{"error":"unprocessable"}""", resp.bodyAsText())
    } }

    // ── engine response unparseable ─────────────────────────────────────────

    @Test
    fun `unparseable engine response returns 503 ml_unavailable`() = TestJwks.withServer { issuer -> testApplication {
        install(ContentNegotiation) { json() }
        application {
            configureJwt(issuer)
            routing {
                authenticate("auth-jwt") {
                    analyzeRoute(RecitationAnalysis(engine = { _, _, _ ->
                        EngineResponse(200, "not-json-at-all")
                    }))
                }
            }
        }
        val resp = client.post("/audio/analyze") {
            header(HttpHeaders.Authorization, "Bearer ${TestJwks.token(issuer)}")
            setBody(audioMultipart())
        }
        assertEquals(HttpStatusCode.ServiceUnavailable, resp.status)
        assertContains(resp.bodyAsText(), "ml_unavailable")
    } }

    // ── engine unreachable ───────────────────────────────────────────────────

    @Test
    fun `engine exception returns 503 ml_unavailable`() = TestJwks.withServer { issuer -> testApplication {
        install(ContentNegotiation) { json() }
        application {
            configureJwt(issuer)
            routing {
                authenticate("auth-jwt") {
                    analyzeRoute(RecitationAnalysis(engine = { _, _, _ ->
                        throw Exception("connection refused")
                    }))
                }
            }
        }
        val resp = client.post("/audio/analyze") {
            header(HttpHeaders.Authorization, "Bearer ${TestJwks.token(issuer)}")
            setBody(audioMultipart())
        }
        assertEquals(HttpStatusCode.ServiceUnavailable, resp.status)
        assertContains(resp.bodyAsText(), "ml_unavailable")
    } }

    // ── validation ───────────────────────────────────────────────────────────

    @Test
    fun `missing audio field returns 400 bad_request`() = TestJwks.withServer { issuer -> testApplication {
        install(ContentNegotiation) { json() }
        application {
            configureJwt(issuer)
            routing {
                authenticate("auth-jwt") {
                    analyzeRoute(RecitationAnalysis(engine = { _, _, _ ->
                        EngineResponse(200, """{"all_correct":true,"errors":[]}""")
                    }))
                }
            }
        }
        val resp = client.post("/audio/analyze") {
            header(HttpHeaders.Authorization, "Bearer ${TestJwks.token(issuer)}")
            setBody(MultiPartFormDataContent(formData {
                append("sura", "1")
                append("aya", "1")
            }))
        }
        assertEquals(HttpStatusCode.BadRequest, resp.status)
        assertContains(resp.bodyAsText(), "bad_request")
    } }

    // ── helpers ──────────────────────────────────────────────────────────────

    private fun audioMultipart(sura: Int = 1, aya: Int = 1) =
        MultiPartFormDataContent(formData {
            append("audio", ByteArray(256), Headers.build {
                append(HttpHeaders.ContentDisposition, "filename=\"recording.wav\"")
            })
            append("sura", sura.toString())
            append("aya", aya.toString())
        })
}
