package com.bayaan.routes

import io.ktor.http.*
import io.ktor.server.response.*
import io.ktor.server.routing.*

fun Route.surahRoutes() {
    get("/surahs") {
        call.respondText(
            """{"surahs":[{"number":1,"name_arabic":"الفاتحة","name_english":"Al-Fatihah","verse_count":7,"available":true},{"number":98,"name_arabic":"البينة","name_english":"Al-Bayyinah","verse_count":8,"available":true}]}""",
            ContentType.Application.Json
        )
    }
}
