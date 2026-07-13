package com.bayaan.data.tables

import org.jetbrains.exposed.sql.ReferenceOption
import org.jetbrains.exposed.sql.Table
import org.jetbrains.exposed.sql.kotlin.datetime.CurrentTimestamp
import org.jetbrains.exposed.sql.kotlin.datetime.timestamp

// Mirrors Mistakes: the engine returns sifat_errors, which EngineResponseParser must
// parse and persist here so /progress can expose a sifat_breakdown.
object SifatMistakes : Table("sifat_mistakes") {
    val id = uuid("id")
    val sessionId = reference("session_id", Sessions.id, onDelete = ReferenceOption.CASCADE)
    val phonemesGroup = text("phonemes_group")
    val attribute = text("attribute")
    val predicted = text("predicted")
    val expected = text("expected")
    val confidence = decimal("confidence", 6, 3).nullable()
    val createdAt = timestamp("created_at").defaultExpression(CurrentTimestamp)

    override val primaryKey = PrimaryKey(id)
}
