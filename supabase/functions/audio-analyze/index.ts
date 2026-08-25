// spike-audio-analyze — Deno Edge Function mirroring Ktor POST /audio/analyze
//
// SPIKE ONLY (2026-08-09): the risky route for the Edge Function migration.
// /speech/grade clips are <=2MB; /audio/analyze accepts up to 10MB — right at
// the Edge Function platform's body-size boundary. This spike answers:
//   1. Does a ~10MB multipart body survive through an Edge Function?
//   2. Does the Modal /correct forward (audio multipart + sura/aya query
//      params, 60s timeout) behave identically?
//   3. Cold vs warm latency vs the Render path.
//
// Ported 1:1 from AnalyzeRoute.kt + RecitationAnalysis.kt + EngineResponseParser.kt.
// Response contract: engine body passed through UNCHANGED on success (the app
// parses it itself); error states map like Ktor:
//   EngineError     -> engine status + body
//   EngineFailed    -> 503 {"error":"ml_unavailable",...}
//   PersistenceFailed -> 500 {"error":"persistence_error",...}
//
// Persistence: uses SERVICE_ROLE_KEY secret when present (same DB bypass trust
// as the backend's HikariCP connection). If absent, logs and skips persistence
// so the proxy path can still be tested — the spike's core questions.
// NOTE: RLS is ON for all public tables with zero policies (checked 2026-08-09),
// so anon+user-JWT writes are impossible without adding policies first.
//
// Promoted from spike/edge-functions/spike-audio-analyze (2026-08-19): only real
// change is CORS (native app never needed it; Flutter web dev does).
import { CORS_HEADERS, handlePreflight } from "../_shared/cors.ts";

const MUAALEM_URL = Deno.env.get("MUAALEM_URL") ??
  "https://abdalrahman-py--bayaan-muaalem-muaalem-correct.modal.run";

const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";

const JSON_HEADERS = { "Content-Type": "application/json", ...CORS_HEADERS };

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: JSON_HEADERS });
}

// With verify_jwt=true, Supabase injects the verified claims into this header.
function userIdFromRequest(req: Request): string | null {
  const authHeader = req.headers.get("x-supabase-auth");
  if (authHeader) {
    try {
      const claims = JSON.parse(authHeader);
      if (claims.sub) return claims.sub;
    } catch { /* fall through */ }
  }
  // Fallback: decode the Bearer JWT payload directly.
  const bearer = req.headers.get("authorization") ?? "";
  const token = bearer.replace(/^Bearer\s+/i, "");
  if (!token) return null;
  try {
    const payload = JSON.parse(atob(token.split(".")[1].replace(/-/g, "+").replace(/_/g, "/")));
    return payload.sub ?? null;
  } catch {
    return null;
  }
}

interface MistakeRow {
  id: string;
  session_id: string;
  char_start: number;
  char_end: number;
  error_type: string;
  speech_error_type: string | null;
  rule_name_en: string | null;
  rule_name_ar: string | null;
  expected_len: number | null;
  predicted_len: number | null;
}

interface SifatRow {
  id: string;
  session_id: string;
  phonemes_group: string;
  attribute: string;
  predicted: string;
  expected: string;
  confidence: number | null;
}

function cryptoRandomUuid(): string {
  return crypto.randomUUID();
}

// Port of EngineResponseParser.parse — extracts what the DB needs. The RAW
// engine body is still what gets returned to the client.
function parseEngineBody(body: string) {
  let root: Record<string, unknown>;
  try {
    root = JSON.parse(body);
  } catch {
    throw new Error("unparseable engine body");
  }
  const allCorrect = typeof root["all_correct"] === "boolean" ? root["all_correct"] as boolean : true;

  const mistakes: MistakeRow[] = [];
  if (Array.isArray(root["errors"])) {
    for (const el of root["errors"] as Record<string, unknown>[]) {
      try {
        const pos = el["uthmani_pos"] as unknown[];
        if (!Array.isArray(pos) || pos.length < 2) continue;
        const rule = (el["ref_tajweed_rules"] as Record<string, unknown>[] | undefined)?.[0] as Record<string, unknown> | undefined;
        const ruleName = rule?.["name"] as Record<string, unknown> | undefined;
        mistakes.push({
          id: cryptoRandomUuid(),
          session_id: "", // filled after session insert
          char_start: Number(String(pos[0])),
          char_end: Number(String(pos[1])),
          error_type: String(el["error_type"] ?? ""),
          speech_error_type: el["speech_error_type"] != null ? String(el["speech_error_type"]) : null,
          rule_name_en: ruleName?.["en"] != null ? String(ruleName["en"]) : null,
          rule_name_ar: ruleName?.["ar"] != null ? String(ruleName["ar"]) : null,
          expected_len: el["expected_len"] != null ? Number(el["expected_len"]) : null,
          predicted_len: el["predicted_len"] != null ? Number(el["predicted_len"]) : null,
        });
      } catch { /* skip malformed row, like Ktor's mapNotNull */ }
    }
  }

  const sifatErrors: SifatRow[] = [];
  if (Array.isArray(root["sifat_errors"])) {
    for (const el of root["sifat_errors"] as Record<string, unknown>[]) {
      try {
        sifatErrors.push({
          id: cryptoRandomUuid(),
          session_id: "",
          phonemes_group: String(el["phonemes_group"] ?? ""),
          attribute: String(el["attribute"] ?? ""),
          predicted: String(el["predicted"] ?? ""),
          expected: String(el["expected"] ?? ""),
          confidence: el["confidence"] != null ? Number(el["confidence"]) : null,
        });
      } catch { /* skip */ }
    }
  }

  return { allCorrect, mistakes, sifatErrors };
}

// Minimal PostgREST client — service-role key bypasses RLS exactly like the
// backend's HikariCP connection does. No SDK dependency needed.
function pgRest(table: string) {
  return {
    upsert: async (body: unknown, onConflict: string) => {
      const r = await fetch(`${SUPABASE_URL}/rest/v1/${table}`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          apikey: SERVICE_ROLE_KEY,
          Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
          Prefer: `resolution=merge-duplicates,return=minimal,on_conflict=${onConflict}`,
        },
        body: JSON.stringify(body),
      });
      if (!r.ok) throw new Error(`upsert ${table}: ${r.status} ${await r.text()}`);
    },
    insert: async (body: unknown) => {
      const r = await fetch(`${SUPABASE_URL}/rest/v1/${table}`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          apikey: SERVICE_ROLE_KEY,
          Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
          Prefer: "return=minimal",
        },
        body: JSON.stringify(body),
      });
      if (!r.ok) throw new Error(`insert ${table}: ${r.status} ${await r.text()}`);
    },
  };
}

async function persist(
  userId: string,
  sura: number,
  aya: number,
  parsed: ReturnType<typeof parseEngineBody>,
): Promise<void> {
  // Upsert users row (mirrors UserRepository.upsert / /auth/sync) so the
  // sessions.user_id FK has a target.
  await pgRest("users").upsert({ id: userId, email: null }, "id");

  const sessionId = cryptoRandomUuid();
  await pgRest("sessions").insert({
    id: sessionId,
    user_id: userId,
    sura,
    aya,
    all_correct: parsed.allCorrect,
  });

  if (parsed.mistakes.length > 0) {
    await pgRest("mistakes").insert(
      parsed.mistakes.map((m) => ({ ...m, session_id: sessionId })),
    );
  }
  if (parsed.sifatErrors.length > 0) {
    await pgRest("sifat_mistakes").insert(
      parsed.sifatErrors.map((s) => ({ ...s, session_id: sessionId })),
    );
  }
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
  const sura = Number.parseInt(String(form.get("sura") ?? "1"), 10);
  const aya = Number.parseInt(String(form.get("aya") ?? "1"), 10);

  if (!(audio instanceof File)) {
    return json({ error: "bad_request", message: "missing audio field" }, 400);
  }
  const audioBytes = new Uint8Array(await audio.arrayBuffer());
  if (audioBytes.length === 0) {
    return json({ error: "bad_request", message: "missing audio field" }, 400);
  }
  if (audioBytes.length > 10 * 1024 * 1024) {
    return json({ error: "payload_too_large", message: "audio exceeds 10MB" }, 413);
  }

  // Forward to Modal /correct — audio multipart, sura/aya as query params
  // (same shape the Ktor client sends). 60s budget covers cold start.
  const fd = new FormData();
  fd.append("audio", new Blob([audioBytes], { type: "audio/wav" }), "recording.wav");

  let engineResp: Response;
  try {
    engineResp = await fetch(`${MUAALEM_URL}?sura=${sura}&aya=${aya}`, {
      method: "POST",
      body: fd,
      signal: AbortSignal.timeout(60_000),
    });
  } catch {
    return json({ error: "ml_unavailable", message: "recitation engine did not respond" }, 503);
  }

  const engineBody = await engineResp.text();

  if (engineResp.status < 200 || engineResp.status >= 300) {
    return new Response(engineBody, { status: engineResp.status, headers: JSON_HEADERS });
  }

  // Persist, but never fail a real ML result because storage hiccuped —
  // mirroring Ktor: Success(engineBody) only after persistence; on persistence
  // failure return 500 like PersistenceFailed.
  const userId = userIdFromRequest(req);
  if (SERVICE_ROLE_KEY && userId) {
    try {
      const parsed = parseEngineBody(engineBody);
      await persist(userId, sura, aya, parsed);
    } catch (e) {
      console.error("persistence failed:", e instanceof Error ? e.message : String(e));
      return json({ error: "persistence_error", message: "failed to save session" }, 500);
    }
  } else {
    console.log("persistence skipped:", !SERVICE_ROLE_KEY ? "no SERVICE_ROLE_KEY" : "no userId");
  }

  // Return engine body unchanged — the app parses it itself.
  return new Response(engineBody, { status: 200, headers: JSON_HEADERS });
});
