// engine-contract.ts — the single owner of Muaalem's wire dialect.
//
// Everything a caller must know about the engine's JSON (docs/api-spec.md, the
// S1 spike in docs/decisions/grading-tiers.md): field names, the upstream
// `preditected_ph` misspelling, optionality, skip-malformed semantics, and the
// meaning of `all_correct`. Both Modal-facing functions (audio-analyze,
// speech-grade) import from here; they no longer carry their own half-copies
// of the dialect.
//
// Also owns the forward adapter: multipart -> engine URL -> {status, body},
// with the 60s cold-start budget. Functions map network failure to 503 and
// pass non-2xx bodies through, per api-spec.

// ---------------------------------------------------------------------------
// Engine response types
// ---------------------------------------------------------------------------

export interface PhonemeIssue {
  uthmani_pos: number[];
  issue_type: string;
  expected_phoneme: string;
  predicted_phoneme: string;
  feedback_key: string;
}

export interface SpeechGradeResponse {
  verdict: string; // pass | retry | fail
  score: number;
  phoneme_issues: PhonemeIssue[];
  item_ref: string;
}

/** One `mistakes` row ready for persistence (id/session_id stamped by caller). */
export interface MistakeRow {
  char_start: number;
  char_end: number;
  error_type: string;
  speech_error_type: string | null;
  rule_name_en: string | null;
  rule_name_ar: string | null;
  expected_len: number | null;
  predicted_len: number | null;
}

/** One `sifat_mistakes` row ready for persistence (id/session_id stamped by caller). */
export interface SifatRow {
  phonemes_group: string;
  attribute: string;
  predicted: string;
  expected: string;
  confidence: number | null;
}

export interface ParsedEngineBody {
  allCorrect: boolean;
  mistakes: MistakeRow[];
  sifatErrors: SifatRow[];
}

// ---------------------------------------------------------------------------
// Feedback-key semantics (api-spec.md:161-162, S1 confusion pairs)
// ---------------------------------------------------------------------------

const PAIR_FEEDBACK: Array<[string[], string]> = [
  [["ص", "س"], "swap_sad_seen"],
  [["ط", "ت"], "swap_taa_ta"],
  [["ح", "ه"], "swap_haa_ha"],
  [["ق", "ك"], "swap_qaf_kaf"],
];

function isMajor(issue: PhonemeIssue): boolean {
  return issue.issue_type === "length_short" || issue.issue_type === "length_long";
}

const TASHKEEL = /[ًٌٍَُِّْٰٕٓٔ]/g;

function stripTashkeel(s: string): string {
  return s.replace(TASHKEEL, "");
}

/**
 * Which minimal-pair feedback key an expected/predicted phoneme confusion maps
 * to, or null. Kotlin semantics (SpeechGrade.kt, the original contract owner):
 * the pair must appear on both sides AND the two character SETS must differ in
 * content — not merely in size. صَ vs سَ are both size-2 sets, so a size-only
 * comparison (the old TS port's `exp.size !== pred.size`) would never fire.
 */
export function pairFeedback(expected: string, predicted: string): string | null {
  const exp = new Set(expected);
  const pred = new Set(predicted);
  const setsDiffer =
    exp.size !== pred.size || [...exp].some((c) => !pred.has(c));
  for (const [pair, key] of PAIR_FEEDBACK) {
    if (pair.some((c) => exp.has(c)) && pair.some((c) => pred.has(c)) && setsDiffer) {
      return key;
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

/** Raw engine error -> (issue_type, feedback_key). Pure; no I/O. */
export function classify(
  expected: string,
  predicted: string,
  speechType: string,
  expectedLen: number | null,
  predictedLen: number | null,
): [string, string] {
  if (expectedLen != null && predictedLen != null && expectedLen !== predictedLen) {
    return predictedLen < expectedLen
      ? ["length_short", "length_short"]
      : ["length_long", "length_long"];
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
  // Upstream misspells the field as preditected_ph (Spike S1 raw output).
  const predicted = (obj["preditected_ph"] ?? obj["predicted_ph"] ?? obj["predicted_phoneme"] ?? "") as string;

  const expectedLen = obj["expected_len"] != null ? Number(obj["expected_len"]) : null;
  const predictedLen = obj["predicted_len"] != null ? Number(obj["predicted_len"]) : null;

  const [issueType, feedbackKey] = classify(expected, predicted, speechType, expectedLen, predictedLen);
  return {
    uthmani_pos: [start, end],
    issue_type: issueType,
    expected_phoneme: expected,
    predicted_phoneme: predicted,
    feedback_key: feedbackKey,
  };
}

function mapSifatError(obj: Record<string, unknown>): PhonemeIssue | null {
  const attribute = obj["attribute"];
  const expected = obj["expected"];
  const predicted = obj["predicted"];
  if (typeof attribute !== "string" || typeof expected !== "string" || typeof predicted !== "string") {
    return null;
  }
  const cleanPred = predicted.trim().toLowerCase();
  if (["[pad]", "<pad>", "pad", "none", ""].includes(cleanPred)) {
    return null;
  }
  const group = typeof obj["phonemes_group"] === "string" ? (obj["phonemes_group"] as string) : "";

  let issueType: string;
  let feedbackKey: string;
  if (attribute === "qalqla") {
    issueType = "missing_qalqalah";
    feedbackKey = "missing_qalqalah";
  } else if (attribute === "ghonna") {
    issueType = "missing_ghunnah";
    feedbackKey = "missing_ghunnah";
  } else if (attribute === "tafkheem_or_taqeeq") {
    if (group.includes("ل") || expected.includes("moraqaq") || predicted.includes("moraqaq")) {
      issueType = "consonant_swap";
      feedbackKey = "light_lam";
    } else {
      issueType = "consonant_swap";
      feedbackKey = "swap_consonant_other";
    }
  } else {
    return null;
  }
  return {
    uthmani_pos: [0, Math.max(1, group.length)],
    issue_type: issueType,
    expected_phoneme: expected,
    predicted_phoneme: predicted,
    feedback_key: feedbackKey,
  };
}

/**
 * Full speech-grade normalization: raw engine body -> {verdict, score,
 * phoneme_issues, item_ref}, with the tolerance policy from
 * docs/decisions/grading-tiers.md (drop edge inserts, single minor -> retry,
 * major or multiple -> fail). Pure; no I/O.
 */
export function normalize(engineBody: string, referenceText: string, itemRef: string): SpeechGradeResponse {
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

  const verdict = issues.length === 0
    ? "pass"
    : (issues.length === 1 && !isMajor(issues[0]) ? "retry" : "fail");
  const score = verdict === "pass"
    ? 1.0
    : (verdict === "retry" ? 0.62 : Math.max(0, Math.min(0.45, 1.0 - 0.25 * issues.length)));
  return { verdict, score, phoneme_issues: issues, item_ref: itemRef };
}

// ---------------------------------------------------------------------------
// all_correct semantics
// ---------------------------------------------------------------------------

/**
 * all_correct = no phoneme errors AND no sifat errors. The engine's two
 * endpoints disagree on this (/correct ignores sifat, /grade-text counts it —
 * ml/muaalem_modal.py:233 vs :212), so the module computes it from the raw
 * arrays instead of trusting the engine's field. A sifat-only recitation is
 * NOT perfect; persisting it as perfect would inflate /progress accuracy.
 */
export function allCorrectFrom(errorCount: number, sifatErrorCount: number): boolean {
  return errorCount === 0 && sifatErrorCount === 0;
}

// ---------------------------------------------------------------------------
// Persistence parsing (audio-analyze's needs)
// ---------------------------------------------------------------------------

/**
 * Extracts what the DB needs from the raw engine body. Throws on unparseable
 * JSON (caller maps to 503 ml_unavailable per api-spec.md:105 — the engine
 * answered, we just can't read it). Rows with a missing error_type are
 * dropped (Ktor semantics: the field is required); malformed rows are skipped
 * like the original mapNotNull. all_correct is recomputed from the raw arrays.
 */
export function parseEngineBody(body: string): ParsedEngineBody {
  let root: Record<string, unknown>;
  try {
    root = JSON.parse(body);
  } catch {
    throw new Error("unparseable engine body");
  }

  const rawErrors = Array.isArray(root["errors"]) ? (root["errors"] as Record<string, unknown>[]) : [];
  const rawSifat = Array.isArray(root["sifat_errors"])
    ? (root["sifat_errors"] as Record<string, unknown>[])
    : [];

  const mistakes: MistakeRow[] = [];
  for (const el of rawErrors) {
    try {
      const pos = el["uthmani_pos"] as unknown[];
      if (!Array.isArray(pos) || pos.length < 2) continue;
      const errorType = el["error_type"];
      if (typeof errorType !== "string" || errorType.length === 0) continue; // required, else drop row
      const rule = (el["ref_tajweed_rules"] as Record<string, unknown>[] | undefined)?.[0] as
        | Record<string, unknown>
        | undefined;
      const ruleName = rule?.["name"] as Record<string, unknown> | undefined;
      mistakes.push({
        char_start: Number(String(pos[0])),
        char_end: Number(String(pos[1])),
        error_type: errorType,
        speech_error_type: el["speech_error_type"] != null ? String(el["speech_error_type"]) : null,
        rule_name_en: ruleName?.["en"] != null ? String(ruleName["en"]) : null,
        rule_name_ar: ruleName?.["ar"] != null ? String(ruleName["ar"]) : null,
        expected_len: el["expected_len"] != null ? Number(el["expected_len"]) : null,
        predicted_len: el["predicted_len"] != null ? Number(el["predicted_len"]) : null,
      });
    } catch {
      /* skip malformed row, like the original mapNotNull */
    }
  }

  const sifatErrors: SifatRow[] = [];
  for (const el of rawSifat) {
    try {
      const pred = String(el["predicted"] ?? "").trim();
      if (["[pad]", "<pad>", "pad", "none", ""].includes(pred.toLowerCase())) {
        continue;
      }
      sifatErrors.push({
        phonemes_group: String(el["phonemes_group"] ?? ""),
        attribute: String(el["attribute"] ?? ""),
        predicted: pred,
        expected: String(el["expected"] ?? ""),
        confidence: el["confidence"] != null ? Number(el["confidence"]) : null,
      });
    } catch {
      /* skip */
    }
  }

  return {
    allCorrect: allCorrectFrom(rawErrors.length, sifatErrors.length),
    mistakes,
    sifatErrors,
  };
}

// ---------------------------------------------------------------------------
// Forward adapter — the engine HTTP call (60s cold-start budget)
// ---------------------------------------------------------------------------

export interface EngineResponse {
  status: number;
  body: string;
}

/**
 * POST multipart to the engine, returning {status, body}. 60s timeout is the
 * Modal cold-start budget (CODEBASE_MAP §7) — don't shorten. Throws on
 * network failure; callers map that to 503 ml_unavailable and pass non-2xx
 * bodies through unchanged (api-spec).
 */
export async function forwardMultipart(url: string, fd: FormData): Promise<EngineResponse> {
  let resp: Response;
  try {
    resp = await fetch(url, {
      method: "POST",
      body: fd,
      signal: AbortSignal.timeout(60_000),
    });
  } catch {
    throw new Error("engine network failure");
  }
  return { status: resp.status, body: await resp.text() };
}
