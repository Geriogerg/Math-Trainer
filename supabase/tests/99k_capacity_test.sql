-- Phase 6a commit 5 (plan v3.9; review M7, M8, M9): completed games
-- counted as accepted, boards cached a minute, the duel pool maintained,
-- matchmaking by widening windows, the weak-spot history bounded, the
-- database against the free plan.

delete from auth.users;
-- Duels outlive their players (Phase 6a: "Deleted player"): cleared here.
delete from public.duels;
delete from public.board_snapshots;
insert into auth.users (id, is_anonymous)
select ('00000000-0000-0000-0000-0000000005' || lpad(i::text, 2, '0'))::uuid, false
from generate_series(1, 6) i;
insert into public.profiles (id, display_name)
select ('00000000-0000-0000-0000-0000000005' || lpad(i::text, 2, '0'))::uuid, 'Cap ' || i
from generate_series(1, 6) i;

-- 1. Completed Levelling games, counted as they are accepted.
set role service_role;
do $$
declare
  p1 constant uuid := '00000000-0000-0000-0000-000000000501';
  out text;
begin
  for i in 1..4 loop
    select outcome into out from public.apply_validated_session(gen_random_uuid(), p1, i - 1,
      now() - ((10 - i) || ' minutes')::interval, case when i = 4 then 'training' else 'game' end,
      i <> 3, '{"session": {"rulesVersion": 8}, "answers": []}',
      '{"addition": {"level": 5000, "sessionsPlayed": 3, "updatedAt": "2026-11-26T10:00:00Z"}}',
      '{}');
    assert out = 'applied', out;
  end loop;
  select outcome into out from public.apply_validated_session(gen_random_uuid(), p1, 4, now(),
    'game', true, '{"session": {"rulesVersion": 1}, "answers": []}', '{}', '{}');
  assert (select completed_games from public.server_players where player_id = p1) = 2,
    'two completed games of rules v2+ (not the interrupted one, the training, the v1 one)';
end;
$$;
reset role;

-- 2. Boards: computed once, served for a minute (this session sets the
-- production value; the test database's default is 0).
set mt.board_cache_seconds = 60;
insert into public.server_players (player_id, version, last_session_at, completed_games)
select ('00000000-0000-0000-0000-0000000005' || lpad(i::text, 2, '0'))::uuid, 1, now(), 5
from generate_series(2, 5) i
on conflict (player_id) do update set completed_games = 5, last_session_at = now();
update public.server_players set completed_games = 5
where player_id = '00000000-0000-0000-0000-000000000501';
insert into public.server_levels (player_id, exercise_type, level, sessions_played, updated_at)
select ('00000000-0000-0000-0000-0000000005' || lpad(i::text, 2, '0'))::uuid, t, 1000 * i, 5, now()
from generate_series(1, 5) i,
  unnest(array['addition', 'subtraction', 'multiplication', 'division']) t
on conflict (player_id, exercise_type) do update set level = excluded.level,
  sessions_played = 5;

set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000502', false);
do $$
declare
  top jsonb;
  mine jsonb;
begin
  top := public.leaderboard_top('overall');
  assert jsonb_array_length(top) = 5, 'five players: ' || top;
  assert top -> 0 ->> 'name' = 'Cap 5' and (top -> 0 ->> 'rank')::int = 1;
  mine := public.leaderboard_around_me('overall');
  assert (mine ->> 'eligible')::boolean and (mine ->> 'rank')::int = 4
    and (mine ->> 'total')::int = 5 and (mine ->> 'level')::int = 2000, mine::text;
  assert jsonb_array_length(mine -> 'neighbours') = 5, 'everyone is within 5 places';
  assert (mine -> 'neighbours' -> 3 ->> 'isMe')::boolean;
end;
$$;
reset role;

-- The levels move; the board does not, for a minute.
update public.server_levels set level = 9900
where player_id = '00000000-0000-0000-0000-000000000501';
set role authenticated;
do $$
begin
  assert public.leaderboard_top('overall') -> 0 ->> 'name' = 'Cap 5', 'served from the cache';
end;
$$;
reset role;
update public.board_snapshots set computed_at = now() - interval '61 seconds';
set role authenticated;
do $$
begin
  assert public.leaderboard_top('overall') -> 0 ->> 'name' = 'Cap 1', 'recomputed after a minute';
  -- Not ranked: the reason from the counts, without reading the sessions.
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000506', false);
  assert public.leaderboard_around_me('overall') ->> 'reason' = 'noSessions';
end;
$$;
reset role;
select set_config('request.jwt.claim.sub', '', false);
do $$
begin
  assert (select count(*) from public.board_rows where board = 'overall') = 5;
  assert (select total from public.board_snapshots where board = 'overall') = 5;
  assert not has_table_privilege('authenticated', 'public.board_rows', 'select');
  assert not has_function_privilege('authenticated', 'public.board_refresh(text)', 'execute');
end;
$$;
-- A player deleting their account leaves the cached board at once.
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000505', false);
select public.delete_my_account();
reset role;
select set_config('request.jwt.claim.sub', '', false);
do $$
begin
  assert not exists (select from auth.users
    where id = '00000000-0000-0000-0000-000000000505');
  assert not exists (select from public.board_rows
    where player_id = '00000000-0000-0000-0000-000000000505');
  assert (select relpersistence from pg_class where oid = 'public.board_rows'::regclass) = 'u',
    'a cache: unlogged';
end;
$$;
reset mt.board_cache_seconds;

-- 3. The duel pool, maintained by trigger.
insert into public.duel_ratings (player_id, mode, rating, deviation, volatility) values
  ('00000000-0000-0000-0000-000000000501', 'basics', 1450, 100, 0.06),
  ('00000000-0000-0000-0000-000000000502', 'basics', 1520, 100, 0.06),
  ('00000000-0000-0000-0000-000000000503', 'basics', 2000, 100, 0.06),
  ('00000000-0000-0000-0000-000000000504', 'basics', 1500, 100, 0.06);
insert into public.duels (id, mode, kind, config, second_player, state)
select ('00000000-0000-0000-0000-00000000c' || lpad(i::text, 3, '0'))::uuid, 'basics',
  'practice', jsonb_build_object('seed', i, 'difficulty', 4),
  ('00000000-0000-0000-0000-0000000005' || lpad((1 + i % 3)::text, 2, '0'))::uuid, 'done'
from generate_series(1, 14) i;
-- Player 2 gets 12 runs (one every minute), players 1 and 3 one each.
insert into public.duel_runs (duel_id, player_id, mode, config, payload, lane, score, created_at)
select d.id, d.second_player, 'basics', d.config, '{}', '{"answers": []}',
  '{"points": 4, "ms": 1}', now() - ((20 - (d.config ->> 'seed')::int) || ' minutes')::interval
from public.duels d where d.second_player = '00000000-0000-0000-0000-000000000502';
insert into public.duel_runs (duel_id, player_id, mode, config, payload, lane, score)
select d.id, d.second_player, 'basics', d.config, '{}', '{"answers": []}', '{"points": 4, "ms": 1}'
from public.duels d
where d.second_player in ('00000000-0000-0000-0000-000000000501',
  '00000000-0000-0000-0000-000000000503')
  and (d.config ->> 'seed')::int in (2, 3);
do $$
declare
  p2 constant uuid := '00000000-0000-0000-0000-000000000502';
  oldest uuid;
begin
  assert (select count(*) from public.duel_runs where player_id = p2) = 5,
    (select count(*) from public.duel_runs where player_id = p2)::text;
end;
$$;
-- More runs for player 2, to pass 10.
insert into public.duels (id, mode, kind, config, second_player, state)
select gen_random_uuid(), 'basics', 'practice', jsonb_build_object('seed', 100 + i, 'difficulty', 4),
  '00000000-0000-0000-0000-000000000502', 'done'
from generate_series(1, 7) i;
insert into public.duel_runs (duel_id, player_id, mode, config, payload, lane, score, created_at)
select d.id, d.second_player, 'basics', d.config, '{}', '{"answers": []}',
  '{"points": 4, "ms": 1}', now() - ((10 - ((d.config ->> 'seed')::int - 100)) || ' minutes')::interval
from public.duels d where (d.config ->> 'seed')::int > 100;
do $$
declare
  p2 constant uuid := '00000000-0000-0000-0000-000000000502';
  run public.duel_runs;
begin
  assert (select count(*) from public.duel_runs where player_id = p2) = 12;
  assert (select count(*) from public.duel_runs where player_id = p2 and in_pool) = 10,
    'only the 10 latest';
  assert not (select r.in_pool from public.duel_runs r where r.player_id = p2
    order by r.created_at limit 1), 'the oldest is out';

  -- Served five times: out. Flagged: out; reviewed ok: back.
  select * into run from public.duel_runs r where r.player_id = p2 and r.in_pool
  order by r.created_at desc limit 1;
  update public.duel_runs set serves = 5 where id = run.id;
  assert not (select in_pool from public.duel_runs where id = run.id), 'served 5 times';
  update public.duel_runs set serves = 0, flags = '{implausiblyFast}' where id = run.id;
  assert not (select in_pool from public.duel_runs where id = run.id), 'flagged';
  perform owner_dashboard.review_run(run.id, 'ok');
  assert (select in_pool from public.duel_runs where id = run.id), 'reviewed ok';
  perform owner_dashboard.review_run(run.id, 'rejected');
  assert not (select in_pool from public.duel_runs where id = run.id), 'rejected';
end;
$$;

-- 4. Matchmaking: the closest rating, by widening windows; never a config
-- the caller played.
set role service_role;
do $$
declare
  p4 constant uuid := '00000000-0000-0000-0000-000000000504';
  offer jsonb;
begin
  -- 1520 (20 away) before 1450 (50 away) before 2000.
  offer := public.duel_take_run(p4, 'basics', 1500, null, null, gen_random_uuid());
  assert offer -> 'opponent' ->> 'name' = 'Cap 2', offer::text;
  -- At 1990: 2000 within the first window.
  offer := public.duel_take_run(p4, 'basics', 1990, null, null, gen_random_uuid());
  assert offer -> 'opponent' ->> 'name' = 'Cap 3', offer::text;
  -- At 900: nobody within 400; the closest of everyone (1450).
  offer := public.duel_take_run(p4, 'basics', 900, null, null, gen_random_uuid());
  assert offer -> 'opponent' ->> 'name' = 'Cap 1', offer::text;
  -- A rematch: that opponent's runs only.
  offer := public.duel_take_run(p4, 'basics', 900, '00000000-0000-0000-0000-000000000502', 4,
    gen_random_uuid());
  assert offer -> 'opponent' ->> 'name' = 'Cap 2', offer::text;
  -- Cap 1 and Cap 3 had one run each: now played by p4, never again.
  assert public.duel_take_run(p4, 'basics', 1450, '00000000-0000-0000-0000-000000000501', 4,
    gen_random_uuid()) is null, 'a config the caller already played';
end;
$$;
reset role;

-- 5. The weak-spot history: the latest 200 sessions, oldest first.
insert into public.uploaded_sessions (id, player_id, created_at, kind, payload, completed)
select gen_random_uuid(), '00000000-0000-0000-0000-000000000503',
  now() - ((300 - i) || ' minutes')::interval, 'game',
  jsonb_build_object('n', i), true
from generate_series(1, 210) i;
set role service_role;
do $$
declare
  history jsonb := public.player_upload_history('00000000-0000-0000-0000-000000000503');
begin
  assert jsonb_array_length(history) = 200, jsonb_array_length(history)::text;
  assert (history -> 0 ->> 'n')::int = 11 and (history -> 199 ->> 'n')::int = 210,
    'the latest 200, oldest first';
end;
$$;
reset role;

-- 6. The database against the free plan.
do $$
declare
  usage record;
begin
  select * into usage from owner_dashboard.database_usage;
  assert usage.bytes > 0 and usage.free_plan_bytes = 524288000;
  assert usage.percent = round(100.0 * usage.bytes / usage.free_plan_bytes, 1);
  assert usage.alert = (usage.bytes >= 262144000);
end;
$$;
