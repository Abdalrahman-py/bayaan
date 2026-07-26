package com.bayaan

import com.bayaan.data.DatabaseFactory
import com.bayaan.data.tables.LessonAttempts
import com.bayaan.data.tables.LessonProgress
import com.bayaan.data.tables.PlacementResults
import com.bayaan.data.tables.Profiles
import com.bayaan.data.tables.ReviewItems
import com.bayaan.data.tables.Users
import com.bayaan.data.tables.XpEvents
import com.zaxxer.hikari.HikariConfig
import com.zaxxer.hikari.HikariDataSource
import kotlinx.coroutines.runBlocking
import org.jetbrains.exposed.sql.SchemaUtils

/**
 * In-memory H2 (PostgreSQL compatibility mode) standing in for Supabase Postgres in
 * tests. Schema comes from the real Exposed `Table` objects — not hand-copied SQL —
 * so a column added to `data/tables/` (any .kt file) is picked up here for free, no drift.
 *
 * One H2 instance per JVM test run (DB_CLOSE_DELAY=-1 keeps it alive between tests);
 * call `reset()` in a `@BeforeTest` to isolate test cases.
*/
object TestDatabase {
private val LEARN_TABLES = arrayOf(
Users, Profiles, PlacementResults, LessonProgress, LessonAttempts, ReviewItems, XpEvents,
)

private var installed = false

@Synchronized
fun install() {
if (installed) return
val config = HikariConfig().apply {
jdbcUrl = "jdbc:h2:mem:bayaan_test;MODE=PostgreSQL;DB_CLOSE_DELAY=-1"
driverClassName = "org.h2.Driver"
maximumPoolSize = 5
isAutoCommit = false
}
DatabaseFactory.testDataSource = HikariDataSource(config)
installed = true
runBlocking { DatabaseFactory.dbQuery { SchemaUtils.create(*LEARN_TABLES) } }
}

// Wipes all rows between tests — cheap enough at this table count, keeps tests
// independent without spinning up a fresh container per test.
fun reset() = runBlocking {
DatabaseFactory.dbQuery {
SchemaUtils.drop(*LEARN_TABLES.reversedArray())
SchemaUtils.create(*LEARN_TABLES)
}
}
}
