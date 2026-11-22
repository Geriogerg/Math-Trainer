-- The owner's beta report (Phase 3a commit 6): the views of
-- `owner_dashboard` (supabase/migrations/…_owner_dashboard.sql), printed
-- by `tool/dashboard/dashboard.sh report`. Read-only.

\pset footer off
\pset null '—'

\echo
\echo '== Calibration progress: Phase 3b starts at ~300 completed games from 10+ testers,'
\echo '   counted since the Redesign release (owner_dashboard.calibration_window)'
select
  completed_games || ' / ' || games_needed || ' (' || games_pct || ' %)' as games,
  testers || ' / ' || testers_needed || ' (' || testers_pct || ' %)' as testers,
  case when ready then 'yes' else 'not yet' end as ready,
  games_per_tester as "games per tester",
  median_games_per_tester as "median",
  games_last_7_days as "games, last 7 days",
  days_to_300_at_this_pace as "days to 300 at this pace",
  days_since_first_game as "window day",
  to_char(window_starts_at, 'YYYY-MM-DD') as "window since"
from owner_dashboard.calibration_progress;

\echo
\echo '== Testers: games and days since the last one (who to nudge)'
select player, invited_as, name, games_completed as games, games_interrupted as interrupted,
  trainings, placements, to_char(last_game_at, 'YYYY-MM-DD') as last_game,
  days_since_last_game as "days since"
from owner_dashboard.player_activity;

\echo
\echo '== Active testers (at least one game uploaded)'
select * from owner_dashboard.active_testers;

\echo
\echo '== Sessions per day, last 14 days (UTC)'
select * from owner_dashboard.sessions_per_day limit 14;

\echo
\echo '== Testers by invitation code'
select code, players, games_completed, to_char(last_session_at, 'YYYY-MM-DD HH24:MI') as last_session
from owner_dashboard.testers_by_code;

\echo
\echo '== Answer times per operation, level band and input device (games only)'
select * from owner_dashboard.answer_times_by_input;

\echo
\echo '== Games per app version (build)'
select app_version, games, placements, players,
  to_char(first_at, 'YYYY-MM-DD HH24:MI') as first, to_char(last_at, 'YYYY-MM-DD HH24:MI') as last
from owner_dashboard.app_versions;

\echo
\echo '== Games interrupted before the end'
select * from owner_dashboard.abandonment;

\echo
\echo '== Refused uploads, last 30 days'
select reason, uploads, players, to_char(last_at, 'YYYY-MM-DD HH24:MI') as last
from owner_dashboard.refusals;

\echo
\echo '== Flagged games (implausible timing; never refused), last 30 days'
select flag, sessions, players, to_char(last_at, 'YYYY-MM-DD HH24:MI') as last
from owner_dashboard.flags;

\echo
\echo '== Names reported, awaiting review'
\echo '   approve: bash tool/dashboard/dashboard.sh approve-name <player_id>'
\echo '   remove:  bash tool/dashboard/dashboard.sh clear-name <player_id>'
\echo '   (SQL: select owner_dashboard.review_name(''<player_id>'', ''approve'' | ''clear'');)'
select player_id, display_name, reports,
  case when hidden then 'hidden' else 'shown' end as now,
  to_char(last_report_at, 'YYYY-MM-DD HH24:MI') as last_report
from owner_dashboard.names_to_review;

\echo
\echo '== Latest feedback (all: bash tool/dashboard/dashboard.sh feedback)'
select to_char(created_at, 'YYYY-MM-DD HH24:MI') as at, app_version, player, message
from owner_dashboard.recent_feedback limit 10;

\echo
\echo '== Stale-guest cleanup job (Supabase pg_cron)'
select to_regclass('cron.job') is not null as has_cron \gset
\if :has_cron
select jobname, schedule, case when active then 'active' else 'INACTIVE' end as state
from cron.job where jobname = 'cleanup-stale-guests';
select status, to_char(start_time, 'YYYY-MM-DD HH24:MI') as last_run, return_message
from cron.job_run_details d
join cron.job j on j.jobid = d.jobid and j.jobname = 'cleanup-stale-guests'
order by start_time desc limit 3;
\else
\echo '   pg_cron is not installed in this database.'
\endif
