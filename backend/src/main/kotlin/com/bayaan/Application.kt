package com.bayaan

import com.bayaan.data.DatabaseFactory
import com.bayaan.plugins.configureJwt
import com.bayaan.routes.authRoutes
import io.ktor.server.application.*
import io.ktor.server.auth.*
import io.ktor.server.routing.*

fun main(args: Array<String>) {
    io.ktor.server.netty.EngineMain.main(args)
}

fun Application.module() {
    configureJwt()
    DatabaseFactory.connect()
    routing {
        healthRoute()
        authenticate("auth-jwt") {
            authRoutes()
            analyzeRoute()
        }
    }
}
