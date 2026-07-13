package com.bayaan

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class SpeechGradeNormalizerTest {

    @Test
    fun `clean engine payload yields pass`() {
        val body = """{"errors":[],"sifat_errors":[],"all_correct":true}"""
        val r = SpeechGradeNormalizer.normalize(body, "بَا", "ar.1.1.echo.ba")
        assertEquals("pass", r.verdict)
        assertEquals(1.0, r.score)
        assertTrue(r.phoneme_issues.isEmpty())
        assertEquals("ar.1.1.echo.ba", r.item_ref)
    }

    @Test
    fun `edge insert at start is dropped so pass if only issue`() {
        // Mirrors Spike S1 baa_correct_long leading-ع breath insert at [0,0].
        val body = """
            {"errors":[{"uthmani_pos":[0,0],"speech_error_type":"insert",
             "expected_ph":"","preditected_ph":"ع","expected_len":null,"predicted_len":null}],
             "sifat_errors":[]}
        """.trimIndent()
        val r = SpeechGradeNormalizer.normalize(body, "بَا", "x")
        assertEquals("pass", r.verdict)
        assertTrue(r.phoneme_issues.isEmpty())
    }

    @Test
    fun `edge insert at end of reference is dropped`() {
        val body = """
            {"errors":[{"uthmani_pos":[3,3],"speech_error_type":"insert",
             "expected_ph":"","preditected_ph":"ه","expected_len":null,"predicted_len":null}],
             "sifat_errors":[]}
        """.trimIndent()
        val r = SpeechGradeNormalizer.normalize(body, "بَا", "x") // len=3, pos at end
        assertEquals("pass", r.verdict)
    }

    @Test
    fun `sad to seen maps to swap_sad_seen and single issue is retry`() {
        val body = """
            {"errors":[{"uthmani_pos":[0,1],"speech_error_type":"replace",
             "expected_ph":"صَ","preditected_ph":"سَ","expected_len":null,"predicted_len":null}],
             "sifat_errors":[]}
        """.trimIndent()
        val r = SpeechGradeNormalizer.normalize(body, "صَا", "x")
        assertEquals("retry", r.verdict)
        assertEquals(1, r.phoneme_issues.size)
        assertEquals("consonant_swap", r.phoneme_issues[0].issue_type)
        assertEquals("swap_sad_seen", r.phoneme_issues[0].feedback_key)
    }

    @Test
    fun `length mismatch is major and single major is fail`() {
        val body = """
            {"errors":[{"uthmani_pos":[1,3],"speech_error_type":"replace",
             "expected_ph":"اا","preditected_ph":"ا","expected_len":2,"predicted_len":1}],
             "sifat_errors":[]}
        """.trimIndent()
        val r = SpeechGradeNormalizer.normalize(body, "بَا", "x")
        assertEquals("fail", r.verdict)
        assertEquals("length_short", r.phoneme_issues[0].issue_type)
        assertEquals("length_short", r.phoneme_issues[0].feedback_key)
    }

    @Test
    fun `two issues yield fail`() {
        val body = """
            {"errors":[
              {"uthmani_pos":[0,1],"speech_error_type":"replace","expected_ph":"صَ","preditected_ph":"سَ"},
              {"uthmani_pos":[1,2],"speech_error_type":"replace","expected_ph":"ا","preditected_ph":"ي"}
            ],"sifat_errors":[]}
        """.trimIndent()
        val r = SpeechGradeNormalizer.normalize(body, "صَا", "x")
        assertEquals("fail", r.verdict)
        assertEquals(2, r.phoneme_issues.size)
    }
}
