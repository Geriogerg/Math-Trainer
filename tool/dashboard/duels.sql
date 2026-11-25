-- Phase 7 commit 8: online play, for the owner (`dashboard.sh duels`).

\echo '== Duels per day, last 14 days (unanswered: opened over an hour ago, no run)'
select day, mode, kind, decided, rated, void, open, unanswered
from owner_dashboard.duels_per_day
where day > (now() at time zone 'utc')::date - 14
order by day desc, mode, kind;

\echo
\echo '== Ratings per mode, bands of 100 (provisional: fewer than 10 rated duels)'
select mode, band, players, provisional, mean_deviation as "mean RD"
from owner_dashboard.duel_rating_distribution
order by mode, band;

\echo
\echo '== Flagged runs (kept out of the pool until reviewed)'
\echo '   back in the pool: bash tool/dashboard/dashboard.sh review-run <run_id> ok'
\echo '   out for good:     bash tool/dashboard/dashboard.sh review-run <run_id> reject'
select run_id, to_char(created_at, 'YYYY-MM-DD HH24:MI') as at, mode, player, flags, review,
  score, serves
from owner_dashboard.flagged_runs
order by created_at desc limit 30;

\echo
\echo '== Players leaving duels unanswered'
select player_id, player, unanswered, to_char(last, 'YYYY-MM-DD HH24:MI') as last
from owner_dashboard.unanswered_duels
order by unanswered desc limit 20;

\echo
\echo '== Friends'
select * from owner_dashboard.friend_counts;
