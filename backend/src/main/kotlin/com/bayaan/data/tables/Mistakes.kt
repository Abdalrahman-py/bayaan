package com.bayaan.data.tables

import org.jetbrains.exposed.sql.Table
import org.jetbrains.exposed.sql.kotlin.datetime.CurrentTimestamp
import org.jetbrains.exposed.sql.kotlin.datetime.timestamp

object Mistakes : Table("mistakes") {
    val id = uuid("id")
    val sessionId = reference("session_id", Sessions.id)
    val charStart = integer("char_start")
    val charEnd = integer("char_end")
    val errorType = text("error_type")
    val speechErrorType = text("speech_error_type").nullable()
    val ruleNameEn = text("rule_name_en").nullable()
    val ruleNameAr = text("rule_name_ar").nullable()
    val expectedLen = integer("expected_len").nullable()
    val predictedLen = integer("predicted_len").nullable()
    val createdAt = timestamp("created_at").defaultExpression(CurrentTimestamp)

    override val primaryKey = PrimaryKey(id)
}
