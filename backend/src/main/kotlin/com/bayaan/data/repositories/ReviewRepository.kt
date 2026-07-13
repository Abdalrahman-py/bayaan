package com.bayaan.data.repositories

import com.bayaan.data.DatabaseFactory
import com.bayaan.data.tables.ReviewItems
import kotlinx.datetime.Clock
import kotlinx.datetime.DateTimeUnit
import kotlinx.datetime.LocalDate
import kotlinx.datetime.TimeZone
import kotlinx.datetime.plus
import kotlinx.datetime.todayIn
import org.jetbrains.exposed.sql.*
import java.util.UUID

data class ReviewItem(
    val id: UUID,
    val userId: UUID,
    val itemRef: String,
    val intervalDays: Int,
    val lapses: Int,
    val dueOn: LocalDate,
)

// SM-2-lite ladder from PRODUCTION_PLAN.md §4.x: intervals 1, 3, 7, 21 days. `ease` is
// a reserved column, unused by this ladder (see 0001_mvp_learn_tables.sql).
object ReviewRepository {
    private val LADDER = listOf(1, 3, 7, 21)
    private fun today() = Clock.System.todayIn(TimeZone.UTC)

    suspend fun due(userId: UUID, limit: Int = 20): List<ReviewItem> = DatabaseFactory.dbQuery {
        val day = today()
        ReviewItems.selectAll()
            .where { (ReviewItems.userId eq userId) and (ReviewItems.dueOn lessEq day) }
            .orderBy(ReviewItems.dueOn to SortOrder.ASC)
            .limit(limit)
            .map { it.toReviewItem() }
    }

    suspend fun dueCount(userId: UUID): Int = DatabaseFactory.dbQuery {
        val day = today()
        ReviewItems.selectAll()
            .where { (ReviewItems.userId eq userId) and (ReviewItems.dueOn lessEq day) }
            .count().toInt()
    }

    // Called from /learn/complete for each missed item_ref. Leaves an item's ladder
    // position alone if it's already queued — only seeds new items.
    suspend fun pushWeak(userId: UUID, itemRefs: List<String>) = DatabaseFactory.dbQuery {
        ProfileRepository.ensure(userId)
        val tomorrow = today().plus(1, DateTimeUnit.DAY)
        for (ref in itemRefs) {
            val exists = ReviewItems.selectAll()
                .where { (ReviewItems.userId eq userId) and (ReviewItems.itemRef eq ref) }
                .singleOrNull() != null
            if (!exists) {
                ReviewItems.insert {
                    it[id] = UUID.randomUUID()
                    it[ReviewItems.userId] = userId
                    it[itemRef] = ref
                    it[intervalDays] = LADDER.first()
                    it[dueOn] = tomorrow
                }
            }
        }
    }

    suspend fun findOwned(userId: UUID, reviewId: UUID): ReviewItem? = DatabaseFactory.dbQuery {
        ReviewItems.selectAll()
            .where { (ReviewItems.id eq reviewId) and (ReviewItems.userId eq userId) }
            .singleOrNull()?.toReviewItem()
    }

    suspend fun recordResult(userId: UUID, reviewId: UUID, correct: Boolean): ReviewItem? = DatabaseFactory.dbQuery {
        val current = findOwned(userId, reviewId) ?: return@dbQuery null
        val day = today()
        val newInterval: Int
        val newLapses: Int
        if (correct) {
            val idx = LADDER.indexOf(current.intervalDays)
            newInterval = if (idx == -1 || idx == LADDER.lastIndex) LADDER.last() else LADDER[idx + 1]
            newLapses = current.lapses
        } else {
            newInterval = LADDER.first()
            newLapses = current.lapses + 1
        }
        val newDue = day.plus(newInterval, DateTimeUnit.DAY)
        ReviewItems.update({ ReviewItems.id eq reviewId }) {
            it[intervalDays] = newInterval
            it[dueOn] = newDue
            it[lapses] = newLapses
        }
        current.copy(intervalDays = newInterval, lapses = newLapses, dueOn = newDue)
    }

    private fun ResultRow.toReviewItem() = ReviewItem(
        id = this[ReviewItems.id],
        userId = this[ReviewItems.userId],
        itemRef = this[ReviewItems.itemRef],
        intervalDays = this[ReviewItems.intervalDays],
        lapses = this[ReviewItems.lapses],
        dueOn = this[ReviewItems.dueOn],
    )
}
