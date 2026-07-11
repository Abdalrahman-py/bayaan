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

    // ── sifat_errors array ───────────────────────────────────────────────────

    @Test
    fun `sifat_errors are parsed to SifatMistakeInput list`() {
        val json = """
            {
              "all_correct": false,
              "errors": [],
              "sifat_errors": [
                {"phonemes_group": "قل", "attribute": "qalqla", "predicted": "moqalqal", "expected": "not_moqalqal", "confidence": 0.83},
                {"phonemes_group": "بّ", "attribute": "ghonna", "predicted": "maghnoon", "expected": "not_maghnoon", "confidence": null}
              ]
            }
        """.trimIndent()

        val parsed = EngineResponseParser.parse(json)

        assertEquals(2, parsed.sifatErrors.size)
        parsed.sifatErrors[0].apply {
            assertEquals("قل", phonemesGroup)
            assertEquals("qalqla", attribute)
            assertEquals("moqalqal", predicted)
            assertEquals("not_moqalqal", expected)
            assertEquals(0.83, confidence)
        }
        assertNull(parsed.sifatErrors[1].confidence)
    }

    @Test
    fun `missing sifat_errors key returns empty list`() {
        val parsed = EngineResponseParser.parse("""{"all_correct":true,"errors":[]}""")
        assertTrue(parsed.sifatErrors.isEmpty())
    }

    @Test
    fun `malformed sifat entry is skipped, valid kept`() {
        val json = """
            {
              "all_correct": false,
              "errors": [],
              "sifat_errors": [
                {"attribute": "qalqla"},
                {"phonemes_group": "قل", "attribute": "qalqla", "predicted": "a", "expected": "b", "confidence": 0.5}
              ]
            }
        """.trimIndent()

        val parsed = EngineResponseParser.parse(json)

        assertEquals(1, parsed.sifatErrors.size)
        assertEquals("قل", parsed.sifatErrors[0].phonemesGroup)
    }

    @Test
    fun `legacy pair destructuring still works alongside sifat`() {
        val (allCorrect, mistakes) = EngineResponseParser.parse(
            """{"all_correct":true,"errors":[]}"""
        )
        assertTrue(allCorrect)
        assertTrue(mistakes.isEmpty())
    }
}
