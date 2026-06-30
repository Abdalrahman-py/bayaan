package com.bayaan

import com.bayaan.MistakeInput
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

class EngineResponseParserTest {

    // ── tracer bullet ────────────────────────────────────────────────────────

    @Test
    fun `all correct with empty errors returns empty list`() {
        val (allCorrect, mistakes) = EngineResponseParser.parse(
            """{"all_correct":true,"errors":[]}"""
        )
        assertTrue(allCorrect)
        assertTrue(mistakes.isEmpty())
    }

    // ── all_correct flag ─────────────────────────────────────────────────────

    @Test
    fun `all_correct false is preserved`() {
        val (allCorrect, _) = EngineResponseParser.parse(
            """{"all_correct":false,"errors":[]}"""
        )
        assertFalse(allCorrect)
    }

    @Test
    fun `missing all_correct defaults to true`() {
        val (allCorrect, _) = EngineResponseParser.parse("""{"errors":[]}""")
        assertTrue(allCorrect)
    }

    // ── errors array ─────────────────────────────────────────────────────────

    @Test
    fun `missing errors key returns empty list`() {
        val (_, mistakes) = EngineResponseParser.parse("""{"all_correct":true}""")
        assertTrue(mistakes.isEmpty())
    }

    @Test
    fun `single mistake with all fields is parsed correctly`() {
        val json = """
            {
              "all_correct": false,
              "errors": [{
                "uthmani_pos": [10, 15],
                "error_type": "tajweed",
                "speech_error_type": "replace",
                "ref_tajweed_rules": [{"name": {"en": "Aared Madd", "ar": "المد العارض"}}],
                "expected_len": 4,
                "predicted_len": 2
              }]
            }
        """.trimIndent()

        val (_, mistakes) = EngineResponseParser.parse(json)

        assertEquals(1, mistakes.size)
        mistakes[0].apply {
            assertEquals(10, charStart)
            assertEquals(15, charEnd)
            assertEquals("tajweed", errorType)
            assertEquals("replace", speechErrorType)
            assertEquals("Aared Madd", ruleNameEn)
            assertEquals("المد العارض", ruleNameAr)
            assertEquals(4, expectedLen)
            assertEquals(2, predictedLen)
        }
    }

    @Test
    fun `optional fields are null when absent`() {
        val json = """
            {
              "all_correct": false,
              "errors": [{"uthmani_pos": [0, 5], "error_type": "plain"}]
            }
        """.trimIndent()

        val (_, mistakes) = EngineResponseParser.parse(json)

        assertEquals(1, mistakes.size)
        mistakes[0].apply {
            assertNull(speechErrorType)
            assertNull(ruleNameEn)
            assertNull(ruleNameAr)
            assertNull(expectedLen)
            assertNull(predictedLen)
        }
    }

    @Test
    fun `speech_error_type as json null is treated as null`() {
        val json = """
            {
              "all_correct": false,
              "errors": [{"uthmani_pos": [0, 5], "error_type": "tajweed", "speech_error_type": null}]
            }
        """.trimIndent()

        val (_, mistakes) = EngineResponseParser.parse(json)

        assertNull(mistakes[0].speechErrorType)
    }

    @Test
    fun `malformed entry is skipped, valid entries are kept`() {
        val json = """
            {
              "all_correct": false,
              "errors": [
                {"bad": "entry"},
                {"uthmani_pos": [0, 3], "error_type": "tajweed"}
              ]
            }
        """.trimIndent()

        val (_, mistakes) = EngineResponseParser.parse(json)

        assertEquals(1, mistakes.size)
        assertEquals(0, mistakes[0].charStart)
    }
}
