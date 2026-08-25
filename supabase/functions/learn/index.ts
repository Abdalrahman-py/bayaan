// Port of LearnRoutes.kt (Ktor) — GET /learn/path, POST /learn/complete,
// GET /learn/reviews, POST /learn/reviews/{id}/result, POST /learn/placement.
// Writes go through RPC (learn_complete, review_record_result, record_placement —
// backend/sql/0002 + 0003) for atomicity; reads use service-role PostgREST.
// Curriculum lives in curriculum_units/curriculum_lessons (backend/sql/0005),
// not a bundled file — `position` encodes both unit order and lesson order
// within a unit, read together as the global gating order /learn/path needs.
import { handlePreflight } from "../_shared/cors.ts";
import { userIdFromRequest } from "../_shared/auth.ts";
import { err, json } from "../_shared/response.ts";
import { isUuid, pgRpc, pgSelect, pgUpsert, qs } from "../_shared/db.ts";

// Ktor deserializes into a non-nullable Double and 400s automatically on a
// missing/malformed field; req.json() here just gives us `unknown`, so bad
// numeric input (missing, "abc", null) needs the same explicit rejection —
// otherwise it becomes NaN and corrupts state silently (e.g. a NaN score
// compares false against every threshold in the RPC, never "passing").
// Must special-case null/undefined/"" first: Number(null) === 0, which is
// finite, so an absent query param would silently become 0 instead of falling
// through to the caller's `?? default` — found by an independent review pass.
function finiteNumber(value: unknown): number | null {
  if (value === null || value === undefined || value === "") return null;
  const n = Number(value);
  return Number.isFinite(n) ? n : null;
}

const XP_LESSON_BASE = 10;
const XP_CHECKPOINT_BASE = 20;
const XP_PER_CORRECT = 2;

interface CurriculumLessonRow {
  lesson_id: string;
  unit_id: string;
  title_en: string;
  title_ar: string;
  is_checkpoint: boolean;
  position: number;
}
interface CurriculumUnitRow {
  unit_id: string;
  track: string;
  title_en: string;
  title_ar: string;
  position: number;
}
interface CurriculumUnit extends CurriculumUnitRow {
  lessons: CurriculumLessonRow[];
}

async function loadCurriculum(): Promise<CurriculumUnit[]> {
  const [unitRows, lessonRows] = await Promise.all([
    pgSelect<CurriculumUnitRow>("curriculum_units", "select=*&order=position.asc"),
    pgSelect<CurriculumLessonRow>("curriculum_lessons", "select=*&order=unit_id.asc,position.asc"),
  ]);
  const lessonsByUnit = new Map<string, CurriculumLessonRow[]>();
  for (const l of lessonRows) {
    const list = lessonsByUnit.get(l.unit_id) ?? [];
    list.push(l);
    lessonsByUnit.set(l.unit_id, list);
  }
  return unitRows.map((u) => ({ ...u, lessons: lessonsByUnit.get(u.unit_id) ?? [] }));
}

async function findLesson(lessonId: string): Promise<CurriculumLessonRow | null> {
  const rows = await pgSelect<CurriculumLessonRow>(
    "curriculum_lessons",
    `select=*&lesson_id=eq.${qs(lessonId)}`,
  );
  return rows[0] ?? null;
}

async function ensureProfile(userId: string) {
  await pgUpsert("users", { id: userId }, "id", true);
  await pgUpsert("profiles", { user_id: userId }, "user_id", true);
  const rows = await pgSelect<Record<string, unknown>>(
    "profiles",
    `select=*&user_id=eq.${qs(userId)}`,
  );
  return rows[0];
}

async function reviewsDueCount(userId: string, today: string): Promise<number> {
  const rows = await pgSelect<{ id: string }>(
    "review_items",
    `select=id&user_id=eq.${qs(userId)}&due_on=lte.${today}`,
  );
  return rows.length;
}

function toHeader(profile: Record<string, unknown>, reviewsDue: number) {
  return {
    arabic_level: profile.arabic_level,
    xp: profile.xp,
    streak_count: profile.streak_count,
    daily_goal_minutes: profile.daily_goal_minutes,
    reviews_due: reviewsDue,
  };
}

async function handlePath(userId: string) {
  const today = new Date().toISOString().slice(0, 10);
  const [profile, units] = await Promise.all([ensureProfile(userId), loadCurriculum()]);
  const progressRows = await pgSelect<{ lesson_id: string; status: string; best_score: number; attempts: number }>(
    "lesson_progress",
    `select=lesson_id,status,best_score,attempts&user_id=eq.${qs(userId)}`,
  );
  const progress = new Map(progressRows.map((r) => [r.lesson_id, r]));
  const reviewsDue = await reviewsDueCount(userId, today);

  let prevCompleted = true;
  const responseUnits = units.map((unit) => ({
    unit_id: unit.unit_id,
    track: unit.track,
    title_en: unit.title_en,
    title_ar: unit.title_ar,
    lessons: unit.lessons.map((lesson) => {
      const state = progress.get(lesson.lesson_id);
      const status = state?.status === "completed"
        ? "completed"
        : state?.status === "in_progress"
        ? "in_progress"
        : prevCompleted
        ? "available"
        : "locked";
      prevCompleted = status === "completed";
      return {
        lesson_id: lesson.lesson_id,
        title_en: lesson.title_en,
        title_ar: lesson.title_ar,
        is_checkpoint: lesson.is_checkpoint,
        status,
        best_score: state?.best_score ?? 0,
        attempts: state?.attempts ?? 0,
      };
    }),
  }));

  return json({ header: toHeader(profile, reviewsDue), units: responseUnits });
}

async function handleComplete(userId: string, req: Request) {
  const body = await req.json();
  const lesson = await findLesson(body.lesson_id);
  if (!lesson) return err(404, "not_found", "Unknown lesson_id");

  const isCheckpoint = lesson.is_checkpoint;
  const rawScore = finiteNumber(body.score);
  if (rawScore === null) return err(400, "bad_request", "score must be a number");
  const score = Math.min(1, Math.max(0, rawScore));
  const itemResults = (body.item_results ?? []) as { item_ref: string; correct: boolean; first_try?: boolean }[];
  const firstTryCorrect = itemResults.filter((r) => r.correct && r.first_try).length;
  const base = isCheckpoint ? XP_CHECKPOINT_BASE : XP_LESSON_BASE;
  const xpAwarded = base + XP_PER_CORRECT * firstTryCorrect;
  const reason = isCheckpoint ? "checkpoint_complete" : "lesson_complete";
  const weakRefs = itemResults.filter((r) => !r.correct).map((r) => r.item_ref);

  const header = await pgRpc<Record<string, unknown>>("learn_complete", {
    p_user_id: userId,
    p_lesson_id: body.lesson_id,
    p_is_checkpoint: isCheckpoint,
    p_score: score,
    p_item_results: JSON.stringify(itemResults),
    p_xp_amount: xpAwarded,
    p_xp_reason: reason,
    p_weak_refs: weakRefs,
  });

  return json({ header });
}

async function handleReviews(userId: string, req: Request) {
  const url = new URL(req.url);
  const rawLimit = finiteNumber(url.searchParams.get("limit")) ?? 20;
  const limit = Math.min(100, Math.max(1, rawLimit));
  const today = new Date().toISOString().slice(0, 10);
  const rows = await pgSelect<{ id: string; item_ref: string; due_on: string }>(
    "review_items",
    `select=id,item_ref,due_on&user_id=eq.${qs(userId)}&due_on=lte.${today}&order=due_on.asc&limit=${limit}`,
  );
  return json({
    reviews: rows.map((r) => ({ review_id: r.id, item_ref: r.item_ref, due_on: r.due_on })),
  });
}

async function handleReviewResult(userId: string, req: Request, reviewId: string) {
  const body = await req.json();
  const result = await pgRpc<{ next_due_on: string; reviews_due: number } | null>(
    "review_record_result",
    { p_user_id: userId, p_review_id: reviewId, p_correct: Boolean(body.correct) },
  );
  if (!result) return err(404, "not_found", "Review item not found");
  return json(result);
}

async function handlePlacement(userId: string, req: Request) {
  const body = await req.json();
  const itemResults = (body.item_results ?? []) as { item_ref: string; difficulty?: number; correct: boolean }[];

  let level = 3;
  let hits = 0;
  let misses = 0;
  for (const r of itemResults) {
    if (r.correct) { hits++; misses = 0; } else { misses++; hits = 0; }
    if (misses === 2) { level = Math.max(0, level - 1); misses = 0; }
    if (hits === 3) { level = Math.min(8, level + 1); hits = 0; }
  }

  await pgRpc("record_placement", {
    p_user_id: userId,
    p_level: level,
    p_items_json: JSON.stringify(itemResults),
  });

  return json({ arabic_level: level, placement_message_key: `placement.level.${level}` });
}

Deno.serve(async (req) => {
  const preflight = handlePreflight(req);
  if (preflight) return preflight;

  const userId = userIdFromRequest(req);
  if (!userId) return err(401, "unauthorized", "Missing or invalid token");

  const parts = new URL(req.url).pathname.split("/").filter(Boolean);
  const learnIdx = parts.indexOf("learn");
  const sub = parts.slice(learnIdx + 1); // e.g. ["path"], ["reviews", "<id>", "result"]

  try {
    if (req.method === "GET" && sub[0] === "path") return await handlePath(userId);
    if (req.method === "POST" && sub[0] === "complete") return await handleComplete(userId, req);
    if (req.method === "GET" && sub[0] === "reviews" && sub.length === 1) return await handleReviews(userId, req);
    if (req.method === "POST" && sub[0] === "reviews" && sub[2] === "result") {
      if (!isUuid(sub[1])) return err(404, "not_found", "Review item not found");
      return await handleReviewResult(userId, req, sub[1]);
    }
    if (req.method === "POST" && sub[0] === "placement") return await handlePlacement(userId, req);
    return err(404, "not_found", "Unknown route");
  } catch (e) {
    console.error("learn function error:", e instanceof Error ? e.message : String(e));
    return err(500, "internal_error", "Unexpected server error");
  }
});
