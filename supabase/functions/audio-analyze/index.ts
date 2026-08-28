// audio-analyze — Deno Edge Function for POST /audio/analyze (the core loop).
//
// Thin orchestrator: validate multipart at the boundary, forward audio to Modal
// /correct via the shared forward adapter, PARSE the engine body before
// persisting (unparseable -> 503 ml_unavailable, per api-spec.md:105), persist
// session + mistakes + sifat_mistakes, return the engine body unchanged.
//
// All dialect knowledge (field names, the preditected_ph misspelling, all_correct
// semantics, drop-malformed-rows) lives in ../_shared/engine-contract.ts.
//
// verify_jwt=true on deploy: Supabase validates the Bearer JWT and injects the
// verified claims into x-supabase-auth.
import { CORS_HEADERS, handlePreflight } from "../_shared/cors.ts";
import { forwardMultipart, parseEngineBody } from "../_shared/engine-contract.ts";

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

function cryptoRandomUuid(): string {
  return crypto.randomUUID();
}

// Minimal PostgREST client — service-role key bypasses RLS exactly like the
// backend's HikariCP connection did. No SDK dependency needed.
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
  // Upsert users row (mirrors /auth-sync) so the sessions.user_id FK has a target.
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
      parsed.mistakes.map((m) => ({ ...m, id: cryptoRandomUuid(), session_id: sessionId })),
    );
  }
  if (parsed.sifatErrors.length > 0) {
    await pgRest("sifat_mistakes").insert(
      parsed.sifatErrors.map((s) => ({ ...s, id: cryptoRandomUuid(), session_id: sessionId })),
    );
  }
}

// Madd lengths are counts in harakāt (docs/CODEBASE_MAP.md:179), not seconds,
// and the engine only accepts a small range. Anything outside it is dropped so
// the engine applies its own Hafs default rather than grading against garbage.
const MADD_KEYS = [
  "madd_monfasel_len",
  "madd_mottasel_len",
  "madd_mottasel_waqf",
  "madd_aared_len",
] as const;

function maddQuery(form: FormData): string {
  return MADD_KEYS.map((k) => {
    const raw = String(form.get(k) ?? "");
    return /^[2-6]$/.test(raw) ? `&${k}=${raw}` : "";
  }).join("");
}

// Strict integer-or-default parsing for sura/aya: garbage -> default 1, never NaN
// in the Modal query string (Ktor used toIntOrNull()?.let ?: 1).
function intParam(form: FormData, name: string): number {
  const raw = String(form.get(name) ?? "");
  if (/^[1-9]\d*$/.test(raw)) return Number(raw);
  return 1;
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
  const sura = intParam(form, "sura");
  const aya = intParam(form, "aya");

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
  // (same shape the Ktor client sent). 60s budget covers cold start.
  const fd = new FormData();
  fd.append("audio", new Blob([audioBytes], { type: "audio/wav" }), "recording.wav");

  let engineResp;
  try {
    engineResp = await forwardMultipart(
      `${MUAALEM_URL}?sura=${sura}&aya=${aya}${maddQuery(form)}`,
      fd,
    );
  } catch {
    return json({ error: "ml_unavailable", message: "recitation engine did not respond" }, 503);
  }

  if (engineResp.status < 200 || engineResp.status >= 300) {
    // Engine answered with an error — pass its body through unchanged.
    return new Response(engineResp.body, { status: engineResp.status, headers: JSON_HEADERS });
  }

  // Parse BEFORE persisting: an unparseable engine body is an engine problem,
  // not a storage problem -> 503 ml_unavailable (api-spec.md:105), not 500.
  let parsed;
  try {
    parsed = parseEngineBody(engineResp.body);
  } catch {
    return json({ error: "ml_unavailable", message: "recitation engine did not respond" }, 503);
  }

  // Persist, but never fail a real ML result because storage hiccuped —
  // mirroring Ktor: Success(engineBody) only after persistence; on persistence
  // failure return 500 like PersistenceFailed. Missing SERVICE_ROLE_KEY or
  // userId is a misconfiguration, not a testing shortcut: fail loudly instead
  // of silently returning 200 with nothing saved.
  const userId = userIdFromRequest(req);
  if (!SERVICE_ROLE_KEY) {
    return json({ error: "persistence_error", message: "SERVICE_ROLE_KEY not configured" }, 500);
  }
  if (!userId) {
    return json({ error: "persistence_error", message: "failed to save session" }, 500);
  }
  try {
    await persist(userId, sura, aya, parsed);
  } catch (e) {
    console.error("persistence failed:", e instanceof Error ? e.message : String(e));
    return json({ error: "persistence_error", message: "failed to save session" }, 500);
  }

  // Return engine body unchanged — the app parses it itself.
  return new Response(engineResp.body, { status: 200, headers: JSON_HEADERS });
});
