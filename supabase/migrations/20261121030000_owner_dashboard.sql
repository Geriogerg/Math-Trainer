-- Owner dashboard (Phase 3a commit 6, plan v2.3): SQL views over the
-- server's own data, printed by `tool/dashboard/dashboard.sh`. No
-- third-party analytics (plan 6.6). The views live in their own schema,
-- which the API never exposes (Supabase serves `public` only) and the API
-- roles cannot even enter: the owner reads them as the database owner.
-- Idempotent: CI applies every migration twice in its SQL tests.

create schema if not exists owner_dashboard;
revoke all on schema owner_dashboard from public, anon, authenticated;

-- Name review (plan 6.4: names are public content). A reported name the
-- owner approves stays shown whatever the reports; one they clear is gone
-- from the profile ("Player") until the player picks another.
create table if not exists public.name_reviews (
  player_id uuid not null references auth.users (id) on delete cascade,
  display_name text not null,
  reviewed_at timestamptz not null default now(),
  primary key (player_id, display_name)
);
alter table public.name_reviews enable row level security;
revoke all on public.name_reviews from anon, authenticated;

-- Same as before (Phase 2 commit 9), plus: an approved name is never
-- hidden.
create or replace function public.public_display_name(p_player_id uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when (
      select count(*) from public.name_reports r
      where r.reported_id = p_player_id and r.reported_name = pr.display_name
    ) >= 3
    and not exists (
      select from public.name_reviews v
      where v.player_id = p_player_id and v.display_name = pr.display_name
    ) then null
    else pr.display_name
  end
  from public.profiles pr
  where pr.id = p_player_id
$$;
revoke all on function public.public_display_name(uuid) from public, anon, authenticated;

-- 'approve' keeps the current name; 'clear' removes it. Returns what was
-- done, or 'no name' when the player has none.
create or replace function owner_dashboard.review_name(p_player_id uuid, p_verdict text)
returns text
language plpgsql
set search_path = ''
as $$
declare
  current_name text;
begin
  select display_name into current_name from public.profiles where id = p_player_id;
  if current_name is null then
    return 'no name';
  end if;
  if p_verdict = 'approve' then
    insert into public.name_reviews (player_id, display_name)
    values (p_player_id, current_name)
    on conflict do nothing;
    return 'approved: ' || current_name;
  elsif p_verdict = 'clear' then
    update public.profiles set display_name = null where id = p_player_id;
    return 'cleared: ' || current_name;
  end if;
  raise exception 'verdict must be approve or clear, not %', p_verdict;
end;
$$;

-- Every answer of every uploaded game, with the level its session froze
-- for that operation. Placements are left out: their level moves within
-- the session (staircase), so it does not describe the answer.
create or replace view owner_dashboard.game_answers as
select
  s.id as session_id,
  s.player_id,
  s.created_at as session_at,
  a ->> 'operationType' as operation,
  (s.payload #>> array['session', 'levels', a ->> 'operationType'])::int as level_hundredths,
  (a ->> 'elapsedMs')::int as elapsed_ms,
  (a ->> 'isCorrect')::boolean as is_correct
from public.uploaded_sessions s
cross join lateral jsonb_array_elements(s.payload -> 'answers') a
where s.kind = 'game';

-- Sessions per day (UTC, the session's own time).
create or replace view owner_dashboard.sessions_per_day as
select
  date_trunc('day', created_at)::date as day,
  count(*) filter (where kind = 'game' and completed) as games_completed,
  count(*) filter (where kind = 'game' and not completed) as games_interrupted,
  count(*) filter (where kind <> 'game') as placements,
  count(distinct player_id) as players
from public.uploaded_sessions
group by 1
order by 1 desc;

-- Testers active over the last 1, 7 and 30 days (at least one upload).
create or replace view owner_dashboard.active_testers as
select
  count(distinct player_id) filter (where created_at > now() - interval '1 day') as last_day,
  count(distinct player_id) filter (where created_at > now() - interval '7 days') as last_7_days,
  count(distinct player_id) filter (where created_at > now() - interval '30 days') as last_30_days,
  count(distinct player_id) as ever
from public.uploaded_sessions;

-- Per invitation code: who it is for, players, their games, last activity.
-- Players who came in without one (before the gate, or around it) are the
-- '(no code)' row.
create or replace view owner_dashboard.testers_by_code as
with players as (
  select p.player_id, coalesce(c.label || ' [' || c.code || ']', '(no code)') as code
  from public.server_players p
  left join public.beta_code_uses u on u.player_id = p.player_id
  left join public.beta_codes c on c.code = u.code
)
select
  pl.code,
  count(distinct pl.player_id) as players,
  count(s.id) filter (where s.kind = 'game' and s.completed) as games_completed,
  max(s.created_at) as last_session_at
from players pl
left join public.uploaded_sessions s on s.player_id = pl.player_id
group by pl.code
order by games_completed desc, pl.code;

-- The codes themselves, with their uses.
create or replace view owner_dashboard.codes as
select
  c.code, c.label, c.max_uses,
  (select count(*) from public.beta_code_uses u where u.code = c.code) as uses,
  c.disabled, c.created_at
from public.beta_codes c
order by c.created_at desc;

-- Median and spread of answer times per operation and level band
-- (1–9, 10–19, …), games only — what Phase 3b calibrates from.
create or replace view owner_dashboard.answer_times as
with banded as (
  select
    operation,
    greatest(1, (level_hundredths / 1000) * 10) as band_start,
    elapsed_ms,
    is_correct
  from owner_dashboard.game_answers
  where level_hundredths is not null
)
select
  operation,
  case when band_start = 1 then '1–9' else band_start || '–' || (band_start + 9) end as level_band,
  count(*) as answers,
  round(100.0 * avg(is_correct::int), 1) as percent_right,
  percentile_cont(0.5) within group (order by elapsed_ms)::int as median_ms,
  percentile_cont(0.25) within group (order by elapsed_ms)::int as p25_ms,
  percentile_cont(0.75) within group (order by elapsed_ms)::int as p75_ms
from banded
group by operation, band_start
order by operation, band_start;

-- Games left before the end, over the last 7 and 30 days.
create or replace view owner_dashboard.abandonment as
select
  period,
  count(*) as games,
  count(*) filter (where not completed) as interrupted,
  round(100.0 * count(*) filter (where not completed) / nullif(count(*), 0), 1) as percent_interrupted
from public.uploaded_sessions
cross join lateral (values ('7 days', interval '7 days'), ('30 days', interval '30 days')) w(period, span)
where kind = 'game' and created_at > now() - span
group by period
order by min(span);

-- Refused uploads per reason, last 30 days, and flagged ones (never
-- refused: worth a look).
create or replace view owner_dashboard.refusals as
select reason, count(*) as uploads, count(distinct player_id) as players, max(received_at) as last_at
from public.upload_rejections
where received_at > now() - interval '30 days'
group by reason
order by uploads desc;

create or replace view owner_dashboard.flags as
select f.flag, count(*) as sessions, count(distinct s.player_id) as players, max(f.created_at) as last_at
from public.upload_flags f
join public.uploaded_sessions s on s.id = f.session_id
where f.created_at > now() - interval '30 days'
group by f.flag
order by sessions desc;

-- Reported names not yet reviewed, as the players see them now.
create or replace view owner_dashboard.names_to_review as
select
  pr.id as player_id,
  pr.display_name,
  count(r.*) as reports,
  count(r.*) >= 3 as hidden,
  max(r.created_at) as last_report_at
from public.profiles pr
join public.name_reports r on r.reported_id = pr.id and r.reported_name = pr.display_name
where not exists (
  select from public.name_reviews v
  where v.player_id = pr.id and v.display_name = pr.display_name
)
group by pr.id, pr.display_name
order by reports desc, last_report_at desc;

-- Recent feedback, newest first.
create or replace view owner_dashboard.recent_feedback as
select f.created_at, f.app_version, coalesce(pr.display_name, '(no name)') as player, f.message
from public.feedback f
left join public.profiles pr on pr.id = f.player_id
order by f.created_at desc;

-- Phase 3b's entry (plan v2.3): ~300 completed sessions from 10+ testers.
create or replace view owner_dashboard.calibration_readiness as
select
  count(*) as completed_games,
  count(distinct player_id) as testers,
  count(*) >= 300 and count(distinct player_id) >= 10 as ready
from public.uploaded_sessions
where kind = 'game' and completed;

revoke all on all tables in schema owner_dashboard from public, anon, authenticated;
revoke all on function owner_dashboard.review_name(uuid, text) from public, anon, authenticated;
