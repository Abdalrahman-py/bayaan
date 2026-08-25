// Unit tests for the engine-contract module (supabase/functions/_shared/engine-contract.ts).
// Source of truth: docs/api-spec.md (feedback_key enum at :148, :161-162) and the
// Spike S1 confusion pairs (docs/decisions/grading-tiers.md). These pin the behaviors
// the Edge Functions must keep: the ص→س confusion must yield swap_sad_seen, etc.

import { assert, assertEquals } from "jsr:@std/assert";
import {
  allCorrectFrom,
  classify,
  normalize,
  pairFeedback,
  parseEngineBody,
} from "../functions/_shared/engine-contract.ts";

// --- pairFeedback: the four S1 minimal pairs must map to their enum keys ---

Deno.test("pairFeedback: sad->seen (ص->س) maps to swap_sad_seen", () => {
  // Expected "صَ" (ص+fatha) vs predicted "سَ" — both sets are size 2, so a
  // size-only comparison would miss this. Set CONTENT differs -> swap_sad_seen.
  assertEquals(pairFeedback("صَ", "سَ"), "swap_sad_seen");
});

Deno.test("pairFeedback: taa->ta (ط->ت) maps to swap_taa_ta", () => {
  assertEquals(pairFeedback("طَ", "تَ"), "swap_taa_ta");
});

Deno.test("pairFeedback: haa->ha (ح->ه) maps to swap_haa_ha", () => {
  assertEquals(pairFeedback("حَ", "هَ"), "swap_haa_ha");
});

Deno.test("pairFeedback: qaf->kaf (ق->ك) maps to swap_qaf_kaf", () => {
  assertEquals(pairFeedback("قَ", "كَ"), "swap_qaf_kaf");
});

Deno.test("pairFeedback: no pair overlap -> null", () => {
  assertEquals(pairFeedback("مَ", "نَ"), null);
});

Deno.test("pairFeedback: identical strings -> null", () => {
  assertEquals(pairFeedback("بَا", "بَا"), null);
});

// --- classify: issue types ---

Deno.test("classify: length mismatch is length_short", () => {
  const [type, key] = classify("اا", "ا", "replace", 2, 1);
  assertEquals(type, "length_short");
  assertEquals(key, "length_short");
});

Deno.test("classify: consonant swap via pair maps to pair key", () => {
  const [type, key] = classify("صَ", "سَ", "replace", null, null);
  assertEquals(type, "consonant_swap");
  assertEquals(key, "swap_sad_seen");
});

Deno.test("classify: non-pair consonant swap is swap_consonant_other", () => {
  const [type, key] = classify("مَ", "نَ", "replace", null, null);
  assertEquals(type, "consonant_swap");
  assertEquals(key, "swap_consonant_other");
});

Deno.test("classify: same consonants different vowels is vowel_swap", () => {
  const [type, key] = classify("بِ", "بُ", "replace", null, null);
  assertEquals(type, "vowel_swap");
  assertEquals(key, "vowel_mismatch");
});

// --- normalize: verdict/score from raw engine body ---

Deno.test("normalize: clean payload yields pass", () => {
  const body = `{"errors":[],"sifat_errors":[],"all_correct":true}`;
  const r = normalize(body, "بَا", "ar.1.1.echo.ba");
  assertEquals(r.verdict, "pass");
  assertEquals(r.score, 1.0);
  assertEquals(r.phoneme_issues.length, 0);
  assertEquals(r.item_ref, "ar.1.1.echo.ba");
});

Deno.test("normalize: edge insert at start is dropped so pass if only issue", () => {
  const body = `{"errors":[{"uthmani_pos":[0,0],"speech_error_type":"insert",
     "expected_ph":"","preditected_ph":"ع","expected_len":null,"predicted_len":null}],
     "sifat_errors":[]}`;
  const r = normalize(body, "بَا", "x");
  assertEquals(r.verdict, "pass");
  assertEquals(r.phoneme_issues.length, 0);
});

Deno.test("normalize: edge insert at end of reference is dropped", () => {
  const body = `{"errors":[{"uthmani_pos":[3,3],"speech_error_type":"insert",
     "expected_ph":"","preditected_ph":"ه","expected_len":null,"predicted_len":null}],
     "sifat_errors":[]}`;
  const r = normalize(body, "بَا", "x");
  assertEquals(r.verdict, "pass");
});

Deno.test("normalize: sad->seen maps to swap_sad_seen and single issue is retry", () => {
  const body = `{"errors":[{"uthmani_pos":[0,1],"speech_error_type":"replace",
     "expected_ph":"صَ","preditected_ph":"سَ","expected_len":null,"predicted_len":null}],
     "sifat_errors":[]}`;
  const r = normalize(body, "صَا", "x");
  assertEquals(r.verdict, "retry");
  assertEquals(r.phoneme_issues.length, 1);
  assertEquals(r.phoneme_issues[0].issue_type, "consonant_swap");
  assertEquals(r.phoneme_issues[0].feedback_key, "swap_sad_seen");
});

Deno.test("normalize: length mismatch is major and single major is fail", () => {
  const body = `{"errors":[{"uthmani_pos":[1,3],"speech_error_type":"replace",
     "expected_ph":"اا","preditected_ph":"ا","expected_len":2,"predicted_len":1}],
     "sifat_errors":[]}`;
  const r = normalize(body, "بَا", "x");
  assertEquals(r.verdict, "fail");
  assertEquals(r.phoneme_issues[0].issue_type, "length_short");
  assertEquals(r.phoneme_issues[0].feedback_key, "length_short");
});

Deno.test("normalize: two issues yield fail", () => {
  const body = `{"errors":[
      {"uthmani_pos":[0,1],"speech_error_type":"replace","expected_ph":"صَ","preditected_ph":"سَ"},
      {"uthmani_pos":[1,2],"speech_error_type":"replace","expected_ph":"ا","preditected_ph":"ي"}
    ],"sifat_errors":[]}`;
  const r = normalize(body, "صَا", "x");
  assertEquals(r.verdict, "fail");
  assertEquals(r.phoneme_issues.length, 2);
});

// --- all_correct semantics: sifat errors must count (spec + ml parity) ---

Deno.test("allCorrectFrom: true only when errors AND sifat are empty", () => {
  assertEquals(allCorrectFrom(0, 0), true);
  assertEquals(allCorrectFrom(1, 0), false);
  assertEquals(allCorrectFrom(0, 1), false);
});

// --- parseEngineBody: persistence rows, tolerant to the upstream dialect ---

Deno.test("parseEngineBody: handles the preditected_ph misspelling", () => {
  const body = `{"errors":[
      {"uthmani_pos":[0,1],"speech_error_type":"replace","error_type":"replace",
       "expected_ph":"صَ","preditected_ph":"سَ",
       "ref_tajweed_rules":[{"name":{"en":"Sad","ar":"صاد"}}]}
    ],"sifat_errors":[],"all_correct":true}`;
  const parsed = parseEngineBody(body);
  // error_type present -> row kept; all_correct recomputed defensively from the
  // raw engine arrays (1 error) instead of trusting the engine's field.
  assertEquals(parsed.mistakes.length, 1);
  assertEquals(parsed.mistakes[0].error_type, "replace");
  assertEquals(parsed.mistakes[0].rule_name_en, "Sad");
  assertEquals(parsed.allCorrect, false);
});

Deno.test("parseEngineBody: row with missing error_type is dropped (Ktor semantics)", () => {
  const body = `{"errors":[
      {"uthmani_pos":[0,1],"speech_error_type":"replace",
       "expected_ph":"صَ","preditected_ph":"سَ"}
    ],"sifat_errors":[],"all_correct":false}`;
  const parsed = parseEngineBody(body);
  assertEquals(parsed.mistakes.length, 0);
  // Engine judged 1 error -> not all correct, even though the row was dropped.
  assertEquals(parsed.allCorrect, false);
});

Deno.test("parseEngineBody: sifat-only recitation is NOT all correct (drift fix)", () => {
  const body = `{"errors":[],"sifat_errors":[
      {"phonemes_group":"ص","attribute":"tafkheem_or_taqeeq","predicted":"mufakham","expected":"moraqaq"}
    ],"all_correct":true}`;
  const parsed = parseEngineBody(body);
  assertEquals(parsed.sifatErrors.length, 1);
  // The /correct endpoint would report all_correct=true here; the module must not.
  assertEquals(parsed.allCorrect, false);
});

Deno.test("parseEngineBody: unparseable body throws", () => {
  let threw = false;
  try {
    parseEngineBody("not json");
  } catch {
    threw = true;
  }
  assert(threw, "expected parseEngineBody to throw on unparseable body");
});
