package com.bayaan.data.tables

import org.jetbrains.exposed.sql.ReferenceOption
import org.jetbrains.exposed.sql.Table
import org.jetbrains.exposed.sql.kotlin.datetime.CurrentTimestamp
import org.jetbrains.exposed.sql.kotlin.datetime.timestamp

object XpEvents : Table("xp_events") {
    val id = uuid("id")
    val userId = reference("user_id", Users.id, onDelete = ReferenceOption.CASCADE)
    val amount = integer("amount")
    val reason = text("reason")
    val createdAt = timestamp("created_at").defaultExpression(CurrentTimestamp)

    override val primaryKey = PrimaryKey(id)
}
