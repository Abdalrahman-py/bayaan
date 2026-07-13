package com.bayaan.data.tables

import java.math.BigDecimal
import org.jetbrains.exposed.sql.ReferenceOption
import org.jetbrains.exposed.sql.Table
import org.jetbrains.exposed.sql.kotlin.datetime.date

object ReviewItems : Table("review_items") {
    val id = uuid("id")
    val userId = reference("user_id", Users.id, onDelete = ReferenceOption.CASCADE)
    val itemRef = text("item_ref")
    val ease = decimal("ease", 3, 2).default(BigDecimal("2.5")) // reserved; unused by MVP ladder
    val intervalDays = integer("interval_days").default(1)
    val dueOn = date("due_on")
    val lapses = integer("lapses").default(0)

    override val primaryKey = PrimaryKey(id)

    init {
        uniqueIndex(userId, itemRef)
    }
}
