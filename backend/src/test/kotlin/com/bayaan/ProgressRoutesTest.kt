package com.bayaan

import com.bayaan.MistakeInput
import com.bayaan.data.repositories.MistakeRepository
import com.bayaan.data.repositories.SessionRepository
import com.bayaan.plugins.configureJwt
import com.bayaan.routes.ProgressSummaryResponse
import com.bayaan.routes.SessionDetailResponse
import com.bayaan.routes.SessionListResponse
import com.bayaan.routes.progressRoutes
import io.ktor.client.HttpClient
import io.ktor.client.request.get
import io.ktor.client.request.header
import io.ktor.client.statement.HttpResponse
import io.ktor.client.statement.bodyAsText
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.serialization.kotlinx.json.json
import io.ktor.server.auth.authenticate
import io.ktor.server.plugins.contentnegotiation.ContentNegotiation
import io.ktor.server.routing.routing
import io.ktor.server.testing.ApplicationTestBuilder
import io.ktor.server.testing.testApplication
import kotlinx.serialization.json.Json
import java.util.UUID
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

// Fills the gap flagged as untested in ServerTest ("404-on-wrong-owner and pagination
// boundary need a live DB — integration test, not here"): cross-user data isolation and
// accuracy-math edge cases on /progress, backed by the real H2 DB via TestDatabase.
private val testJson = Json { ignoreUnknownKeys = true }

class ProgressRoutesTest {

    @BeforeTest
    fun setUp() {
        TestDatabase.install()
        TestDatabase.reset()
    }

    @Test
    fun `fresh user has zero accuracy, not NaN, with no sessions`() = progressApp { ctx ->
        val body = decode<ProgressSummaryResponse>(summary(client, ctx))
        assertEquals(0L, body.total_sessions)
        assertEquals(0L, body.perfect_sessions)
        assertEquals(0.0, body.overall_accuracy)
    }

    @Test
    fun `accuracy is the ratio of perfect to total sessions`() = progressApp { ctx ->
        SessionRepository.insert(ctx.userId, sura = 1, aya = 1, allCorrect = true)
        SessionRepository.insert(ctx.userId, sura = 1, aya = 2, allCorrect = true)
        SessionRepository.insert(ctx.userId, sura = 1, aya = 3, allCorrect = false)

        val body = decode<ProgressSummaryResponse>(summary(client, ctx))
        assertEquals(3L, body.total_sessions)
        assertEquals(2L, body.perfect_sessions)
        assertEquals(2.0 / 3.0, body.overall_accuracy)
    }

    @Test
    fun `mistake breakdown only counts the caller's own sessions`() = progressApp { ctx ->
        val otherUser = UUID.randomUUID()
        val mySession = SessionRepository.insert(ctx.userId, sura = 1, aya = 1, allCorrect = false)
        val otherSession = SessionRepository.insert(otherUser, sura = 1, aya = 1, allCorrect = false)
        MistakeRepository.insertBatch(mySession, listOf(mistake("ghonna")))
        MistakeRepository.insertBatch(otherSession, listOf(mistake("qalqla"), mistake("qalqla")))

        val body = decode<ProgressSummaryResponse>(summary(client, ctx))
        assertEquals(1L, body.total_mistakes)
        assertEquals(mapOf("ghonna" to 1L), body.mistake_breakdown)
    }

    @Test
    fun `session detail for another user's session is not found, not leaked`() = progressApp { ctx ->
        val otherUser = UUID.randomUUID()
        val otherSession = SessionRepository.insert(otherUser, sura = 2, aya = 5, allCorrect = true)

        val resp = sessionDetail(client, ctx, otherSession)
        assertEquals(HttpStatusCode.NotFound, resp.status)
    }

    @Test
    fun `session detail for own session returns its mistakes`() = progressApp { ctx ->
        val sessionId = SessionRepository.insert(ctx.userId, sura = 3, aya = 7, allCorrect = false)
        MistakeRepository.insertBatch(sessionId, listOf(mistake("madd")))

        val body = decode<SessionDetailResponse>(sessionDetail(client, ctx, sessionId))
        assertEquals(sessionId.toString(), body.session_id)
        assertEquals(1, body.mistakes.size)
        assertEquals("madd", body.mistakes.single().rule_name_en)
    }

    @Test
    fun `malformed session id returns 404, not a server error`() = progressApp { ctx ->
        val resp = client.get("/progress/sessions/not-a-uuid") { header(HttpHeaders.Authorization, ctx.bearer()) }
        assertEquals(HttpStatusCode.NotFound, resp.status)
    }

    @Test
    fun `unknown but well-formed session id returns 404`() = progressApp { ctx ->
        assertEquals(HttpStatusCode.NotFound, sessionDetail(client, ctx, UUID.randomUUID()).status)
    }

    @Test
    fun `session list only returns the caller's own sessions`() = progressApp { ctx ->
        val otherUser = UUID.randomUUID()
        SessionRepository.insert(ctx.userId, sura = 1, aya = 1, allCorrect = true)
        SessionRepository.insert(otherUser, sura = 1, aya = 1, allCorrect = true)

        val body = decode<SessionListResponse>(client.get("/progress/sessions") { header(HttpHeaders.Authorization, ctx.bearer()) })
        assertEquals(1L, body.total)
        assertEquals(1, body.sessions.size)
    }

    @Test
    fun `limit above 100 is clamped to 100`() = progressApp { ctx ->
        val body = decode<SessionListResponse>(sessions(client, ctx, limit = "500"))
        assertEquals(100, body.limit)
    }

    @Test
    fun `limit below 1 is clamped to 1`() = progressApp { ctx ->
        val body = decode<SessionListResponse>(sessions(client, ctx, limit = "0"))
        assertEquals(1, body.limit)
    }

    @Test
    fun `non-numeric limit falls back to the default of 20`() = progressApp { ctx ->
        val body = decode<SessionListResponse>(sessions(client, ctx, limit = "banana"))
        assertEquals(20, body.limit)
    }

    @Test
    fun `negative offset is clamped to 0`() = progressApp { ctx ->
        val body = decode<SessionListResponse>(sessions(client, ctx, offset = "-5"))
        assertEquals(0, body.offset)
    }

    private fun mistake(ruleNameEn: String) = MistakeInput(
        charStart = 0, charEnd = 1, errorType = "tajweed",
        speechErrorType = null, ruleNameEn = ruleNameEn, ruleNameAr = null,
        expectedLen = null, predictedLen = null,
    )

    private class Ctx(val userId: UUID, private val tokenFor: (UUID) -> String) {
        fun bearer() = "Bearer ${tokenFor(userId)}"
    }

    private fun progressApp(block: suspend ApplicationTestBuilder.(Ctx) -> Unit) =
        TestJwks.withServer { issuer -> testApplication {
            install(ContentNegotiation) { json() }
            application {
                configureJwt(issuer)
                routing { authenticate("auth-jwt") { progressRoutes() } }
            }
            block(Ctx(UUID.randomUUID()) { uid -> TestJwks.token(issuer, subject = uid.toString()) })
        } }

    private suspend fun summary(client: HttpClient, ctx: Ctx): HttpResponse =
        client.get("/progress") { header(HttpHeaders.Authorization, ctx.bearer()) }

    private suspend fun sessionDetail(client: HttpClient, ctx: Ctx, sessionId: UUID): HttpResponse =
        client.get("/progress/sessions/$sessionId") { header(HttpHeaders.Authorization, ctx.bearer()) }

    private suspend fun sessions(client: HttpClient, ctx: Ctx, limit: String? = null, offset: String? = null): HttpResponse =
        client.get("/progress/sessions" + buildQuery(limit, offset)) { header(HttpHeaders.Authorization, ctx.bearer()) }

    private fun buildQuery(limit: String?, offset: String?): String {
        val params = listOfNotNull(limit?.let { "limit=$it" }, offset?.let { "offset=$it" })
        return if (params.isEmpty()) "" else "?" + params.joinToString("&")
    }

    private suspend inline fun <reified T> decode(resp: HttpResponse): T =
        testJson.decodeFromString(resp.bodyAsText())
}
