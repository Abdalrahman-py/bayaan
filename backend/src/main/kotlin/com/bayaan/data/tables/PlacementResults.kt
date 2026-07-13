package com.bayaan.data.tables

import org.jetbrains.exposed.sql.ReferenceOption
import org.jetbrains.exposed.sql.Table
import org.jetbrains.exposed.sql.kotlin.datetime.CurrentTimestamp
import org.jetbrains.exposed.sql.kotlin.datetime.timestamp

object PlacementResults : Table("placement_results") {
    val id = uuid("id")
    val userId = reference("user_id", Users.id, onDelete = ReferenceOption.CASCADE)
    val level = integer("level")
    val items = text("items") // JSON-as-text (audit blob; never queried)
    val createdAt = timestamp("created_at").defaultExpression(CurrentTimestamp)

    override val primaryKey = PrimaryKey(id)
}
