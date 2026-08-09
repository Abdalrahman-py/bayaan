// spike-speech-grade — Deno Edge Function mirroring Ktor POST /speech/grade
//
// SPIKE ONLY (2026-08-09): proves Supabase Edge Functions can replace the
// Render-hosted Ktor proxy for the Modal-facing routes. Ported 1:1 from
// backend/src/main/kotlin/com/bayaan/SpeechGrade.kt + routes/SpeechGradeRoute.kt
// so the response contract is identical: {verdict, score, phoneme_issues, item_ref}.
//
// Flow: multipart in (audio + tier + reference_text + item_ref)
//     -> validate at boundary (mirrors Ktor checks)
//     -> forward audio + reference_text to Modal /grade-text (60s timeout)
//     -> normalize raw {errors, sifat_errors} with the tolerance policy
//     -> return the same JSON the app already parses.
//
// verify_jwt=true on deploy: Supabase validates the Bearer JWT, so the JWKS/ES256
// plugin code in Ktor is not needed here at all.

const MUAALEM_GRADE_TEXT_URL = Deno.env.get("MUAALEM_GRADE_TEXT_URL") ??
  "https://abdalrahman-py--bayaan-muaalem-muaalem-grade-text.modal.run";

const JSON_HEADERS = { "Content-Type": "application/json" };

const PAIR_FEEDBACK: Array<[string[], string]> = [
  [["ص", "س"], "swap_sad_seen"],
  [["ط", "ت"], "swap_taa_ta"],
  [["ح", "ه"], "swap_haa_ha"],
  [["ق", "ك"], "swap_qaf_kaf"],
];

interface PhonemeIssue {
  uthmani_pos: number[];
  issue_type: string;
  expected_phoneme: string;
  predicted_phoneme: string;
  feedback_key: string;
}

interface SpeechGradeResponse {
  verdict: string;
  score: number;
  phoneme_issues: PhonemeIssue[];
  item_ref: string;
}

function isMajor(issue: PhonemeIssue): boolean {
  return issue.issue_type === "length_short" || issue.issue_type === "length_long";
}

function stripTashkeel(s: string): string {
  return s.replace(/[ًٌٍَُِّْٰٕٓٔ]/g, "");
}

function pairFeedback(expected: string, predicted: string): string | null {
  const exp = new Set(expected);
  const pred = new Set(predicted);
  for (const [pair, key] of PAIR_FEEDBACK) {
    if (pair.some((c) => exp.has(c)) && pair.some((c) => pred.has(c)) && exp.size !== pred.size) {
      // Kotlin compares Set(expected) != Set(predicted); approximate with a
      // content check on the pair chars themselves.
      if (expected !== predicted) return key;
    }
  }
  return null;
}

function isEdgeInsert(start: number, end: number, refLen: number): boolean {
  if (refLen <= 0) return true;
  if (start <= 0) return true;
  if (start >= refLen) return true;
  if (end >= refLen && start === end) return true;
  return false;
}

function classify(
  expected: string,
  predicted: string,
  speechType: string,
  expectedLen: number | null,
  predictedLen: number | null,
): [string, string] {
  if (expectedLen != null && predictedLen != null && expectedLen !== predictedLen) {
    return predictedLen < expectedLen ? ["length_short", "length_short"] : ["length_long", "length_long"];
  }

  // Length cues without expected_len: missing madd letters in the prediction.
  const maddChars = "اويۦٰۥ";
  const expHasMadd = [...expected].some((c) => maddChars.includes(c)) || expected.includes("اا");
  const predHasMadd = [...predicted].some((c) => maddChars.includes(c)) || predicted.includes("اا");
  if (expHasMadd && !predHasMadd) return ["length_short", "length_short"];
  if (!expHasMadd && predHasMadd) return ["length_long", "length_long"];

  const pairKey = pairFeedback(expected, predicted);
  if (pairKey != null) return ["consonant_swap", pairKey];

  if (speechType === "replace" || speechType === "delete" || speechType === "insert") {
    const expCons = stripTashkeel(expected);
    const predCons = stripTashkeel(predicted);
    if (expCons !== predCons && expCons.length > 0 && predCons.length > 0) {
      return ["consonant_swap", "swap_consonant_other"];
    }
    if (expCons === predCons && expected !== predicted) {
      return ["vowel_swap", "vowel_mismatch"];
    }
  }

  return ["vowel_swap", "vowel_mismatch"];
}

function mapPhonemeError(obj: Record<string, unknown>, referenceText: string): PhonemeIssue | null {
  const speechType = obj["speech_error_type"];
  if (typeof speechType !== "string") return null;

  const pos = obj["uthmani_pos"];
  if (!Array.isArray(pos) || pos.length < 2) return null;
  const start = Number(pos[0]);
  const end = Number(pos[1]);

  if (speechType === "insert" && isEdgeInsert(start, end, referenceText.length)) return null;

  const expected = (obj["expected_ph"] ?? obj["expected_phoneme"] ?? "") as string;
  // Upstream misspells the field as preditected_ph (see Spike S1 raw output).
  const predicted = (obj["preditected_ph"] ?? obj["predicted_ph"] ?? obj["predicted_phoneme"] ?? "") as string;

  const expectedLen = obj["expected_len"] != null ? Number(obj["expected_len"]) : null;
  const predictedLen = obj["predicted_len"] != null ? Number(obj["predicted_len"]) : null;

  const [issueType, feedbackKey] = classify(expected, predicted, speechType, expectedLen, predictedLen);
  return { uthmani_pos: [start, end], issue_type: issueType, expected_phoneme: expected, predicted_phoneme: predicted, feedback_key: feedbackKey };
}

function mapSifatError(obj: Record<string, unknown>): PhonemeIssue | null {
  const attribute = obj["attribute"];
  const expected = obj["expected"];
  const predicted = obj["predicted"];
  if (typeof attribute !== "string" || typeof expected !== "string" || typeof predicted !== "string") return null;
  const group = typeof obj["phonemes_group"] === "string" ? (obj["phonemes_group"] as string) : "";

  let issueType: string, feedbackKey: string;
  if (attribute === "qalqla") {
    issueType = "missing_qalqalah"; feedbackKey = "missing_qalqalah";
  } else if (attribute === "ghonna") {
    issueType = "missing_ghunnah"; feedbackKey = "missing_ghunnah";
  } else if (attribute === "tafkheem_or_taqeeq") {
    if (group.includes("ل") || expected.includes("moraqaq") || predicted.includes("moraqaq")) {
      issueType = "consonant_swap"; feedbackKey = "light_lam";
    } else {
      issueType = "consonant_swap"; feedbackKey = "swap_consonant_other";
    }
  } else {
    return null;
  }
  return { uthmani_pos: [0, Math.max(1, group.length)], issue_type: issueType, expected_phoneme: expected, predicted_phoneme: predicted, feedback_key: feedbackKey };
}

function normalize(engineBody: string, referenceText: string, itemRef: string): SpeechGradeResponse {
  const root = JSON.parse(engineBody);
  const rawErrors = Array.isArray(root["errors"]) ? root["errors"] : [];
  const sifatErrors = Array.isArray(root["sifat_errors"]) ? root["sifat_errors"] : [];

  const issues: PhonemeIssue[] = [];
  for (const el of rawErrors) {
    const issue = mapPhonemeError(el, referenceText);
    if (issue) issues.push(issue);
  }
  for (const el of sifatErrors) {
    const issue = mapSifatError(el);
    if (issue) issues.push(issue);
  }

  const verdict = issues.length === 0 ? "pass" : (issues.length === 1 && !isMajor(issues[0]) ? "retry" : "fail");
  const score = verdict === "pass" ? 1.0 : (verdict === "retry" ? 0.62 : Math.max(0, Math.min(0.45, 1.0 - 0.25 * issues.length)));
  return { verdict, score, phoneme_issues: issues, item_ref: itemRef };
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: JSON_HEADERS });
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return json({ error: "method_not_allowed", message: "POST only" }, 405);
  }

  let form: FormData;
  try {
    form = await req.formData();
  } catch {
    return json({ error: "bad_request", message: "invalid multipart form" }, 400);
  }

  const audio = form.get("audio");
  const tierRaw = String(form.get("tier") ?? "1");
  const referenceText = String(form.get("reference_text") ?? "");
  const itemRef = String(form.get("item_ref") ?? "");
  const tier = Number.parseInt(tierRaw, 10);

  if (!(audio instanceof File)) {
    return json({ error: "bad_request", message: "missing audio field" }, 400);
  }
  const audioBytes = new Uint8Array(await audio.arrayBuffer());
  if (audioBytes.length === 0) {
    return json({ error: "bad_request", message: "missing audio field" }, 400);
  }
  // Lesson clips are <=4s / small; 2MB is generous while still protecting the host.
  if (audioBytes.length > 2 * 1024 * 1024) {
    return json({ error: "payload_too_large", message: "audio exceeds 2MB" }, 413);
  }
  if (tier !== 1 && tier !== 2) {
    return json({ error: "bad_request", message: "tier must be 1 or 2" }, 400);
  }
  const text = referenceText.trim();
  if (text.length === 0) {
    return json({ error: "bad_request", message: "missing reference_text" }, 400);
  }
  if (itemRef.trim().length === 0) {
    return json({ error: "bad_request", message: "missing item_ref" }, 400);
  }

  // Forward to Modal /grade-text — same multipart shape the Ktor backend sends.
  const fd = new FormData();
  fd.append("audio", new Blob([audioBytes], { type: "audio/wav" }), "recording.wav");
  fd.append("reference_text", text);

  let engineResp: Response;
  try {
    engineResp = await fetch(MUAALEM_GRADE_TEXT_URL, {
      method: "POST",
      body: fd,
      // Same 60s budget as the Ktor client: Modal can cold-start ~24s.
      signal: AbortSignal.timeout(60_000),
    });
  } catch {
    return json({ error: "ml_unavailable", message: "recitation engine did not respond" }, 503);
  }

  const engineBody = await engineResp.text();

  // Decode crash on short clips -> verdict retry (never 5xx). Modal returns 422
  // with error=decode_failed for multilevel_greedy_decode RuntimeError.
  if (engineResp.status === 422 && engineBody.includes("decode_failed")) {
    return json({ verdict: "retry", score: 0.0, phoneme_issues: [], item_ref: itemRef });
  }

  if (engineResp.status < 200 || engineResp.status >= 300) {
    return new Response(engineBody, { status: engineResp.status, headers: JSON_HEADERS });
  }

  try {
    return json(normalize(engineBody, text, itemRef));
  } catch {
    return json({ error: "ml_unavailable", message: "recitation engine did not respond" }, 503);
  }
});
