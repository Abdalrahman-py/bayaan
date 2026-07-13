package com.bayaan

import com.bayaan.plugins.configureJwt
import com.bayaan.routes.speechGradeRoute
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
import kotlin.test.assertContains
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class SpeechGradeRouteTest {

    @Test
    fun `missing audio returns 400`() = TestJwks.withServer { issuer -> testApplication {
        install(ContentNegotiation) { json() }
        application {
            configureJwt(issuer)
            routing { authenticate("auth-jwt") { speechGradeRoute() } }
        }
        val resp = client.post("/speech/grade") {
            header(HttpHeaders.Authorization, "Bearer ${TestJwks.token(issuer)}")
            setBody(MultiPartFormDataContent(formData {
                append("tier", "1")
                append("reference_text", "بَا")
                append("item_ref", "ar.1.1.echo.ba")
            }))
        }
        assertEquals(HttpStatusCode.BadRequest, resp.status)
        assertContains(resp.bodyAsText(), "missing audio")
    } }

    @Test
    fun `decode crash from engine becomes verdict retry 200`() = TestJwks.withServer { issuer -> testApplication {
        install(ContentNegotiation) { json() }
        application {
            configureJwt(issuer)
            routing {
                authenticate("auth-jwt") {
                    speechGradeRoute(SpeechGrade(engine = { _, _ ->
                        GradeEngineResponse(
                            422,
                            """{"error":"decode_failed","message":"RuntimeError: negative dim"}""",
                        )
                    }))
                }
            }
        }
        val resp = client.post("/speech/grade") {
            header(HttpHeaders.Authorization, "Bearer ${TestJwks.token(issuer)}")
            setBody(gradeMultipart())
        }
        assertEquals(HttpStatusCode.OK, resp.status)
        val body = resp.bodyAsText()
        assertContains(body, "\"verdict\":\"retry\"")
        assertContains(body, "ar.1.1.echo.ba")
    } }

    @Test
    fun `happy path normalizes pass verdict`() = TestJwks.withServer { issuer -> testApplication {
        install(ContentNegotiation) { json() }
        application {
            configureJwt(issuer)
            routing {
                authenticate("auth-jwt") {
                    speechGradeRoute(SpeechGrade(engine = { _, _ ->
                        GradeEngineResponse(200, """{"errors":[],"sifat_errors":[]}""")
                    }))
                }
            }
        }
        val resp = client.post("/speech/grade") {
            header(HttpHeaders.Authorization, "Bearer ${TestJwks.token(issuer)}")
            setBody(gradeMultipart())
        }
        assertEquals(HttpStatusCode.OK, resp.status)
        assertTrue(resp.bodyAsText().contains("\"verdict\":\"pass\""))
    } }

    @Test
    fun `engine unreachable returns 503`() = TestJwks.withServer { issuer -> testApplication {
        install(ContentNegotiation) { json() }
        application {
            configureJwt(issuer)
            routing {
                authenticate("auth-jwt") {
                    speechGradeRoute(SpeechGrade(engine = { _, _ ->
                        throw RuntimeException("boom")
                    }))
                }
            }
        }
        val resp = client.post("/speech/grade") {
            header(HttpHeaders.Authorization, "Bearer ${TestJwks.token(issuer)}")
            setBody(gradeMultipart())
        }
        assertEquals(HttpStatusCode.ServiceUnavailable, resp.status)
        assertContains(resp.bodyAsText(), "ml_unavailable")
    } }

    private fun gradeMultipart() = MultiPartFormDataContent(formData {
        append("audio", byteArrayOf(1, 2, 3, 4), Headers.build {
            append(HttpHeaders.ContentDisposition, "filename=\"r.wav\"")
        })
        append("tier", "1")
        append("reference_text", "بَا")
        append("item_ref", "ar.1.1.echo.ba")
    })
}
