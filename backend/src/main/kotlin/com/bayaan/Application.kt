package com.bayaan

import com.bayaan.plugins.configureJwt
import com.bayaan.routes.analyzeRoute
import com.bayaan.routes.authRoutes
import com.bayaan.routes.progressRoutes
import com.bayaan.routes.surahRoutes
import io.ktor.serialization.kotlinx.json.*
import io.ktor.server.application.*
import io.ktor.server.auth.*
import io.ktor.server.plugins.contentnegotiation.*
import io.ktor.server.routing.*

fun main(args: Array<String>) {
    io.ktor.server.netty.EngineMain.main(args)
}

fun Application.module() {
    configureJwt()
    install(ContentNegotiation) { json() }
    routing {
        healthRoute()
        surahRoutes()
        authenticate("auth-jwt") {
            authRoutes()
            analyzeRoute()
            progressRoutes()
        }
    }
}
