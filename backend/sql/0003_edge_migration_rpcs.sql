-- Edge Functions migration (docs/decisions/edge-functions-vs-ktor.md) — the two
-- remaining /learn/* writes, ported to RPC for the same reason learn_complete was
-- (0002): atomic multi-table writes, no service-role-key-in-TS transaction hand-rolling.
-- Reads stay on service-role PostgREST (single-table, no atomicity concern).

create or replace function review_record_result(
  p_user_id uuid,
  p_review_id uuid,
  p_correct boolean
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ladder int[] := array[1, 3, 7, 21];
  v_current record;
  v_idx int;
  v_new_interval int;
  v_new_lapses int;
  v_new_due date;
  v_today date := (now() at time zone 'utc')::date;
begin
  select * into v_current from review_items where id = p_review_id and user_id = p_user_id;
  if not found then
    return null;
  end if;

  if p_correct then
    v_idx := array_position(v_ladder, v_current.interval_days);
    v_new_interval := case
      when v_idx is null or v_idx = array_length(v_ladder, 1) then v_ladder[array_length(v_ladder, 1)]
      else v_ladder[v_idx + 1]
    end;
    v_new_lapses := v_current.lapses;
  else
    v_new_interval := v_ladder[1];
    v_new_lapses := v_current.lapses + 1;
  end if;
  v_new_due := v_today + v_new_interval;

  update review_items set interval_days = v_new_interval, due_on = v_new_due, lapses = v_new_lapses
    where id = p_review_id;

  if p_correct then
    insert into users (id) values (p_user_id) on conflict (id) do nothing;
    insert into profiles (user_id) values (p_user_id) on conflict (user_id) do nothing;
    insert into xp_events (id, user_id, amount, reason) values (gen_random_uuid(), p_user_id, 5, 'review_correct');
    update profiles set xp = xp + 5, updated_at = now() where user_id = p_user_id;
  end if;

  return jsonb_build_object(
    'next_due_on', v_new_due,
    'reviews_due', (select count(*) from review_items where user_id = p_user_id and due_on <= v_today)
  );
end;
$$;

grant execute on function review_record_result(uuid, uuid, boolean) to authenticated;

create or replace function record_placement(
  p_user_id uuid,
  p_level int,
  p_items_json text
) returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into users (id) values (p_user_id) on conflict (id) do nothing;
  insert into profiles (user_id) values (p_user_id) on conflict (user_id) do nothing;

  insert into placement_results (id, user_id, level, items)
  values (gen_random_uuid(), p_user_id, p_level, p_items_json);

  update profiles set arabic_level = p_level, updated_at = now() where user_id = p_user_id;

  -- Must return something, not void: PostgREST sends an empty 204 body for
  -- void, and the Edge Function's pgRpc() helper always calls r.json() on the
  -- response — an empty body throws there. Found by supabase/tests/edge_functions_test.sh.
  return true;
end;
$$;

grant execute on function record_placement(uuid, int, text) to authenticated;
