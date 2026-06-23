package com.bayaan

import io.ktor.client.request.forms.MultiPartFormDataContent
import io.ktor.client.request.forms.formData
import io.ktor.client.request.get
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.http.HttpStatusCode
import io.ktor.server.testing.testApplication
import kotlin.test.Test
import kotlin.test.assertEquals

class ServerTest {

    @Test
    fun `health returns ok`() = testApplication {
        application { configureRouting() }
        assertEquals(HttpStatusCode.OK, client.get("/health").status)
    }

    // Boundary check: no audio part -> 400, without touching the engine.
    @Test
    fun `analyze without audio is bad request`() = testApplication {
        application { configureRouting() }
        val response = client.post("/audio/analyze") {
            setBody(MultiPartFormDataContent(formData { append("sura", "1") }))
        }
        assertEquals(HttpStatusCode.BadRequest, response.status)
    }
}
