package com.bayaan

import com.auth0.jwt.JWT
import com.auth0.jwt.algorithms.Algorithm
import com.sun.net.httpserver.HttpServer
import java.math.BigInteger
import java.net.InetSocketAddress
import java.security.KeyPairGenerator
import java.security.interfaces.ECPrivateKey
import java.security.interfaces.ECPublicKey
import java.security.spec.ECGenParameterSpec
import java.util.Base64
import java.util.Date
import java.util.UUID

// Exercises the real JwtPlugin verification path (JWKS fetch + ES256) instead of the
// HS256 shared-secret scheme Supabase moved off of in 706df94 — serves a real JWKS
// document for a throwaway EC keypair over a local loopback HTTP server.
object TestJwks {
    private const val KEY_ID = "test-key-1"

    private val keyPair = KeyPairGenerator.getInstance("EC")
        .apply { initialize(ECGenParameterSpec("secp256r1")) }
        .generateKeyPair()
    private val publicKey = keyPair.public as ECPublicKey
    private val privateKey = keyPair.private as ECPrivateKey
    private val algorithm: Algorithm = Algorithm.ECDSA256(publicKey, privateKey)

    // P-256 coordinates must be exactly 32 bytes, left-padded with zeros — BigInteger's
    // own toByteArray() drops leading zeros and may prepend a sign byte.
    private fun coordinate(value: BigInteger): String {
        val raw = value.toByteArray()
        val trimmed = if (raw.size > 32) raw.copyOfRange(raw.size - 32, raw.size) else raw
        val padded = ByteArray(32 - trimmed.size) + trimmed
        return Base64.getUrlEncoder().withoutPadding().encodeToString(padded)
    }

    private val jwksJson = """
        {"keys":[{"kty":"EC","crv":"P-256","kid":"$KEY_ID","use":"sig","alg":"ES256",
        "x":"${coordinate(publicKey.w.affineX)}","y":"${coordinate(publicKey.w.affineY)}"}]}
    """.trimIndent()

    // Starts a loopback-only JWKS endpoint for the duration of `block`, passing the
    // issuer URL to feed into `configureJwt(issuer = ...)`.
    fun <T> withServer(block: (issuer: String) -> T): T {
        val server = HttpServer.create(InetSocketAddress("127.0.0.1", 0), 0)
        server.createContext("/.well-known/jwks.json") { exchange ->
            val bytes = jwksJson.toByteArray()
            exchange.responseHeaders.add("Content-Type", "application/json")
            exchange.sendResponseHeaders(200, bytes.size.toLong())
            exchange.responseBody.use { it.write(bytes) }
        }
        server.start()
        try {
            return block("http://127.0.0.1:${server.address.port}")
        } finally {
            server.stop(0)
        }
    }

    fun token(issuer: String, subject: String = UUID.randomUUID().toString(), audience: String = "authenticated"): String =
        JWT.create()
            .withKeyId(KEY_ID)
            .withSubject(subject)
            .withIssuer(issuer)
            .withAudience(audience)
            .withExpiresAt(Date(System.currentTimeMillis() + 3_600_000))
            .sign(algorithm)
}
