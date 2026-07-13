package com.bayaan.data.tables

import java.math.BigDecimal
import org.jetbrains.exposed.sql.ReferenceOption
import org.jetbrains.exposed.sql.Table
import org.jetbrains.exposed.sql.kotlin.datetime.timestamp

object LessonProgress : Table("lesson_progress") {
    val userId = reference("user_id", Users.id, onDelete = ReferenceOption.CASCADE)
    val lessonId = text("lesson_id")
    // 'in_progress' | 'completed' — locked/available are derived at read (see /learn/path).
    val status = text("status")
    val bestScore = decimal("best_score", 4, 3).default(BigDecimal.ZERO)
    val attempts = integer("attempts").default(0)
    val completedAt = timestamp("completed_at").nullable()

    override val primaryKey = PrimaryKey(userId, lessonId)
}
