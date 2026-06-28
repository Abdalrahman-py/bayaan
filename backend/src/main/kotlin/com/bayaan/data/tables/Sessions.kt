package com.bayaan.data.tables

import org.jetbrains.exposed.sql.ReferenceOption
import org.jetbrains.exposed.sql.Table
import org.jetbrains.exposed.sql.kotlin.datetime.CurrentTimestamp
import org.jetbrains.exposed.sql.kotlin.datetime.timestamp

object Sessions : Table("sessions") {
    val id = uuid("id")
    val userId = reference("user_id", Users.id, onDelete = ReferenceOption.CASCADE)
    val sura = integer("sura")
    val aya = integer("aya")
    val allCorrect = bool("all_correct")
    val createdAt = timestamp("created_at").defaultExpression(CurrentTimestamp)

    override val primaryKey = PrimaryKey(id)
}
