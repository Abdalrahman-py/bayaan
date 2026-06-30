package com.bayaan.plugins

import io.ktor.server.application.ApplicationCall
import io.ktor.server.auth.principal
import io.ktor.server.auth.jwt.JWTPrincipal
import java.util.UUID

// Safe inside authenticate("auth-jwt"): Ktor's JWT middleware guarantees non-null principal
// and Supabase always uses UUID v4 as the subject.
fun ApplicationCall.userId(): UUID =
    UUID.fromString(principal<JWTPrincipal>()!!.payload.subject)
