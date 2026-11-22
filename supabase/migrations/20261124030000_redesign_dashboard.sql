-- The owner dashboard follows the Redesign phase (commit 9, plan v2.9).
--
-- 1. Phase 3b's ~300 games count from the Redesign phase's release: the
--    calibration window starts when this migration first reaches the
--    project (CI applies it with the release). The owner can move it:
--      update owner_dashboard.calibration_window set starts_at = '…';
-- 2. Training games are their own column, never "placements".
--
-- New view names: a view's columns cannot change under `create or
-- replace` when CI applies every migration twice; the old ones are
-- dropped. In owner_dashboard (never served by the API).

create table if not exists owner_dashboard.calibration_window (
  only_row boolean primary key default true check (only_row),
  starts_at timestamptz not null
);
insert into owner_dashboard.calibration_window (starts_at) values (now())
on conflict (only_row) do nothing;

create or replace view owner_dashboard.calibration_progress as
with games as (
  select player_id, created_at
  from public.uploaded_sessions
  where kind = 'game' and completed
    and created_at >= (select starts_at from owner_dashboard.calibration_window)
),
per_tester as (
  select player_id, count(*) as games from games group by player_id
),
totals as (
  select
    (select count(*) from games) as games,
    (select count(*) from per_tester) as testers,
    (select count(*) from games where created_at > now() - interval '7 days') as games_last_7_days,
    (select min(created_at) from games) as first_game_at
)
select
  t.games as completed_games,
  300 as games_needed,
  least(100, round(100.0 * t.games / 300)) as games_pct,
  t.testers,
  10 as testers_needed,
  least(100, round(100.0 * t.testers / 10)) as testers_pct,
  t.games >= 300 and t.testers >= 10 as ready,
  case when t.testers > 0 then round(1.0 * t.games / t.testers, 1) end as games_per_tester,
  (select percentile_disc(0.5) within group (order by games) from per_tester) as median_games_per_tester,
  t.games_last_7_days,
  case
    when t.games >= 300 then 0
    when t.games_last_7_days > 0 then ceil((300 - t.games) / (t.games_last_7_days / 7.0))::int
  end as days_to_300_at_this_pace,
  (now()::date - t.first_game_at::date) as days_since_first_game,
  (select starts_at from owner_dashboard.calibration_window) as window_starts_at
from totals t;

-- Every player who uploaded anything, Training apart from placements.
create or replace view owner_dashboard.player_activity as
select
  left(s.player_id::text, 8) as player,
  coalesce(c.label, '(no code)') as invited_as,
  pr.display_name as name,
  count(*) filter (where s.kind = 'game' and s.completed) as games_completed,
  count(*) filter (where s.kind = 'game' and not s.completed) as games_interrupted,
  count(*) filter (where s.kind = 'training' and s.completed) as trainings,
  count(*) filter (where s.kind not in ('game', 'training')) as placements,
  min(s.created_at) as first_at,
  max(s.created_at) filter (where s.kind = 'game') as last_game_at,
  (now()::date - (max(s.created_at) filter (where s.kind = 'game'))::date) as days_since_last_game
from public.uploaded_sessions s
left join public.beta_code_uses u on u.player_id = s.player_id
left join public.beta_codes c on c.code = u.code
left join public.profiles pr on pr.id = s.player_id
group by s.player_id, c.label, pr.display_name
order by last_game_at desc nulls last, first_at desc;

drop view if exists owner_dashboard.beta_progress;
drop view if exists owner_dashboard.tester_activity;

revoke all on all tables in schema owner_dashboard from public, anon, authenticated;
