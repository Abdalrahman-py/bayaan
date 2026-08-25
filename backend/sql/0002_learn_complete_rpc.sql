-- RPC-vs-direct-DB spike (docs/decisions/edge-functions-vs-ktor.md, open item 1).
-- Ports LessonRepository.recordAttempt + ProfileRepository.addXp/bumpStreak +
-- ReviewRepository.pushWeak into one atomic call, replacing 6 separate
-- round trips (today's Ktor behavior, NOT actually atomic — a crash mid-request
-- can leave attempt recorded but streak/xp unbumped) with a single transaction.
--
-- SECURITY DEFINER: runs as the function owner so it bypasses RLS the same way
-- the Ktor backend's HikariCP connection does (all learn_* tables have RLS on,
-- zero policies). Grant to `authenticated` so an Edge Function with a user JWT
-- (verify_jwt=true) can call it directly via supabase.rpc — no service-role key
-- needed for this path.

create or replace function learn_complete(
  p_user_id uuid,
  p_lesson_id text,
  p_is_checkpoint boolean,
  p_score numeric,
  p_item_results text,
  p_xp_amount int,
  p_xp_reason text,
  p_weak_refs text[]
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_threshold numeric := case when p_is_checkpoint then 0.85 else 0.80 end;
  v_passed boolean := p_score >= v_threshold;
  v_existing record;
  v_new_best numeric;
  v_new_attempts int;
  v_new_status text;
  v_already_completed boolean;
  v_profile record;
  v_today date := (now() at time zone 'utc')::date;
  v_new_streak int;
  v_ref text;
begin
  insert into users (id) values (p_user_id) on conflict (id) do nothing;
  insert into profiles (user_id) values (p_user_id) on conflict (user_id) do nothing;

  insert into lesson_attempts (id, user_id, lesson_id, score, item_results)
  values (gen_random_uuid(), p_user_id, p_lesson_id, p_score, p_item_results);

  select * into v_existing from lesson_progress
    where user_id = p_user_id and lesson_id = p_lesson_id;
  v_new_best := greatest(coalesce(v_existing.best_score, 0), p_score);
  v_new_attempts := coalesce(v_existing.attempts, 0) + 1;
  v_already_completed := coalesce(v_existing.status, '') = 'completed';
  v_new_status := case when v_passed then 'completed' else coalesce(v_existing.status, 'in_progress') end;

  insert into lesson_progress (user_id, lesson_id, status, best_score, attempts, completed_at)
  values (p_user_id, p_lesson_id, v_new_status, v_new_best, v_new_attempts,
          case when v_passed and not v_already_completed then now() else v_existing.completed_at end)
  on conflict (user_id, lesson_id) do update
    set status = excluded.status,
        best_score = excluded.best_score,
        attempts = excluded.attempts,
        completed_at = coalesce(lesson_progress.completed_at, excluded.completed_at);

  insert into xp_events (id, user_id, amount, reason)
  values (gen_random_uuid(), p_user_id, p_xp_amount, p_xp_reason);

  update profiles set xp = xp + p_xp_amount, updated_at = now() where user_id = p_user_id;

  select * into v_profile from profiles where user_id = p_user_id;
  v_new_streak := case
    when v_profile.streak_updated_on = v_today then v_profile.streak_count
    when v_profile.streak_updated_on = v_today - 1 then v_profile.streak_count + 1
    else 1
  end;
  update profiles set streak_count = v_new_streak, streak_updated_on = v_today, updated_at = now()
    where user_id = p_user_id;

  foreach v_ref in array coalesce(p_weak_refs, array[]::text[]) loop
    insert into review_items (id, user_id, item_ref, interval_days, due_on)
    values (gen_random_uuid(), p_user_id, v_ref, 1, v_today + 1)
    on conflict (user_id, item_ref) do nothing;
  end loop;

  select * into v_profile from profiles where user_id = p_user_id;
  return jsonb_build_object(
    'arabic_level', v_profile.arabic_level,
    'xp', v_profile.xp,
    'streak_count', v_profile.streak_count,
    'daily_goal_minutes', v_profile.daily_goal_minutes,
    'reviews_due', (select count(*) from review_items
                     where user_id = p_user_id and due_on <= v_today)
  );
end;
$$;

grant execute on function learn_complete(uuid, text, boolean, numeric, text, int, text, text[])
  to authenticated;
