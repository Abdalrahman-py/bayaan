-- 0006 — revoke EXECUTE on the learn/progress RPCs from public + authenticated.
--
-- 2026-08-25 security fix (architecture review run 2, candidate 1):
-- learn_complete / review_record_result / record_placement / progress_summary are
-- SECURITY DEFINER (owner runs, RLS bypassed) and take p_user_id as a
-- caller-supplied parameter with NO identity check.
--
-- Two overlapping holes, both closed here:
--   1. Postgres grants EXECUTE to PUBLIC by default on create function — so even
--      the `anon` role (no login, just the public anon key) could call these RPCs
--      with an arbitrary user id: forge XP/streaks/completions/placements, or read
--      any user's progress summary. Verified live 2026-08-25 (has_function_privilege
--      showed anon_can=true for all four, via a direct grant to anon + PUBLIC).
--   2. The explicit `grant ... to authenticated` (0002:94, 0003:59+86, 0004:51)
--      extended the same power to any logged-in user.
--
-- The only intended caller is the Edge Functions via the service-role key
-- (supabase/functions/_shared/db.ts) — unaffected by this revoke.
-- Re-granting is deliberate and must come with an auth.uid() check inside the
-- function first (see _shared/db.ts ponytail note).
revoke execute on function learn_complete(uuid, text, boolean, numeric, text, int, text, text[]) from public;
revoke execute on function review_record_result(uuid, uuid, boolean) from public;
revoke execute on function record_placement(uuid, int, text) from public;
revoke execute on function progress_summary(uuid) from public;
revoke execute on function learn_complete(uuid, text, boolean, numeric, text, int, text, text[]) from authenticated;
revoke execute on function review_record_result(uuid, uuid, boolean) from authenticated;
revoke execute on function record_placement(uuid, int, text) from authenticated;
revoke execute on function progress_summary(uuid) from authenticated;
revoke execute on function learn_complete(uuid, text, boolean, numeric, text, int, text, text[]) from anon;
revoke execute on function review_record_result(uuid, uuid, boolean) from anon;
revoke execute on function record_placement(uuid, int, text) from anon;
revoke execute on function progress_summary(uuid) from anon;
