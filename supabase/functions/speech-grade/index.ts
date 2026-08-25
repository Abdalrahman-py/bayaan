// speech-grade — Deno Edge Function for POST /speech/grade (M3 Path A echo grading).
//
// Thin orchestrator: validate multipart at the boundary, forward audio +
// reference_text to Modal /grade-text via the shared forward adapter, normalize
// the raw {errors, sifat_errors} with the engine-contract module, return the
// same JSON the app parses. All dialect knowledge (field names, the
// preditected_ph misspelling, pair feedback keys, tolerance policy) lives in
// ../_shared/engine-contract.ts — this file owns none of it.
//
// verify_jwt=true on deploy: Supabase validates the Bearer JWT.
import { CORS_HEADERS, handlePreflight } from "../_shared/cors.ts";
import { forwardMultipart, normalize } from "../_shared/engine-contract.ts";

const MUAALEM_GRADE_TEXT_URL = Deno.env.get("MUAALEM_GRADE_TEXT_URL") ??
  "https://abdalrahman-py--bayaan-muaalem-muaalem-grade-text.modal.run";

const JSON_HEADERS = { "Content-Type": "application/json", ...CORS_HEADERS };

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: JSON_HEADERS });
}

Deno.serve(async (req) => {
  const preflight = handlePreflight(req);
  if (preflight) return preflight;
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

  // Forward to Modal /grade-text — same multipart shape the Ktor backend sent.
  const fd = new FormData();
  fd.append("audio", new Blob([audioBytes], { type: "audio/wav" }), "recording.wav");
  fd.append("reference_text", text);

  let engineResp;
  try {
    engineResp = await forwardMultipart(MUAALEM_GRADE_TEXT_URL, fd);
  } catch {
    return json({ error: "ml_unavailable", message: "recitation engine did not respond" }, 503);
  }

  // Decode crash on short clips -> verdict retry (never 5xx). Modal returns 422
  // with error=decode_failed for multilevel_greedy_decode RuntimeError.
  if (engineResp.status === 422 && engineResp.body.includes("decode_failed")) {
    return json({ verdict: "retry", score: 0.0, phoneme_issues: [], item_ref: itemRef });
  }

  if (engineResp.status < 200 || engineResp.status >= 300) {
    return new Response(engineResp.body, { status: engineResp.status, headers: JSON_HEADERS });
  }

  try {
    return json(normalize(engineResp.body, text, itemRef));
  } catch {
    return json({ error: "ml_unavailable", message: "recitation engine did not respond" }, 503);
  }
});
