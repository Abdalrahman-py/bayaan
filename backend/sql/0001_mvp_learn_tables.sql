-- Bayaan MVP (Arabic + Tajweed tracks) — per-user learning state.
-- Scoped from docs/PRODUCTION_PLAN.md §8, MVP subset: no `tts_cache`, no `/tutor`
-- support (no-LLM / no-dynamic-TTS decisions). `sifat_mistakes` closes the persistence
-- gap so ghunnah/qalqalah tajweed lessons can grade.
--
-- HOW TO APPLY: paste into the Supabase SQL editor (dashboard) or run via an authed
-- `supabase` CLI. Safe to re-run (IF NOT EXISTS). Existing users/sessions/mistakes
-- are untouched. `gen_random_uuid()` is built in on Supabase Postgres.

create table if not exists profiles (
  user_id            uuid primary key references users(id) on delete cascade,
  arabic_level       int  not null default 0,
  xp                 int  not null default 0,
  streak_count       int  not null default 0,
  streak_updated_on  date,
  daily_goal_minutes int  not null default 10,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);

create table if not exists placement_results (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references users(id) on delete cascade,
  level      int  not null,
  items      text not null,          -- JSON-as-text (audit blob; never queried)
  created_at timestamptz not null default now()
);

create table if not exists lesson_progress (
  user_id      uuid not null references users(id) on delete cascade,
  lesson_id    text not null,
  status       text not null,        -- 'in_progress' | 'completed'; locked/available derived at read
  best_score   numeric not null default 0,
  attempts     int  not null default 0,
  completed_at timestamptz,
  primary key (user_id, lesson_id)
);

create table if not exists lesson_attempts (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references users(id) on delete cascade,
  lesson_id     text not null,
  score         numeric not null,
  item_results  text not null,       -- JSON-as-text
  coach_summary text,                -- reserved; unused in MVP (no LLM)
  created_at    timestamptz not null default now()
);

create table if not exists review_items (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references users(id) on delete cascade,
  item_ref      text not null,
  ease          numeric not null default 2.5,  -- reserved; unused by the MVP interval ladder
  interval_days int  not null default 1,
  due_on        date not null,
  lapses        int  not null default 0,
  unique (user_id, item_ref)
);

create table if not exists xp_events (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references users(id) on delete cascade,
  amount     int  not null,
  reason     text not null,
  created_at timestamptz not null default now()
);

create table if not exists sifat_mistakes (
  id             uuid primary key default gen_random_uuid(),
  session_id     uuid not null references sessions(id) on delete cascade,
  phonemes_group text not null,
  attribute      text not null,
  predicted      text not null,
  expected       text not null,
  confidence     numeric,
  created_at     timestamptz not null default now()
);

-- hot-read indexes
create index if not exists idx_review_items_due     on review_items   (user_id, due_on);
create index if not exists idx_sifat_mistakes_sess  on sifat_mistakes (session_id);
create index if not exists idx_lesson_attempts_user on lesson_attempts(user_id, lesson_id);

-- RLS: these hold per-user data and live in the exposed `public` schema. The Ktor
-- backend accesses them via the service/owner connection (bypasses RLS), and the
-- Android client never reads them directly (everything goes through /learn/* — §8).
-- So enable RLS with NO policies: locks the tables to anon/authenticated (no Data API
-- access) with zero backend impact. If the client ever reads a table directly, add a
-- `to authenticated using ((select auth.uid()) = user_id)` policy for that table then.
alter table profiles          enable row level security;
alter table placement_results enable row level security;
alter table lesson_progress   enable row level security;
alter table lesson_attempts   enable row level security;
alter table review_items      enable row level security;
alter table xp_events         enable row level security;
alter table sifat_mistakes    enable row level security;
