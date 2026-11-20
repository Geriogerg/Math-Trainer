-- Beta progress (Phase 5.1 commit 4, plan v2.6): how far the beta is from
-- Phase 3b's entry — ~300 completed games from 10+ testers — and who is
-- still playing. Printed first by `dashboard.sh report`.
--
-- In owner_dashboard (never served by the API). Idempotent: new views,
-- `create or replace` holds when CI applies the migration twice.

-- One row. A tester is a player with at least one completed game (the
-- threshold's own definition, `calibration_readiness`). The pace is the
-- last 7 days' completed games; at that pace, the days still needed for
-- 300 (null while nothing was played this week).
create or replace view owner_dashboard.beta_progress as
with games as (
  select player_id, created_at
  from public.uploaded_sessions
  where kind = 'game' and completed
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
  (now()::date - t.first_game_at::date) as days_since_first_game
from totals t;

-- Every player who uploaded anything: their code, name, games, and how
-- long since they last played — who to nudge. Most recently active first;
-- never active at the end.
create or replace view owner_dashboard.tester_activity as
select
  left(s.player_id::text, 8) as player,
  coalesce(c.label, '(no code)') as invited_as,
  pr.display_name as name,
  count(*) filter (where s.kind = 'game' and s.completed) as games_completed,
  count(*) filter (where s.kind = 'game' and not s.completed) as games_interrupted,
  count(*) filter (where s.kind <> 'game') as placements,
  min(s.created_at) as first_at,
  max(s.created_at) filter (where s.kind = 'game') as last_game_at,
  (now()::date - (max(s.created_at) filter (where s.kind = 'game'))::date) as days_since_last_game
from public.uploaded_sessions s
left join public.beta_code_uses u on u.player_id = s.player_id
left join public.beta_codes c on c.code = u.code
left join public.profiles pr on pr.id = s.player_id
group by s.player_id, c.label, pr.display_name
order by last_game_at desc nulls last, first_at desc;

revoke all on all tables in schema owner_dashboard from public, anon, authenticated;
