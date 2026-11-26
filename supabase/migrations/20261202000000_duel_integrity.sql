-- Phase 6a commit 1 (plan v3.9; review findings B5, M1, M2, M3, n1): duel
-- results hold.
--
-- - A duel reached through a chosen opponent (a challenge, a rematch) is
--   `chosen`: rated at most once per pair and mode over a rolling 24 hours,
--   whatever its kind. Before, only challenges were limited, by UTC day.
-- - The second player's run that does not replay is a loss, not a void
--   duel: the server records why (`record_duel_run_forfeit`) and applies a
--   forfeited run. `void` stays for a challenger's own first run.
-- - A challenge the friend opened is played or lost: its expiry no longer
--   applies once opened, so an abandonment is always scored. It can be
--   opened during 6 days and played for 24 hours from then — never opened
--   in the last 24 hours of its 7 days.
-- - Challenges only to a friend or an opponent of the last 30 days.
-- - `duel_context` says when the database read it (`now`: what a run's
--   claimed time is measured against) and whether the first run is flagged.
--
-- Every function keeps its signature: the server deployed before this
-- migration keeps working until the new one replaces it.

alter table public.duels add column if not exists chosen boolean not null default false;
update public.duels set chosen = true where kind = 'challenge' and not chosen;

-- How long a pair's chosen duels stay unrated after a rated one.
create or replace function public.duel_pair_rating_window() returns interval
language sql immutable set search_path = '' as $$ select interval '24 hours' $$;

-- How long a past duel lets two players challenge each other.
create or replace function public.duel_recent_opponent_window() returns interval
language sql immutable set search_path = '' as $$ select interval '30 days' $$;

-- Whether a chosen duel between d's two players was rated in d's mode
-- within the window (d itself left out).
create or replace function public.duel_pair_rated_recently(
  p_duel_id uuid,
  p_mode text,
  p_first uuid,
  p_second uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select from public.duels x
    where x.chosen and x.rated and x.mode = p_mode and x.id <> p_duel_id
      and least(x.first_player, x.second_player) = least(p_first, p_second)
      and greatest(x.first_player, x.second_player) = greatest(p_first, p_second)
      and x.finished_at > now() - public.duel_pair_rating_window()
  )
$$;

-- duel_take_run: as before; a run taken from a chosen opponent (a rematch)
-- makes a chosen duel.
create or replace function public.duel_take_run(
  p_player_id uuid,
  p_mode text,
  p_rating double precision,
  p_opponent uuid,
  p_difficulty integer,
  p_duel_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  picked public.duel_runs;
  owner public.duel_ratings;
begin
  select r.* into picked
  from public.duel_runs r
  join public.duel_ratings o on o.player_id = r.player_id and o.mode = r.mode
  join auth.users u on u.id = r.player_id
  where r.mode = p_mode
    and not u.is_anonymous
    and r.player_id <> p_player_id
    and (p_opponent is null or r.player_id = p_opponent)
    and r.serves < public.duel_max_serves()
    and ((cardinality(r.flags) = 0 and r.review is distinct from 'rejected')
      or r.review = 'ok')
    and r.id in (
      select x.id from (
        select l.id, row_number() over (
          partition by l.player_id order by l.created_at desc, l.id desc
        ) as n
        from public.duel_runs l where l.mode = p_mode
      ) x where x.n <= public.duel_pool_latest()
    )
    and not exists (
      select from public.duels d
      where d.config = r.config
        and (d.first_player = p_player_id or d.second_player = p_player_id)
    )
  order by
    case when p_opponent is null then abs(o.rating - p_rating)
      else abs((r.config ->> 'difficulty')::integer - coalesce(p_difficulty, 0)) end,
    r.created_at desc,
    r.id
  limit 1
  for update of r skip locked;
  if not found then
    return null;
  end if;

  update public.duel_runs set serves = serves + 1 where id = picked.id;
  insert into public.duels
    (id, mode, kind, config, first_player, second_player, first_run, first_lane, state, chosen)
  values
    (p_duel_id, p_mode, 'pool', picked.config, picked.player_id, p_player_id,
     picked.id, picked.lane, 'awaitingSecond', p_opponent is not null);
  select o.* into owner from public.duel_ratings o
  where o.player_id = picked.player_id and o.mode = p_mode;
  return jsonb_build_object(
    'duelId', p_duel_id,
    'kind', 'pool',
    'config', picked.config,
    'lane', picked.lane,
    'opponent', jsonb_build_object(
      'id', picked.player_id,
      'name', public.public_display_name(picked.player_id),
      'rating', owner.rating,
      'ratedDuels', owner.rated_duels
    )
  );
end;
$$;

-- A practice or challenge duel; a challenge is chosen.
create or replace function public.duel_insert(
  p_duel_id uuid,
  p_mode text,
  p_kind text,
  p_config jsonb,
  p_first_player uuid,
  p_second_player uuid,
  p_first_lane jsonb,
  p_expires_at timestamptz
)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.duels
    (id, mode, kind, config, first_player, second_player, first_lane, state, expires_at, chosen)
  values
    (p_duel_id, p_mode, p_kind, p_config, p_first_player, p_second_player, p_first_lane,
     case when p_kind = 'challenge' then 'awaitingFirst' else 'awaitingSecond' end,
     p_expires_at, p_kind = 'challenge')
$$;

-- duel_context, with: `chosen`; `now` (the database's clock, which also set
-- `createdAt` and `openedAt`); `firstFlags` (the first run's flags unless
-- the owner reviewed it ok); `pairRatedToday` for every chosen duel, over a
-- rolling 24 hours (the key keeps its name for the server deployed before).
create or replace function public.duel_context(p_duel_id uuid, p_player_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'duel', jsonb_build_object(
      'id', d.id,
      'mode', d.mode,
      'kind', d.kind,
      'chosen', d.chosen,
      'config', d.config,
      'firstPlayer', d.first_player,
      'secondPlayer', d.second_player,
      'firstLane', d.first_lane,
      'state', d.state,
      'result', d.result,
      'rated', d.rated,
      'firstRatingBefore', d.first_rating_before,
      'firstRatingAfter', d.first_rating_after,
      'secondRatingBefore', d.second_rating_before,
      'secondRatingAfter', d.second_rating_after,
      'expiresAt', d.expires_at,
      'openedAt', d.opened_at,
      'createdAt', d.created_at,
      'progress', d.progress,
      'opponentName', public.public_display_name(
        case when d.first_player = p_player_id then d.second_player else d.first_player end
      )
    ),
    'now', now(),
    'run', (
      select jsonb_build_object('lane', r.lane, 'score', r.score, 'flags', to_jsonb(r.flags))
      from public.duel_runs r where r.duel_id = d.id and r.player_id = p_player_id
    ),
    'rejection', (
      select jsonb_build_object('reason', x.reason)
      from public.duel_run_rejections x
      where x.duel_id = d.id and x.player_id = p_player_id
    ),
    'firstFlags', coalesce((
      select to_jsonb(r.flags) from public.duel_runs r
      where r.id = d.first_run and r.review is distinct from 'ok'
    ), '[]'::jsonb),
    'ratings', coalesce((
      select jsonb_object_agg(o.player_id, jsonb_build_object(
        'rating', o.rating,
        'deviation', o.deviation,
        'volatility', o.volatility,
        'ratedDuels', o.rated_duels,
        'version', o.version
      ))
      from public.duel_ratings o
      where o.mode = d.mode and o.player_id in (d.first_player, d.second_player)
    ), '{}'::jsonb),
    'levels', coalesce((
      select jsonb_object_agg(l.exercise_type, l.level)
      from public.server_levels l where l.player_id = p_player_id
    ), '{}'::jsonb),
    'pairRatedToday', d.chosen and public.duel_pair_rated_recently(
      d.id, d.mode, d.first_player, d.second_player)
  )
  from public.duels d
  where d.id = p_duel_id
$$;

-- apply_duel_run, with: the expiry only before a challenge is opened (an
-- opened challenge is played or lost); the once-per-24-hours rule for every
-- chosen duel.
create or replace function public.apply_duel_run(
  p_duel_id uuid,
  p_player_id uuid,
  p_payload jsonb,
  p_lane jsonb,
  p_score jsonb,
  p_flags text[],
  p_start_rating jsonb,
  p_result double precision,
  p_rated boolean,
  p_ratings jsonb
)
returns table (outcome text, run_id uuid)
language plpgsql
security definer
set search_path = ''
as $$
declare
  d public.duels;
  turn text;
  new_run uuid;
  existing uuid;
  entry record;
  held public.duel_ratings;
  first_before double precision;
  first_after double precision;
  second_before double precision;
  second_after double precision;
begin
  select r.id into existing from public.duel_runs r
  where r.duel_id = p_duel_id and r.player_id = p_player_id;
  if found then
    return query select 'duplicate'::text, existing;
    return;
  end if;

  select * into d from public.duels where id = p_duel_id for update;
  if not found then
    return query select 'notOpen'::text, null::uuid;
    return;
  end if;
  if d.state = 'awaitingFirst' and d.first_player = p_player_id then
    turn := 'first';
  elsif d.state = 'awaitingSecond' and d.second_player = p_player_id then
    turn := 'second';
  else
    return query select 'notOpen'::text, null::uuid;
    return;
  end if;
  if d.expires_at is not null and now() > d.expires_at + interval '1 hour'
     and not (turn = 'second' and d.opened_at is not null) then
    return query select 'expired'::text, null::uuid;
    return;
  end if;

  insert into public.duel_ratings (player_id, mode, rating, deviation, volatility)
  values (p_player_id, d.mode, (p_start_rating ->> 'rating')::double precision,
    (p_start_rating ->> 'deviation')::double precision,
    (p_start_rating ->> 'volatility')::double precision)
  on conflict (player_id, mode) do nothing;

  if turn = 'second' and p_rated then
    if d.chosen and public.duel_pair_rated_recently(
      d.id, d.mode, d.first_player, d.second_player) then
      return query select 'stale'::text, null::uuid;
      return;
    end if;
    for entry in select key::uuid as player, value from jsonb_each(p_ratings) order by key loop
      select o.* into held from public.duel_ratings o
      where o.player_id = entry.player and o.mode = d.mode
      for update;
      if not found or held.version <> (entry.value ->> 'expectedVersion')::integer then
        return query select 'stale'::text, null::uuid;
        return;
      end if;
      update public.duel_ratings o set
        rating = (entry.value ->> 'rating')::double precision,
        deviation = (entry.value ->> 'deviation')::double precision,
        volatility = (entry.value ->> 'volatility')::double precision,
        rated_duels = o.rated_duels + 1,
        last_rated_at = now(),
        version = o.version + 1
      where o.player_id = entry.player and o.mode = d.mode;
      if entry.player = d.first_player then
        first_before := held.rating;
        first_after := (entry.value ->> 'rating')::double precision;
      elsif entry.player = d.second_player then
        second_before := held.rating;
        second_after := (entry.value ->> 'rating')::double precision;
      end if;
    end loop;
  end if;

  insert into public.duel_runs (duel_id, player_id, mode, config, payload, lane, score, flags)
  values (p_duel_id, p_player_id, d.mode, d.config, p_payload, p_lane, p_score, p_flags)
  returning id into new_run;

  if turn = 'first' then
    update public.duels set first_run = new_run, first_lane = p_lane, state = 'awaitingSecond'
    where id = p_duel_id;
  else
    update public.duels set
      second_run = new_run,
      state = 'done',
      result = p_result,
      rated = coalesce(p_rated, false),
      first_rating_before = first_before,
      first_rating_after = first_after,
      second_rating_before = second_before,
      second_rating_after = second_after,
      finished_at = now()
    where id = p_duel_id;
  end if;
  return query select 'applied'::text, new_run;
end;
$$;

-- Why the second player's run was not taken as sent, once per (duel,
-- player). The duel is not void: the server applies a forfeited run (a
-- loss) right after. The payload is what the server chose to keep of it.
create or replace function public.record_duel_run_forfeit(
  p_duel_id uuid,
  p_player_id uuid,
  p_reason text,
  p_detail text,
  p_payload jsonb
)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.duel_run_rejections (duel_id, player_id, reason, detail, payload)
  select p_duel_id, p_player_id, p_reason, p_detail, p_payload
  where exists (
    select from public.duels d
    where d.id = p_duel_id and d.second_player = p_player_id
  )
  on conflict (duel_id, player_id) do nothing
$$;

-- A challenge from p_challenger to p_target (the challenger plays first).
-- The friend can open it for 6 days and then has 24 hours to play it: 7
-- days in all, never opened in the last 24 hours. New: 'notAllowed' unless
-- the two are friends or finished a duel against each other in the last 30
-- days — a rated duel is not aimed at a stranger.
create or replace function public.duel_create_challenge(
  p_duel_id uuid,
  p_mode text,
  p_config jsonb,
  p_challenger uuid,
  p_target uuid
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_challenger = p_target then
    return 'self';
  end if;
  if not exists (select from auth.users u where u.id = p_target and not u.is_anonymous) then
    return 'notLinked';
  end if;
  if not exists (
    select from public.friendships f
    where f.player_a = least(p_challenger, p_target)
      and f.player_b = greatest(p_challenger, p_target)
  ) and not exists (
    select from public.duels d
    where d.state = 'done'
      and d.finished_at > now() - public.duel_recent_opponent_window()
      and least(d.first_player, d.second_player) = least(p_challenger, p_target)
      and greatest(d.first_player, d.second_player) = greatest(p_challenger, p_target)
  ) then
    return 'notAllowed';
  end if;
  -- Serialise challenges between the same two players.
  perform pg_advisory_xact_lock(hashtext(least(p_challenger, p_target)::text
    || greatest(p_challenger, p_target)::text || p_mode));
  if exists (
    select from public.duels d
    where d.kind = 'challenge' and d.mode = p_mode
      and d.state in ('awaitingFirst', 'awaitingSecond')
      and (d.opened_at is not null or d.expires_at is null or d.expires_at > now())
      and least(d.first_player, d.second_player) = least(p_challenger, p_target)
      and greatest(d.first_player, d.second_player) = greatest(p_challenger, p_target)
  ) then
    return 'exists';
  end if;
  perform public.duel_insert(p_duel_id, p_mode, 'challenge', p_config, p_challenger,
    p_target, null, now() + interval '7 days' - public.duel_abandon_after());
  return 'created';
end;
$$;

-- The flagged runs the owner reviews: neither an abandoned run nor a
-- forfeited one (both are losses already, never in the pool).
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
where cardinality(array_remove(array_remove(r.flags, 'abandoned'), 'forfeited')) > 0;

-- Who sent runs that did not replay (recorded as losses), and why: evidence
-- for the owner's moderation.
create or replace view owner_dashboard.forfeited_duels as
select x.player_id,
  public.public_display_name(x.player_id) as player,
  x.reason,
  count(*) as forfeits,
  max(x.received_at) as last
from public.duel_run_rejections x
join public.duel_runs r on r.duel_id = x.duel_id and r.player_id = x.player_id
where 'forfeited' = any(r.flags)
group by 1, 3;

revoke all on function public.duel_pair_rated_recently(uuid, text, uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.record_duel_run_forfeit(uuid, uuid, text, text, jsonb)
  from public, anon, authenticated;
grant execute on function public.duel_pair_rated_recently(uuid, text, uuid, uuid)
  to service_role;
grant execute on function public.record_duel_run_forfeit(uuid, uuid, text, text, jsonb)
  to service_role;
