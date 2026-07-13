package com.bayaan.data.repositories

import com.bayaan.data.DatabaseFactory
import com.bayaan.data.tables.PlacementResults
import com.bayaan.data.tables.Profiles
import com.bayaan.data.tables.XpEvents
import kotlinx.datetime.Clock
import kotlinx.datetime.DateTimeUnit
import kotlinx.datetime.LocalDate
import kotlinx.datetime.TimeZone
import kotlinx.datetime.minus
import kotlinx.datetime.todayIn
import org.jetbrains.exposed.sql.*
import java.util.UUID

data class Profile(
    val userId: UUID,
    val arabicLevel: Int,
    val xp: Int,
    val streakCount: Int,
    val streakUpdatedOn: LocalDate?,
    val dailyGoalMinutes: Int
)

// Owns `profiles` + the two tables always mutated alongside it: `xp_events` (an XP
// change is always a profile.xp change) and `placement_results` (a placement is
// always a profiles.arabic_level change).
object ProfileRepository {

    // Streak day boundary: UTC calendar date, not the user's local day. Simplest rule
    // that's still correct for "increments across a real day boundary" (§10 M4 accept);
    // ponytail: per-user timezone tracking is real complexity for a cosmetic feature —
    // revisit only if users report a streak break at the wrong local midnight.
    private fun today(): LocalDate = Clock.System.todayIn(TimeZone.UTC)

    suspend fun ensure(userId: UUID): Profile = DatabaseFactory.dbQuery {
        UserRepository.upsert(userId)
        val existing = Profiles.selectAll().where { Profiles.userId eq userId }.singleOrNull()
        if (existing != null) return@dbQuery existing.toProfile()
        Profiles.insert { it[Profiles.userId] = userId }
        Profiles.selectAll().where { Profiles.userId eq userId }.single().toProfile()
    }

    suspend fun get(userId: UUID): Profile? = DatabaseFactory.dbQuery {
        Profiles.selectAll().where { Profiles.userId eq userId }.singleOrNull()?.toProfile()
    }

    suspend fun addXp(userId: UUID, amount: Int, reason: String): Profile = DatabaseFactory.dbQuery {
        val current = ensure(userId)
        XpEvents.insert {
            it[id] = UUID.randomUUID()
            it[XpEvents.userId] = userId
            it[XpEvents.amount] = amount
            it[XpEvents.reason] = reason
        }
        Profiles.update({ Profiles.userId eq userId }) {
            it[xp] = current.xp + amount
            it[updatedAt] = Clock.System.now()
        }
        Profiles.selectAll().where { Profiles.userId eq userId }.single().toProfile()
    }

    // Bumps streak_count by 1 the first time a lesson completes on a new UTC day
    // (yesterday -> today), resets to 1 after a gap, no-ops for a second completion
    // the same day.
    suspend fun bumpStreak(userId: UUID): Profile = DatabaseFactory.dbQuery {
        val profile = ensure(userId)
        val day = today()
        val newCount = when (profile.streakUpdatedOn) {
            day -> profile.streakCount
            day.minus(1, DateTimeUnit.DAY) -> profile.streakCount + 1
            else -> 1
        }
        Profiles.update({ Profiles.userId eq userId }) {
            it[streakCount] = newCount
            it[streakUpdatedOn] = day
            it[updatedAt] = Clock.System.now()
        }
        Profiles.selectAll().where { Profiles.userId eq userId }.single().toProfile()
    }

    suspend fun recordPlacement(userId: UUID, level: Int, itemsJson: String): Profile = DatabaseFactory.dbQuery {
        ensure(userId)
        PlacementResults.insert {
            it[id] = UUID.randomUUID()
            it[PlacementResults.userId] = userId
            it[PlacementResults.level] = level
            it[items] = itemsJson
        }
        Profiles.update({ Profiles.userId eq userId }) {
            it[arabicLevel] = level
            it[updatedAt] = Clock.System.now()
        }
        Profiles.selectAll().where { Profiles.userId eq userId }.single().toProfile()
    }

    private fun ResultRow.toProfile() = Profile(
        userId = this[Profiles.userId],
        arabicLevel = this[Profiles.arabicLevel],
        xp = this[Profiles.xp],
        streakCount = this[Profiles.streakCount],
        streakUpdatedOn = this[Profiles.streakUpdatedOn],
        dailyGoalMinutes = this[Profiles.dailyGoalMinutes]
    )
}
