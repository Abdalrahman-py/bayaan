// Port of ProgressRoutes.kt — GET /progress, /progress/sessions, /progress/sessions/{id}.
import { handlePreflight } from "../_shared/cors.ts";
import { userIdFromRequest } from "../_shared/auth.ts";
import { err, json } from "../_shared/response.ts";
import { isUuid, pgCount, pgRpc, pgSelect, qs } from "../_shared/db.ts";

// Number(null) === 0, which is finite — must special-case null/undefined/""
// first or an absent query param silently becomes 0 instead of the default.
// Found by an independent review pass; see learn/index.ts for the full note.
function finiteNumber(value: unknown): number | null {
  if (value === null || value === undefined || value === "") return null;
  const n = Number(value);
  return Number.isFinite(n) ? n : null;
}

interface SessionRow {
  id: string;
  sura: number;
  aya: number;
  all_correct: boolean;
  created_at: string;
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

async function handleSummary(userId: string) {
  const summary = await pgRpc("progress_summary", { p_user_id: userId });
  return json(summary);
}

async function handleSessions(userId: string, req: Request) {
  const url = new URL(req.url);
  const limit = Math.min(100, Math.max(1, finiteNumber(url.searchParams.get("limit")) ?? 20));
  const offset = Math.max(0, finiteNumber(url.searchParams.get("offset")) ?? 0);

  const total = await pgCount("sessions", `select=id&user_id=eq.${qs(userId)}`);
  const sessions = await pgSelect<SessionRow>(
    "sessions",
    `select=id,sura,aya,all_correct,created_at&user_id=eq.${qs(userId)}&order=created_at.desc&limit=${limit}&offset=${offset}`,
  );

  const ids = sessions.map((s) => s.id);
  const counts = new Map<string, number>();
  if (ids.length > 0) {
    const mistakes = await pgSelect<{ session_id: string }>(
      "mistakes",
      `select=session_id&session_id=in.(${ids.join(",")})`,
    );
    for (const m of mistakes) counts.set(m.session_id, (counts.get(m.session_id) ?? 0) + 1);
  }

  return json({
    sessions: sessions.map((s) => ({
      session_id: s.id,
      sura: s.sura,
      aya: s.aya,
      all_correct: s.all_correct,
      mistakes_count: counts.get(s.id) ?? 0,
      created_at: s.created_at,
    })),
    total,
    limit,
    offset,
  });
}

async function handleSessionDetail(userId: string, sessionId: string) {
  const sessions = await pgSelect<SessionRow>(
    "sessions",
    `select=id,sura,aya,all_correct,created_at&id=eq.${qs(sessionId)}&user_id=eq.${qs(userId)}`,
  );
  const session = sessions[0];
  if (!session) return err(404, "not_found", "Session not found");

  const mistakes = await pgSelect<MistakeRow>(
    "mistakes",
    `select=id,char_start,char_end,error_type,speech_error_type,rule_name_en,rule_name_ar,expected_len,predicted_len&session_id=eq.${qs(sessionId)}`,
  );

  return json({
    session_id: session.id,
    sura: session.sura,
    aya: session.aya,
    all_correct: session.all_correct,
    created_at: session.created_at,
    mistakes: mistakes.map((m) => ({
      id: m.id,
      char_start: m.char_start,
      char_end: m.char_end,
      error_type: m.error_type,
      speech_error_type: m.speech_error_type,
      rule_name_en: m.rule_name_en,
      rule_name_ar: m.rule_name_ar,
      expected_len: m.expected_len,
      predicted_len: m.predicted_len,
    })),
  });
}

Deno.serve(async (req) => {
  const preflight = handlePreflight(req);
  if (preflight) return preflight;

  const userId = userIdFromRequest(req);
  if (!userId) return err(401, "unauthorized", "Missing or invalid token");

  const parts = new URL(req.url).pathname.split("/").filter(Boolean);
  const idx = parts.indexOf("progress");
  const sub = parts.slice(idx + 1); // [], ["sessions"], ["sessions", "<id>"]

  try {
    if (req.method === "GET" && sub.length === 0) return await handleSummary(userId);
    if (req.method === "GET" && sub[0] === "sessions" && sub.length === 1) {
      return await handleSessions(userId, req);
    }
    if (req.method === "GET" && sub[0] === "sessions" && sub.length === 2) {
      if (!isUuid(sub[1])) return err(404, "not_found", "Session not found");
      return await handleSessionDetail(userId, sub[1]);
    }
    return err(404, "not_found", "Unknown route");
  } catch (e) {
    console.error("progress function error:", e instanceof Error ? e.message : String(e));
    return err(500, "internal_error", "Unexpected server error");
  }
});
