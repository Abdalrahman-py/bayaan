-- Edge Functions migration — GET /progress needs a group-by-count aggregate
-- across sessions+mistakes and sessions+sifat_mistakes that plain PostgREST
-- (no embedded-aggregate reliance, keep this simple/portable) can't express.
-- Mirrors MistakeRepository.countByRuleForUser / SifatMistakeRepository.countByAttributeForUser.

create or replace function progress_summary(p_user_id uuid) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_total_sessions bigint;
  v_perfect_sessions bigint;
  v_mistake_breakdown jsonb;
  v_sifat_breakdown jsonb;
  v_total_mistakes bigint;
begin
  select count(*) into v_total_sessions from sessions where user_id = p_user_id;
  select count(*) into v_perfect_sessions from sessions where user_id = p_user_id and all_correct = true;

  select coalesce(jsonb_object_agg(rule, cnt), '{}'::jsonb), coalesce(sum(cnt), 0)
    into v_mistake_breakdown, v_total_mistakes
    from (
      select coalesce(m.rule_name_en, 'Other') as rule, count(*) as cnt
      from sessions s join mistakes m on m.session_id = s.id
      where s.user_id = p_user_id
      group by coalesce(m.rule_name_en, 'Other')
    ) t;

  select coalesce(jsonb_object_agg(attribute, cnt), '{}'::jsonb)
    into v_sifat_breakdown
    from (
      select sm.attribute as attribute, count(*) as cnt
      from sessions s join sifat_mistakes sm on sm.session_id = s.id
      where s.user_id = p_user_id
      group by sm.attribute
    ) t;

  return jsonb_build_object(
    'total_sessions', v_total_sessions,
    'perfect_sessions', v_perfect_sessions,
    'overall_accuracy', case when v_total_sessions = 0 then 0
                              else v_perfect_sessions::numeric / v_total_sessions end,
    'total_mistakes', coalesce(v_total_mistakes, 0),
    'mistake_breakdown', v_mistake_breakdown,
    'sifat_breakdown', v_sifat_breakdown
  );
end;
$$;

grant execute on function progress_summary(uuid) to authenticated;
