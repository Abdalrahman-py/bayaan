// Port of AuthRoutes.kt — POST /auth/sync.
import { handlePreflight } from "../_shared/cors.ts";
import { userIdFromRequest } from "../_shared/auth.ts";
import { err, json } from "../_shared/response.ts";
import { pgSelect, pgUpsert, qs } from "../_shared/db.ts";

Deno.serve(async (req) => {
  const preflight = handlePreflight(req);
  if (preflight) return preflight;

  const userId = userIdFromRequest(req);
  if (!userId) return err(401, "unauthorized", "Missing or invalid token");

  try {
    const existing = await pgSelect<{ id: string }>("users", `select=id&id=eq.${qs(userId)}`);
    const created = existing.length === 0;
    if (created) await pgUpsert("users", { id: userId }, "id", true);
    return json({ user_id: userId, created });
  } catch (e) {
    console.error("auth-sync function error:", e instanceof Error ? e.message : String(e));
    return err(500, "internal_error", "Unexpected server error");
  }
});
