package com.bayaan.data.tables

import org.jetbrains.exposed.sql.ReferenceOption
import org.jetbrains.exposed.sql.Table
import org.jetbrains.exposed.sql.kotlin.datetime.CurrentTimestamp
import org.jetbrains.exposed.sql.kotlin.datetime.date
import org.jetbrains.exposed.sql.kotlin.datetime.timestamp

object Profiles : Table("profiles") {
    val userId = reference("user_id", Users.id, onDelete = ReferenceOption.CASCADE)
    val arabicLevel = integer("arabic_level").default(0)
    val xp = integer("xp").default(0)
    val streakCount = integer("streak_count").default(0)
    val streakUpdatedOn = date("streak_updated_on").nullable()
    val dailyGoalMinutes = integer("daily_goal_minutes").default(10)
    val createdAt = timestamp("created_at").defaultExpression(CurrentTimestamp)
    val updatedAt = timestamp("updated_at").defaultExpression(CurrentTimestamp)

    override val primaryKey = PrimaryKey(userId)
}
