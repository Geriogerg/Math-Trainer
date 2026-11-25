-- Phase 7 commit 8 (plan v3.7): the owner's view of online play, in the
-- owner_dashboard schema (never exposed by the API; `dashboard.sh duels`
-- prints it). Duels per day and mode, rating distributions, flagged runs
-- (with their review: a flagged run stays out of the pool until the owner
-- says ok), duels never answered, and friend counts.

-- Duels started per UTC day, mode and kind: decided, void (a run refused),
-- still open (a challenge in its 7 days, or a duel under way), and left
-- unanswered (a pool or practice duel opened more than an hour ago with no
-- run — quitting by closing the browser; plan v3.7 says quitting counts).
create or replace view owner_dashboard.duels_per_day as
select (d.created_at at time zone 'utc')::date as day,
  d.mode,
  d.kind,
  count(*) filter (where d.state = 'done') as decided,
  count(*) filter (where d.state = 'done' and d.rated) as rated,
  count(*) filter (where d.state = 'void') as void,
  count(*) filter (where d.state in ('awaitingFirst', 'awaitingSecond')
    and not (d.kind in ('pool', 'practice') and d.created_at < now() - interval '1 hour'))
    as open,
  count(*) filter (where d.state = 'awaitingSecond' and d.kind in ('pool', 'practice')
    and d.created_at < now() - interval '1 hour') as unanswered
from public.duels d
group by 1, 2, 3;

-- Ratings per mode in bands of 100 points, provisional apart (fewer than 10
-- rated duels): do players pile at the tier edges? (Every 150 points is a
-- tier of Basics and Advanced; 1300 and 1700 are Get the count's bands.)
create or replace view owner_dashboard.duel_rating_distribution as
select o.mode,
  (floor(o.rating / 100) * 100)::integer as band,
  count(*) filter (where o.rated_duels >= 10) as players,
  count(*) filter (where o.rated_duels < 10) as provisional,
  round(avg(o.deviation))::integer as mean_deviation
from public.duel_ratings o
group by 1, 2;

-- Runs with fair-play flags, newest first, and what became of them.
create or replace view owner_dashboard.flagged_runs as
select r.id as run_id,
  r.created_at,
  r.mode,
  r.player_id,
  public.public_display_name(r.player_id) as player,
  r.flags,
  coalesce(r.review, 'awaiting review') as review,
  r.score,
  r.serves
from public.duel_runs r
where cardinality(r.flags) > 0;

-- Who leaves duels unanswered (the escape quitting by closing the tab
-- leaves open).
create or replace view owner_dashboard.unanswered_duels as
select d.second_player as player_id,
  public.public_display_name(d.second_player) as player,
  count(*) as unanswered,
  max(d.created_at) as last
from public.duels d
where d.state = 'awaitingSecond' and d.kind in ('pool', 'practice')
  and d.created_at < now() - interval '1 hour'
group by 1;

-- Friends at a glance.
create or replace view owner_dashboard.friend_counts as
select
  (select count(*) from public.friend_codes) as players_with_code,
  (select count(*) from public.friendships) as friendships,
  (select count(distinct p) from (
    select player_a as p from public.friendships
    union all select player_b from public.friendships
  ) x) as players_with_friends,
  (select count(*) from public.friend_requests) as requests_pending,
  (select count(*) from public.friend_request_attempts
   where at > now() - interval '24 hours') as request_attempts_24h,
  (select count(*) from public.duels where kind = 'challenge') as challenges,
  (select count(*) from public.duels
   where kind = 'challenge' and state = 'awaitingSecond' and expires_at <= now())
    as challenges_expired;

-- The owner's verdict on a flagged run: 'ok' puts it back in the pool,
-- 'rejected' keeps it out for good. True if the run exists.
create or replace function owner_dashboard.review_run(p_run_id uuid, p_verdict text)
returns boolean
language plpgsql
set search_path = ''
as $$
begin
  if p_verdict not in ('ok', 'rejected') then
    raise exception 'verdict must be ok or rejected' using errcode = '22023';
  end if;
  update public.duel_runs set review = p_verdict where id = p_run_id;
  return found;
end;
$$;

revoke all on function owner_dashboard.review_run(uuid, text) from public, anon, authenticated;
