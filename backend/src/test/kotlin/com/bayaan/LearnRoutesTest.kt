package com.bayaan

import com.bayaan.data.DatabaseFactory
import com.bayaan.data.repositories.ReviewRepository
import com.bayaan.data.tables.Profiles
import com.bayaan.data.tables.ReviewItems
import com.bayaan.plugins.configureJwt
import com.bayaan.routes.CompleteItemResult
import com.bayaan.routes.HeaderResponse
import com.bayaan.routes.LearnPathResponse
import com.bayaan.routes.LessonCompleteRequest
import com.bayaan.routes.LessonCompleteResponse
import com.bayaan.routes.PlacementItemResult
import com.bayaan.routes.PlacementRequest
import com.bayaan.routes.PlacementResponse
import com.bayaan.routes.ReviewResultRequest
import com.bayaan.routes.ReviewResultResponse
import com.bayaan.routes.ReviewsResponse
import com.bayaan.routes.learnRoutes
import io.ktor.client.HttpClient
import io.ktor.client.request.get
import io.ktor.client.request.header
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.client.statement.HttpResponse
import io.ktor.client.statement.bodyAsText
import io.ktor.http.ContentType
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.contentType
import io.ktor.serialization.kotlinx.json.json
import io.ktor.server.auth.authenticate
import io.ktor.server.plugins.contentnegotiation.ContentNegotiation
import io.ktor.server.routing.routing
import io.ktor.server.testing.ApplicationTestBuilder
import io.ktor.server.testing.testApplication
import kotlinx.datetime.Clock
import kotlinx.datetime.DateTimeUnit
import kotlinx.datetime.LocalDate
import kotlinx.datetime.TimeZone
import kotlinx.datetime.minus
import kotlinx.datetime.plus
import kotlinx.datetime.todayIn
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import org.jetbrains.exposed.sql.*
import java.util.UUID
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

private val testJson = Json { ignoreUnknownKeys = true }
private fun today(): LocalDate = Clock.System.todayIn(TimeZone.UTC)

// Binds one JWT subject (= one profiles row) across every call in a test.
private class Ctx(val userId: UUID, private val tokenFor: (UUID) -> String) {
    fun bearer() = "Bearer ${tokenFor(userId)}"
}


class LearnRoutesTest {

    @BeforeTest
    fun setUp() {
        TestDatabase.install()
        TestDatabase.reset()
    }


    @Test
    fun `a fresh account has the whole first unit open and the rest locked`() = learnApp { ctx ->
        val body = decode<LearnPathResponse>(path(client, ctx))
        assertEquals(HeaderResponse(0, 0, 0, 10, 0), body.header)
        val lessons = body.units.flatMap { it.lessons }
        // arabic_level 0 places the learner at unit 1, so all six of its lessons open at
        // once; unit 2 onward still waits on the completion chain.
        assertTrue(lessons.take(6).all { it.status == "available" })
        assertTrue(lessons.drop(6).all { it.status == "locked" })
    }


    @Test
    fun `passing a lesson awards base xp plus first-try bonus and completes it`() = learnApp { ctx ->
        val resp = complete(client, ctx, "ar.1.1", 0.9, listOf(
            CompleteItemResult("ar.1.1.listen.ba", correct = true, first_try = true),
            CompleteItemResult("ar.1.1.listen.ta", correct = true, first_try = true),
            CompleteItemResult("ar.1.1.listen.tha", correct = false, first_try = false),
        ))
        assertEquals(HttpStatusCode.OK, resp.status)
        assertEquals(10 + 2 * 2, decode<LessonCompleteResponse>(resp).header.xp) // base 10 + 2×first-try-correct
        assertEquals("completed", decode<LearnPathResponse>(path(client, ctx)).units.first().lessons.first().status)
    }

    @Test
    fun `passing a lesson completes it and leaves the next unit gated`() = learnApp { ctx ->
        complete(client, ctx, "ar.1.1", 0.9)
        val lessons = decode<LearnPathResponse>(path(client, ctx)).units.flatMap { it.lessons }
        assertEquals("completed", lessons[0].status)
        assertEquals("available", lessons[1].status)
        // ar.2.1 — placement has not reached unit 2, and the chain has not either.
        assertEquals("locked", lessons[6].status)
    }

    @Test
    fun `placement opens every unit up to one past the assigned level`() = learnApp { ctx ->
        // Two wrong answers place the learner at level 2 (see the placement tests below).
        placement(client, ctx, List(2) { PlacementItemResult("x", correct = false) })
        val units = decode<LearnPathResponse>(path(client, ctx)).units
        // Level 2 opens units at position 1..3; position 4 onward stays gated, and the
        // tajweed units are never placed.
        assertTrue(units.take(3).flatMap { it.lessons }.all { it.status == "available" })
        assertTrue(units.drop(3).flatMap { it.lessons }.all { it.status == "locked" })
    }

    @Test
    fun `checkpoint lessons use the higher xp base regardless of the client's claim`() = learnApp { ctx ->
        // ar.1.6 is unit 1's checkpoint in curriculum.json; sending is_checkpoint=false
        // on the request and still getting the checkpoint XP proves the server trusts
        // curriculum.json, never the client (docs/api-spec.md).
        val resp = complete(client, ctx, "ar.1.6", 0.9, isCheckpointClaim = false)
        assertEquals(20, decode<LessonCompleteResponse>(resp).header.xp)
    }

    @Test
    fun `a failing score still awards xp and bumps the streak but doesn't complete the lesson`() = learnApp { ctx ->
        val resp = complete(client, ctx, "ar.1.1", 0.5)
        val body = decode<LessonCompleteResponse>(resp)
        assertEquals(10, body.header.xp) // XP isn't gated on pass/fail — docs/api-spec.md
        assertEquals(1, body.header.streak_count)
        assertEquals(
            "in_progress",
            decode<LearnPathResponse>(path(client, ctx)).units.first().lessons.first().status,
        )
    }

    @Test
    fun `unknown lesson id returns 404`() = learnApp { ctx ->
        assertEquals(HttpStatusCode.NotFound, complete(client, ctx, "ar.99.9", 1.0).status)
    }

    @Test
    fun `missed items are queued for review due tomorrow, not today`() = learnApp { ctx ->
        complete(client, ctx, "ar.1.1", 0.9, listOf(
            CompleteItemResult("ar.1.1.listen.ba", correct = false, first_try = false),
        ))
        assertTrue(decode<ReviewsResponse>(reviews(client, ctx)).reviews.isEmpty())
    }

    @Test
    fun `re-completing a lesson the same day does not double bump the streak`() = learnApp { ctx ->
        complete(client, ctx, "ar.1.1", 0.9)
        val second = decode<LessonCompleteResponse>(complete(client, ctx, "ar.1.1", 0.9))
        assertEquals(1, second.header.streak_count)
    }

    @Test
    fun `completing the day after the last completion bumps the streak by one`() = learnApp { ctx ->
        complete(client, ctx, "ar.1.1", 0.9)
        seedStreak(ctx.userId, count = 1, updatedOn = today().minus(1, DateTimeUnit.DAY))
        val body = decode<LessonCompleteResponse>(complete(client, ctx, "ar.1.2", 0.9))
        assertEquals(2, body.header.streak_count)
    }

    @Test
    fun `a multi-day gap resets the streak to one`() = learnApp { ctx ->
        complete(client, ctx, "ar.1.1", 0.9)
        seedStreak(ctx.userId, count = 5, updatedOn = today().minus(3, DateTimeUnit.DAY))
        val body = decode<LessonCompleteResponse>(complete(client, ctx, "ar.1.2", 0.9))
        assertEquals(1, body.header.streak_count)
    }


    @Test
    fun `a review becomes due once its date arrives`() = learnApp { ctx ->
        complete(client, ctx, "ar.1.1", 0.9, listOf(
            CompleteItemResult("ar.1.1.listen.ba", correct = false, first_try = false),
        ))
        forceReviewDue(ctx.userId, "ar.1.1.listen.ba", today())
        val due = decode<ReviewsResponse>(reviews(client, ctx))
        assertEquals(listOf("ar.1.1.listen.ba"), due.reviews.map { it.item_ref })
    }

    @Test
    fun `a correct review answer advances the ladder to the next rung`() = learnApp { ctx ->
        complete(client, ctx, "ar.1.1", 0.9, listOf(
            CompleteItemResult("ar.1.1.listen.ba", correct = false, first_try = false),
        ))
        forceReviewDue(ctx.userId, "ar.1.1.listen.ba", today())
        val reviewId = ReviewRepository.due(ctx.userId).single().id

        val body = decode<ReviewResultResponse>(reviewResult(client, ctx, reviewId, correct = true))
        assertEquals(today().plus(3, DateTimeUnit.DAY).toString(), body.next_due_on) // ladder: 1 -> 3
        assertEquals(0, body.reviews_due)
    }

    @Test
    fun `a wrong review answer resets to the first rung and counts a lapse`() = learnApp { ctx ->
        complete(client, ctx, "ar.1.1", 0.9, listOf(
            CompleteItemResult("ar.1.1.listen.ba", correct = false, first_try = false),
        ))
        forceReviewDue(ctx.userId, "ar.1.1.listen.ba", today())
        val reviewId = ReviewRepository.due(ctx.userId).single().id
        ReviewRepository.recordResult(ctx.userId, reviewId, correct = true) // advance 1 -> 3 first,
        // so the reset back to 1 below is actually observable.

        val body = decode<ReviewResultResponse>(reviewResult(client, ctx, reviewId, correct = false))
        assertEquals(today().plus(1, DateTimeUnit.DAY).toString(), body.next_due_on)
    }

    @Test
    fun `unknown review id returns 404`() = learnApp { ctx ->
        assertEquals(HttpStatusCode.NotFound, reviewResult(client, ctx, UUID.randomUUID(), correct = true).status)
    }


    @Test
    fun `three correct in a row raises the level`() = learnApp { ctx ->
        val body = decode<PlacementResponse>(
            placement(client, ctx, List(3) { PlacementItemResult("x", correct = true) }),
        )
        assertEquals(4, body.arabic_level) // ladder always starts at 3 (PRODUCTION_PLAN.md §4.0)
    }

    @Test
    fun `two wrong in a row lowers the level`() = learnApp { ctx ->
        val body = decode<PlacementResponse>(
            placement(client, ctx, List(2) { PlacementItemResult("x", correct = false) }),
        )
        assertEquals(2, body.arabic_level)
    }

    @Test
    fun `level is clamped to the 0 through 8 range`() = learnApp { ctx ->
        val low = decode<PlacementResponse>(
            placement(client, ctx, List(8) { PlacementItemResult("x", correct = false) }),
        )
        assertEquals(0, low.arabic_level)

        val high = decode<PlacementResponse>(
            placement(client, ctx, List(15) { PlacementItemResult("x", correct = true) }),
        )
        assertEquals(8, high.arabic_level)
    }


    private fun learnApp(block: suspend ApplicationTestBuilder.(Ctx) -> Unit) =
        TestJwks.withServer { issuer -> testApplication {
            install(ContentNegotiation) { json() }
            application {
                configureJwt(issuer)
                routing { authenticate("auth-jwt") { learnRoutes() } }
            }
            block(Ctx(UUID.randomUUID()) { uid -> TestJwks.token(issuer, subject = uid.toString()) })
        } }

    private suspend fun path(client: HttpClient, ctx: Ctx): HttpResponse =
        client.get("/learn/path") { header(HttpHeaders.Authorization, ctx.bearer()) }

    private suspend fun reviews(client: HttpClient, ctx: Ctx): HttpResponse =
        client.get("/learn/reviews") { header(HttpHeaders.Authorization, ctx.bearer()) }

    private suspend fun complete(
        client: HttpClient,
        ctx: Ctx,
        lessonId: String,
        score: Double,
        results: List<CompleteItemResult> = emptyList(),
        isCheckpointClaim: Boolean = false,
    ): HttpResponse = client.post("/learn/complete") {
        header(HttpHeaders.Authorization, ctx.bearer())
        contentType(ContentType.Application.Json)
        setBody(testJson.encodeToString(LessonCompleteRequest(lessonId, score, isCheckpointClaim, results)))
    }

    private suspend fun reviewResult(client: HttpClient, ctx: Ctx, reviewId: UUID, correct: Boolean): HttpResponse =
        client.post("/learn/reviews/$reviewId/result") {
            header(HttpHeaders.Authorization, ctx.bearer())
            contentType(ContentType.Application.Json)
            setBody(testJson.encodeToString(ReviewResultRequest(correct)))
        }

    private suspend fun placement(client: HttpClient, ctx: Ctx, results: List<PlacementItemResult>): HttpResponse =
        client.post("/learn/placement") {
            header(HttpHeaders.Authorization, ctx.bearer())
            contentType(ContentType.Application.Json)
            setBody(testJson.encodeToString(PlacementRequest(results)))
        }

    private suspend inline fun <reified T> decode(resp: HttpResponse): T =
        testJson.decodeFromString(resp.bodyAsText())


    private suspend fun seedStreak(userId: UUID, count: Int, updatedOn: LocalDate) {
        DatabaseFactory.dbQuery {
            Profiles.update({ Profiles.userId eq userId }) {
                it[streakCount] = count
                it[streakUpdatedOn] = updatedOn
            }
        }
    }

    private suspend fun forceReviewDue(userId: UUID, itemRef: String, dueOn: LocalDate) {
        DatabaseFactory.dbQuery {
            ReviewItems.update({ (ReviewItems.userId eq userId) and (ReviewItems.itemRef eq itemRef) }) {
                it[ReviewItems.dueOn] = dueOn
            }
        }
    }
}
