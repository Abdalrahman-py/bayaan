package com.bayaan.data

import com.zaxxer.hikari.HikariConfig
import com.zaxxer.hikari.HikariDataSource
import kotlinx.coroutines.Dispatchers
import org.jetbrains.exposed.sql.Database
import org.jetbrains.exposed.sql.transactions.experimental.newSuspendedTransaction
import javax.sql.DataSource

object DatabaseFactory {


    internal var testDataSource: DataSource? = null

    private val dataSource: DataSource by lazy {
        testDataSource ?: run {
            val config = HikariConfig().apply {
                jdbcUrl = System.getenv("SUPABASE_DB_URL")
                    ?: throw IllegalStateException("SUPABASE_DB_URL env var is required")
                driverClassName = "org.postgresql.Driver"
                maximumPoolSize = 10
                isAutoCommit = false
                transactionIsolation = "TRANSACTION_READ_COMMITTED"
                validate()
            }
            HikariDataSource(config)
        }
    }

    private val db by lazy { Database.connect(dataSource) }

    suspend fun <T> dbQuery(block: suspend () -> T): T {
        db // trigger lazy init on first real DB call
        return newSuspendedTransaction(Dispatchers.IO) { block() }
    }
}
