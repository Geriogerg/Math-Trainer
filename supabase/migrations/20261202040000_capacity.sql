-- Phase 6a commit 5 (plan v3.9; review findings M7, M8, M9): capacity.
--
-- - Each player's completed Levelling games are counted as they are
--   accepted (`server_players.completed_games`): the main board no longer
--   counts every active player's sessions on every call.
-- - Every board (levels and duels) is computed at most once a minute into
--   `board_rows`, and each call reads it: `leaderboard_around_me` computed
--   the whole board three times per call.
-- - The duel pool is maintained as runs change (`duel_runs.in_pool`, by
--   trigger), configs are compared by hash, and matchmaking looks for the
--   closest rating in widening windows instead of sorting every run.
-- - The weak-spot check reads a player's latest 200 sessions, not all.
-- - `owner_dashboard.database_usage`: the database against the free plan's
--   500 MB; the owner's report raises an alert from 50 %.
--
-- Every function the server calls keeps its signature. The board functions
-- become VOLATILE (they refresh the cache): the app calls them with POST,
-- as supabase-js and supabase_flutter do by default.

-- 1. Completed Levelling games per player.
alter table public.server_players
  add column if not exists completed_games integer not null default 0;
update public.server_players p set completed_games = c.n
from (
  select s.player_id, count(*)::integer as n
  from public.uploaded_sessions s
  where s.completed and s.kind = 'game' and s.rules_version >= 2
  group by s.player_id
) c
where c.player_id = p.player_id and p.completed_games is distinct from c.n;

-- apply_validated_session, also counting completed Levelling games.
create or replace function public.apply_validated_session(
  p_session_id uuid,
  p_player_id uuid,
  p_expected_version integer,
  p_created_at timestamptz,
  p_kind text,
  p_completed boolean,
  p_payload jsonb,
  p_level_updates jsonb,
  p_flags text[]
)
returns table (outcome text, received_at timestamptz)
language plpgsql
set search_path = ''
as $$
declare
  current_version integer;
  existing_player uuid;
  stored_at timestamptz;
begin
  select s.player_id, s.received_at into existing_player, stored_at
  from public.uploaded_sessions s where s.id = p_session_id;
  if found then
    return query select
      case when existing_player = p_player_id then 'duplicate' else 'conflict' end,
      stored_at;
    return;
  end if;
  insert into public.server_players (player_id) values (p_player_id)
  on conflict (player_id) do nothing;
  select p.version into current_version
  from public.server_players p where p.player_id = p_player_id
  for update;
  if current_version <> p_expected_version then
    return query select 'stale'::text, null::timestamptz;
    return;
  end if;
  insert into public.uploaded_sessions
    (id, player_id, created_at, kind, payload, completed)
  values (p_session_id, p_player_id, p_created_at, p_kind, p_payload, p_completed)
  returning uploaded_sessions.received_at into stored_at;
  insert into public.server_levels
    (player_id, exercise_type, level, sessions_played, updated_at)
  select p_player_id, u.key, (u.value ->> 'level')::integer,
    (u.value ->> 'sessionsPlayed')::integer,
    (u.value ->> 'updatedAt')::timestamptz
  from jsonb_each(p_level_updates) u
  on conflict (player_id, exercise_type) do update set
    level = excluded.level,
    sessions_played = excluded.sessions_played,
    updated_at = excluded.updated_at;
  insert into public.upload_flags (session_id, flag)
  select p_session_id, f from unnest(p_flags) f
  on conflict do nothing;
  update public.server_players p set
    version = p.version + 1,
    last_session_at = greatest(p.last_session_at, p_created_at),
    last_session_ends_at = greatest(p.last_session_ends_at,
      p_created_at + public.upload_played_ms(p_payload) * interval '1 millisecond'),
    has_completed_session = p.has_completed_session or p_completed,
    completed_games = p.completed_games + case
      when p_completed and p_kind = 'game'
        and coalesce((p_payload -> 'session' ->> 'rulesVersion')::integer, 1) >= 2
      then 1 else 0 end
  where p.player_id = p_player_id;
  return query select 'applied'::text, stored_at;
end;
$$;

-- leaderboard_rows: the main board from the count above.
create or replace function public.leaderboard_rows(p_board text)
returns table (player_id uuid, level integer, rank bigint, total bigint)
language sql
stable
security definer
set search_path = ''
as $$
  with active as (
    select p.player_id, p.completed_games
    from public.server_players p
    join auth.users u on u.id = p.player_id
    where p.last_session_at >= now() - interval '30 days'
      and not u.is_anonymous
      and p.player_id <> all (array(select m.player_id from public.player_moderation m))
  ),
  board as (
    select l.player_id, l.level
    from public.server_levels l
    join active a on a.player_id = l.player_id
    where p_board <> 'overall'
      and l.exercise_type = p_board
      and l.sessions_played >= public.leaderboard_min_sessions()
    union all
    select a.player_id,
      round(coalesce(sum(l.level), 0) / 4.0)::integer
    from active a
    left join public.server_levels l
      on l.player_id = a.player_id
      and l.exercise_type in ('addition', 'subtraction', 'multiplication', 'division')
    where p_board = 'overall'
      and a.completed_games >= public.leaderboard_min_sessions()
    group by a.player_id
  )
  select b.player_id, b.level,
    rank() over (order by b.level desc),
    count(*) over ()
  from board b
$$;

-- duel_board_rows likewise (the hidden players once, as an array).
create or replace function public.duel_board_rows(p_mode text)
returns table (player_id uuid, rating integer, rank bigint, total bigint)
language sql
stable
security definer
set search_path = ''
as $$
  select o.player_id, round(o.rating)::integer,
    rank() over (order by round(o.rating) desc),
    count(*) over ()
  from public.duel_ratings o
  join auth.users u on u.id = o.player_id
  where o.mode = p_mode
    and not u.is_anonymous
    and o.rated_duels >= public.duel_board_min_duels()
    and o.last_rated_at >= now() - interval '30 days'
    and o.player_id <> all (array(select m.player_id from public.player_moderation m))
$$;

-- 2. The boards, computed at most once a minute.
create table if not exists public.board_snapshots (
  board text primary key,
  computed_at timestamptz not null,
  total integer not null
);
-- Unlogged and without a foreign key: a cache, rebuilt from the real tables
-- every minute (a crash empties it; the next call refills it). Writing 10,000
-- rows took 250 ms with the key and WAL, 60–90 ms without — the difference
-- between the main board's refreshing call staying under 300 ms or not. A
-- deleted player's rows are removed by `delete_my_account` itself.
create unlogged table if not exists public.board_rows (
  board text not null,
  position integer not null,
  player_id uuid not null,
  value integer not null,
  rank bigint not null,
  primary key (board, position)
);
create index if not exists board_rows_player on public.board_rows (board, player_id);
alter table public.board_snapshots enable row level security;
alter table public.board_rows enable row level security;
revoke all on table public.board_snapshots, public.board_rows from anon, authenticated;
grant select, insert, update, delete on table public.board_snapshots, public.board_rows
  to service_role;

-- How long a computed board is served: a minute, unless the database sets
-- `mt.board_cache_seconds` (the SQL tests' database sets 0, so each step
-- reads its own data; production never sets it).
create or replace function public.board_cache_age() returns interval
language sql stable set search_path = '' as $$
  select make_interval(secs => coalesce(
    nullif(current_setting('mt.board_cache_seconds', true), '')::integer, 60))
$$;

-- Recomputes p_board ('overall', an exercise type, or 'duel:<mode>') if
-- its snapshot is older than a minute. One caller computes; the others
-- serve the previous minute's meanwhile (or wait, the very first time).
create or replace function public.board_refresh(p_board text)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  fresh boolean;
  total integer;
begin
  select s.computed_at > clock_timestamp() - public.board_cache_age() into fresh
  from public.board_snapshots s where s.board = p_board;
  if fresh then
    return;
  end if;
  if fresh is null then
    perform pg_advisory_xact_lock(hashtext('board:' || p_board));
  elsif not pg_try_advisory_xact_lock(hashtext('board:' || p_board)) then
    return;
  end if;
  select s.computed_at > clock_timestamp() - public.board_cache_age() into fresh
  from public.board_snapshots s where s.board = p_board;
  if fresh then
    return;
  end if;
  delete from public.board_rows b where b.board = p_board;
  if p_board like 'duel:%' then
    insert into public.board_rows (board, position, player_id, value, rank)
    select p_board, row_number() over (order by r.rank, r.player_id), r.player_id, r.rating, r.rank
    from public.duel_board_rows(substr(p_board, 6)) r;
  else
    insert into public.board_rows (board, position, player_id, value, rank)
    select p_board, row_number() over (order by r.rank, r.player_id), r.player_id, r.level, r.rank
    from public.leaderboard_rows(p_board) r;
  end if;
  get diagnostics total = row_count;
  insert into public.board_snapshots (board, computed_at, total)
  values (p_board, clock_timestamp(), total)
  on conflict (board) do update set computed_at = excluded.computed_at, total = excluded.total;
end;
$$;

create or replace function public.leaderboard_top(p_board text)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
  perform public.leaderboard_check_board(p_board);
  perform public.board_refresh(p_board);
  return coalesce((
    select jsonb_agg(public.leaderboard_entry(b.player_id, b.rank, b.value)
      order by b.position)
    from public.board_rows b
    where b.board = p_board and b.position <= 100
  ), '[]'::jsonb);
end;
$$;

create or replace function public.leaderboard_around_me(p_board text)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
  mine public.board_rows;
  board_total integer;
  last_at timestamptz;
  counted integer;
begin
  perform public.leaderboard_check_board(p_board);
  if me is null then
    return jsonb_build_object('eligible', false, 'reason', 'signedOut');
  end if;
  if exists (select from auth.users u where u.id = me and u.is_anonymous) then
    return jsonb_build_object('eligible', false, 'reason', 'notLinked');
  end if;
  perform public.board_refresh(p_board);
  select b.* into mine from public.board_rows b
  where b.board = p_board and b.player_id = me;
  if not found then
    select p.last_session_at, p.completed_games into last_at, counted
    from public.server_players p where p.player_id = me;
    if p_board <> 'overall' then
      select coalesce(max(l.sessions_played), 0) into counted
      from public.server_levels l
      where l.player_id = me and l.exercise_type = p_board;
    end if;
    counted := coalesce(counted, 0);
    return jsonb_build_object(
      'eligible', false,
      'reason', case
        when last_at is null then 'noSessions'
        when counted < public.leaderboard_min_sessions() then 'notEnoughSessions'
        else 'inactive'
      end,
      'sessionsNeeded', greatest(public.leaderboard_min_sessions() - counted, 0)
    );
  end if;
  select s.total into board_total from public.board_snapshots s where s.board = p_board;
  return jsonb_build_object(
    'eligible', true,
    'rank', mine.rank,
    'total', board_total,
    'topPercent', ceil(100.0 * mine.rank / board_total)::integer,
    'level', mine.value,
    'neighbours', (
      select jsonb_agg(public.leaderboard_entry(n.player_id, n.rank, n.value)
        order by n.position)
      from public.board_rows n
      where n.board = p_board
        and n.position between mine.position - 5 and mine.position + 5
    )
  );
end;
$$;

create or replace function public.duel_board_top(p_mode text)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
  perform public.duel_check_mode(p_mode);
  perform public.board_refresh('duel:' || p_mode);
  return coalesce((
    select jsonb_agg(public.duel_board_entry(b.player_id, b.rank, b.value)
      order by b.position)
    from public.board_rows b
    where b.board = 'duel:' || p_mode and b.position <= 100
  ), '[]'::jsonb);
end;
$$;

create or replace function public.duel_board_around_me(p_mode text)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
  mine public.board_rows;
  board_total integer;
  held public.duel_ratings;
begin
  perform public.duel_check_mode(p_mode);
  if me is null then
    return jsonb_build_object('eligible', false, 'reason', 'signedOut');
  end if;
  if exists (select from auth.users u where u.id = me and u.is_anonymous) then
    return jsonb_build_object('eligible', false, 'reason', 'notLinked');
  end if;
  perform public.board_refresh('duel:' || p_mode);
  select b.* into mine from public.board_rows b
  where b.board = 'duel:' || p_mode and b.player_id = me;
  if not found then
    select o.* into held from public.duel_ratings o
    where o.player_id = me and o.mode = p_mode;
    return jsonb_build_object(
      'eligible', false,
      'reason', case
        when held.player_id is null or held.rated_duels = 0 then 'noDuels'
        when held.rated_duels < public.duel_board_min_duels() then 'provisional'
        else 'inactive'
      end,
      'sessionsNeeded', greatest(
        public.duel_board_min_duels() - coalesce(held.rated_duels, 0), 0)
    );
  end if;
  select s.total into board_total from public.board_snapshots s
  where s.board = 'duel:' || p_mode;
  return jsonb_build_object(
    'eligible', true,
    'rank', mine.rank,
    'total', board_total,
    'topPercent', ceil(100.0 * mine.rank / board_total)::integer,
    'rating', mine.value,
    'neighbours', (
      select jsonb_agg(public.duel_board_entry(n.player_id, n.rank, n.value)
        order by n.position)
      from public.board_rows n
      where n.board = 'duel:' || p_mode
        and n.position between mine.position - 5 and mine.position + 5
    )
  );
end;
$$;

-- 3. The duel pool, maintained. A run is in the pool while it is served
-- fewer than 5 times, unflagged (or reviewed ok) and among its owner's 10
-- latest of the mode; whether its owner is linked and visible is checked
-- when it is picked.
alter table public.duel_runs add column if not exists in_pool boolean not null default false;
alter table public.duel_runs add column if not exists config_hash text
  generated always as (md5(config::text)) stored;
alter table public.duels add column if not exists config_hash text
  generated always as (md5(config::text)) stored;
create index if not exists duel_runs_in_pool
  on public.duel_runs (mode, player_id, created_at desc) where in_pool;
create index if not exists duels_first_config on public.duels (first_player, config_hash);
create index if not exists duels_second_config on public.duels (second_player, config_hash);
create index if not exists duel_ratings_mode_rating on public.duel_ratings (mode, rating);

create or replace function public.duel_run_poolable(p_serves integer, p_flags text[], p_review text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select p_serves < public.duel_max_serves()
    and ((cardinality(p_flags) = 0 and p_review is distinct from 'rejected')
      or p_review is not distinct from 'ok')
$$;

create or replace function public.duel_runs_pool_flag()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.in_pool := public.duel_run_poolable(new.serves, new.flags, new.review)
    and (tg_op = 'INSERT' or (
      select count(*) from public.duel_runs l
      where l.player_id = new.player_id and l.mode = new.mode
        and (l.created_at, l.id) > (new.created_at, new.id)
    ) < public.duel_pool_latest());
  return new;
end;
$$;

-- A new run pushes its owner's 11th latest of the mode out of the pool.
create or replace function public.duel_runs_pool_trim()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  update public.duel_runs r set in_pool = false
  where r.player_id = new.player_id and r.mode = new.mode and r.in_pool
    and r.id not in (
      select l.id from public.duel_runs l
      where l.player_id = new.player_id and l.mode = new.mode
      order by l.created_at desc, l.id desc
      limit public.duel_pool_latest()
    );
  return null;
end;
$$;

drop trigger if exists duel_runs_pool_flag on public.duel_runs;
create trigger duel_runs_pool_flag
  before insert or update of serves, flags, review on public.duel_runs
  for each row execute function public.duel_runs_pool_flag();
drop trigger if exists duel_runs_pool_trim on public.duel_runs;
create trigger duel_runs_pool_trim
  after insert on public.duel_runs
  for each row execute function public.duel_runs_pool_trim();

update public.duel_runs r set in_pool = x.poolable
from (
  select l.id,
    public.duel_run_poolable(l.serves, l.flags, l.review)
      and row_number() over (partition by l.player_id, l.mode
        order by l.created_at desc, l.id desc) <= public.duel_pool_latest() as poolable
  from public.duel_runs l
) x
where x.id = r.id and r.in_pool is distinct from x.poolable;

-- duel_take_run: the closest rating within 50, then 150, then 400 points,
-- then anyone; the caller's played configs by hash.
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
  window_points double precision;
begin
  if not public.player_visible(p_player_id) then
    return null;
  end if;
  foreach window_points in array array[50, 150, 400, 'Infinity']::double precision[] loop
    select r.* into picked
    from public.duel_ratings o
    join public.duel_runs r on r.player_id = o.player_id and r.mode = o.mode and r.in_pool
    join auth.users u on u.id = r.player_id
    where o.mode = p_mode
      and (case when p_opponent is null
        then o.rating between p_rating - window_points and p_rating + window_points
        else o.player_id = p_opponent end)
      and not u.is_anonymous
      and r.player_id <> p_player_id
      -- The hidden players once, as an array: player_visible() per run cost
      -- 50 ms at 10,000 players, an anti-join the planner loops 145 ms.
      and o.player_id <> all (array(select m.player_id from public.player_moderation m))
      and r.config_hash not in (
        select d.config_hash from public.duels d where d.first_player = p_player_id
        union all
        select d.config_hash from public.duels d where d.second_player = p_player_id
      )
    order by
      case when p_opponent is null then abs(o.rating - p_rating)
        else abs((r.config ->> 'difficulty')::integer - coalesce(p_difficulty, 0)) end,
      r.created_at desc,
      r.id
    limit 1
    for update of r skip locked;
    exit when found or p_opponent is not null;
  end loop;
  if picked.id is null then
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

-- 4. The weak-spot check reads the latest 200 sessions.
create or replace function public.upload_history_limit() returns integer
language sql immutable set search_path = '' as $$ select 200 $$;

create or replace function public.player_upload_history(p_player_id uuid)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select coalesce(jsonb_agg(x.payload order by x.created_at, x.id), '[]'::jsonb)
  from (
    select s.payload, s.created_at, s.id
    from public.uploaded_sessions s
    where s.player_id = p_player_id
    order by s.created_at desc, s.id desc
    limit public.upload_history_limit()
  ) x
$$;

-- delete_my_account: the player's cached board rows go at once too.
create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller uuid := auth.uid();
begin
  if caller is null then
    raise exception 'not signed in' using errcode = '28000';
  end if;
  delete from public.board_rows where player_id = caller;
  delete from auth.users where id = caller;
end;
$$;

-- 5. The database against the free plan.
create or replace function owner_dashboard.free_plan_bytes() returns bigint
language sql immutable set search_path = '' as $$ select 500::bigint * 1024 * 1024 $$;

create or replace view owner_dashboard.database_usage as
select
  pg_database_size(current_database()) as bytes,
  owner_dashboard.free_plan_bytes() as free_plan_bytes,
  round(100.0 * pg_database_size(current_database()) / owner_dashboard.free_plan_bytes(), 1)
    as percent,
  pg_total_relation_size('public.uploaded_sessions') as session_bytes,
  (select count(*) from public.uploaded_sessions) as sessions,
  pg_database_size(current_database()) >= owner_dashboard.free_plan_bytes() / 2 as alert;

revoke all on function public.board_refresh(text) from public, anon, authenticated;
revoke all on function public.board_cache_age() from public, anon, authenticated;
revoke all on function public.duel_run_poolable(integer, text[], text) from public, anon, authenticated;
revoke all on function public.upload_history_limit() from public, anon, authenticated;
grant execute on function public.board_refresh(text) to service_role;
grant execute on function public.board_cache_age() to service_role;
grant execute on function public.duel_run_poolable(integer, text[], text) to service_role;
grant execute on function public.upload_history_limit() to service_role;
