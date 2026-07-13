package com.bayaan.data.tables

import org.jetbrains.exposed.sql.ReferenceOption
import org.jetbrains.exposed.sql.Table
import org.jetbrains.exposed.sql.kotlin.datetime.CurrentTimestamp
import org.jetbrains.exposed.sql.kotlin.datetime.timestamp

object LessonAttempts : Table("lesson_attempts") {
    val id = uuid("id")
    val userId = reference("user_id", Users.id, onDelete = ReferenceOption.CASCADE)
    val lessonId = text("lesson_id")
    val score = decimal("score", 4, 3)
    val itemResults = text("item_results") // JSON-as-text
    val coachSummary = text("coach_summary").nullable() // reserved; unused in MVP
    val createdAt = timestamp("created_at").defaultExpression(CurrentTimestamp)

    override val primaryKey = PrimaryKey(id)
}
