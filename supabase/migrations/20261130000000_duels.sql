-- Phase 7 commit 2 (plan v3.7): asynchronous duels. A duel races a
-- recorded run (or a simulated one); every run is replayed by the Dart
-- server with math_core before it is stored here. Players never read or
-- write these tables through the API: the server does, as the service role,
-- through the functions below (all `security definer`: they also read
-- `auth.users`). Reads for the app come with commit 6.

-- One rating per player and mode (Glicko-2, computed by the server only).
-- Created at the player's first accepted run of the mode, at the starting
-- rating from their levels; `version` is bumped by every rated duel — two
-- results computed from the same ratings cannot both apply.
create table if not exists public.duel_ratings (
  player_id uuid not null references auth.users (id) on delete cascade,
  mode text not null check (mode in ('basics', 'advanced', 'count')),
  rating double precision not null,
  deviation double precision not null check (deviation > 0),
  volatility double precision not null check (volatility > 0),
  rated_duels integer not null default 0 check (rated_duels >= 0),
  last_rated_at timestamptz,
  version integer not null default 0,
  primary key (player_id, mode)
);

-- A duel: the second player races the first player's run (pool, challenge)
-- or a simulated one (practice: no first player). `first_lane` is what the
-- second player sees of the first run (never the values typed). States:
-- awaitingFirst (a challenge before its challenger's run), awaitingSecond,
-- done, void (a run was refused: the duel does not count).
create table if not exists public.duels (
  id uuid primary key,
  mode text not null check (mode in ('basics', 'advanced', 'count')),
  kind text not null check (kind in ('pool', 'practice', 'challenge')),
  config jsonb not null,
  first_player uuid references auth.users (id) on delete cascade,
  second_player uuid not null references auth.users (id) on delete cascade,
  first_run uuid,
  second_run uuid,
  first_lane jsonb,
  state text not null check (state in ('awaitingFirst', 'awaitingSecond', 'done', 'void')),
  -- The second player's Glicko-2 score: 1 a win, 0.5 a draw, 0 a loss.
  result double precision check (result in (0, 0.5, 1)),
  rated boolean not null default false,
  first_rating_before double precision,
  first_rating_after double precision,
  second_rating_before double precision,
  second_rating_after double precision,
  created_at timestamptz not null default now(),
  expires_at timestamptz,
  finished_at timestamptz,
  check ((kind = 'practice') = (first_player is null))
);

create index if not exists duels_second_player on public.duels (second_player, created_at desc);
create index if not exists duels_first_player on public.duels (first_player, created_at desc);

-- A validated run. `lane` is what an opponent sees, `score` its result
-- ({points, ms}); flagged runs stay out of the pool until the owner
-- reviews them (`review`). `serves`: how many duels it was handed to.
create table if not exists public.duel_runs (
  id uuid primary key default gen_random_uuid(),
  duel_id uuid not null references public.duels (id) on delete cascade,
  player_id uuid not null references auth.users (id) on delete cascade,
  mode text not null check (mode in ('basics', 'advanced', 'count')),
  config jsonb not null,
  payload jsonb not null,
  lane jsonb not null,
  score jsonb not null,
  flags text[] not null default '{}',
  review text check (review in ('ok', 'rejected')),
  serves integer not null default 0 check (serves >= 0),
  created_at timestamptz not null default now(),
  unique (duel_id, player_id)
);

create index if not exists duel_runs_pool on public.duel_runs (mode, player_id, created_at desc);

-- Refused runs, once per (duel, player): a resend gets the same answer.
create table if not exists public.duel_run_rejections (
  duel_id uuid not null references public.duels (id) on delete cascade,
  player_id uuid not null references auth.users (id) on delete cascade,
  reason text not null,
  detail text,
  payload jsonb not null,
  received_at timestamptz not null default now(),
  primary key (duel_id, player_id)
);

alter table public.duel_ratings enable row level security;
alter table public.duels enable row level security;
alter table public.duel_runs enable row level security;
alter table public.duel_run_rejections enable row level security;
revoke all on table public.duel_ratings, public.duels, public.duel_runs,
  public.duel_run_rejections from anon, authenticated;
grant select, insert, update on table public.duel_ratings, public.duels,
  public.duel_runs, public.duel_run_rejections to service_role;

-- How many times a run is handed out, and how many of a player's latest
-- runs per mode are in the pool (plan v3.7).
create or replace function public.duel_max_serves() returns integer
language sql immutable as $$ select 5 $$;
create or replace function public.duel_pool_latest() returns integer
language sql immutable as $$ select 10 $$;

-- Matchmaking's pool (commit 4 calls it): the run to race for p_player_id
-- in p_mode, or null. Candidates: accepted runs, unflagged or reviewed ok,
-- served fewer than 5 times, among their owner's 10 latest of the mode, of
-- a linked player other than the caller, on a config the caller never
-- played. Ordered by the owner's rating's distance to p_rating — for a
-- rematch (p_opponent), that opponent's runs only, by the distance of their
-- tier to p_difficulty — then newest. The run is locked (two callers never
-- share its last serve), served once more, and the duel created.
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
    (id, mode, kind, config, first_player, second_player, first_run, first_lane, state)
  values
    (p_duel_id, p_mode, 'pool', picked.config, picked.player_id, p_player_id,
     picked.id, picked.lane, 'awaitingSecond');
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

-- A practice or challenge duel (the server built its config and, for
-- practice, its simulated lane).
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
    (id, mode, kind, config, first_player, second_player, first_lane, state, expires_at)
  values
    (p_duel_id, p_mode, p_kind, p_config, p_first_player, p_second_player, p_first_lane,
     case when p_kind = 'challenge' then 'awaitingFirst' else 'awaitingSecond' end,
     p_expires_at)
$$;

-- Everything the server needs to decide a run of p_player_id in p_duel_id:
-- the duel, this player's run or refusal if already decided (a resend gets
-- the same answer), both players' ratings, this player's levels (a missing
-- rating starts from them), and whether a challenge between the two was
-- already rated today in this mode (once a day per pair). Null: no such
-- duel.
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
      'opponentName', public.public_display_name(
        case when d.first_player = p_player_id then d.second_player else d.first_player end
      )
    ),
    'run', (
      select jsonb_build_object('lane', r.lane, 'score', r.score, 'flags', to_jsonb(r.flags))
      from public.duel_runs r where r.duel_id = d.id and r.player_id = p_player_id
    ),
    'rejection', (
      select jsonb_build_object('reason', x.reason)
      from public.duel_run_rejections x
      where x.duel_id = d.id and x.player_id = p_player_id
    ),
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
    'pairRatedToday', d.kind = 'challenge' and exists (
      select from public.duels x
      where x.kind = 'challenge' and x.rated and x.mode = d.mode and x.id <> d.id
        and least(x.first_player, x.second_player) = least(d.first_player, d.second_player)
        and greatest(x.first_player, x.second_player) = greatest(d.first_player, d.second_player)
        and (x.finished_at at time zone 'utc')::date = (now() at time zone 'utc')::date
    )
  )
  from public.duels d
  where d.id = p_duel_id
$$;

-- Applies one validated run, all or nothing. Creates the submitter's rating
-- at p_start_rating ({rating, deviation, volatility}) if they have none.
-- The first player's run (a challenge) opens the duel to the second; the
-- second player's run decides it: p_result (their score), p_rated, and when
-- rated p_ratings = {player id: {rating, deviation, volatility,
-- expectedVersion}} for both players. Outcomes: 'applied'; 'duplicate'
-- (this player's run is stored); 'notOpen' (not this player's turn);
-- 'expired' (a challenge past its 7 days, an hour's grace for a game under
-- way); 'stale' (a rating moved, or a challenge between the pair was rated
-- today since the server read the context: read and compute again).
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
  if d.expires_at is not null and now() > d.expires_at + interval '1 hour' then
    return query select 'expired'::text, null::uuid;
    return;
  end if;

  insert into public.duel_ratings (player_id, mode, rating, deviation, volatility)
  values (p_player_id, d.mode, (p_start_rating ->> 'rating')::double precision,
    (p_start_rating ->> 'deviation')::double precision,
    (p_start_rating ->> 'volatility')::double precision)
  on conflict (player_id, mode) do nothing;

  if turn = 'second' and p_rated then
    if d.kind = 'challenge' and exists (
      select from public.duels x
      where x.kind = 'challenge' and x.rated and x.mode = d.mode and x.id <> d.id
        and least(x.first_player, x.second_player) = least(d.first_player, d.second_player)
        and greatest(x.first_player, x.second_player) = greatest(d.first_player, d.second_player)
        and (x.finished_at at time zone 'utc')::date = (now() at time zone 'utc')::date
    ) then
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

-- Records a refused run once and voids its duel (plan v3.7: a run that
-- fails never enters the pool and its duel does not count).
create or replace function public.record_duel_run_refused(
  p_duel_id uuid,
  p_player_id uuid,
  p_reason text,
  p_detail text,
  p_payload jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.duel_run_rejections (duel_id, player_id, reason, detail, payload)
  values (p_duel_id, p_player_id, p_reason, p_detail, p_payload)
  on conflict (duel_id, player_id) do nothing;
  update public.duels set state = 'void', finished_at = now()
  where id = p_duel_id and state in ('awaitingFirst', 'awaitingSecond')
    and p_player_id in (first_player, second_player);
end;
$$;

revoke all on function public.duel_take_run(uuid, text, double precision, uuid, integer, uuid)
  from public, anon, authenticated;
revoke all on function public.duel_insert(uuid, text, text, jsonb, uuid, uuid, jsonb, timestamptz)
  from public, anon, authenticated;
revoke all on function public.duel_context(uuid, uuid) from public, anon, authenticated;
revoke all on function public.apply_duel_run(uuid, uuid, jsonb, jsonb, jsonb, text[], jsonb,
  double precision, boolean, jsonb) from public, anon, authenticated;
revoke all on function public.record_duel_run_refused(uuid, uuid, text, text, jsonb)
  from public, anon, authenticated;
grant execute on function public.duel_take_run(uuid, text, double precision, uuid, integer, uuid)
  to service_role;
grant execute on function public.duel_insert(uuid, text, text, jsonb, uuid, uuid, jsonb, timestamptz)
  to service_role;
grant execute on function public.duel_context(uuid, uuid) to service_role;
grant execute on function public.apply_duel_run(uuid, uuid, jsonb, jsonb, jsonb, text[], jsonb,
  double precision, boolean, jsonb) to service_role;
grant execute on function public.record_duel_run_refused(uuid, uuid, text, text, jsonb)
  to service_role;
