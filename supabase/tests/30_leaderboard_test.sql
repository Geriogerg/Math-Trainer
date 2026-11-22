-- Leaderboard (Phase 2 commit 7): ranks, "top N %", neighbours,
-- eligibility, and who may call what.

-- Twelve players: player k has addition at level 8·k (k = 1..12), 3
-- counted addition sessions and 3 completed games, active today — except
-- player 12 (inactive: last session 40 days ago) and player 11 (only 2
-- addition sessions).
do $$
declare
  k integer;
  id uuid;
begin
  for k in 1..12 loop
    id := ('00000000-0000-0000-0000-0000000001' || lpad(k::text, 2, '0'))::uuid;
    insert into auth.users (id, is_anonymous) values (id, false);
    insert into public.profiles (id, display_name) values (id, 'Player ' || k);
    insert into public.server_players (player_id, version, last_session_at, has_completed_session)
    values (id, 3, case when k = 12 then now() - interval '40 days' else now() end, true);
    insert into public.server_levels values
      (id, 'addition', 800 * k, case when k = 11 then 2 else 3 end, now());
    for g in 1..3 loop
      insert into public.uploaded_sessions (id, player_id, created_at, kind, payload, completed)
      values (gen_random_uuid(), id, now(), 'game', '{}', true);
    end loop;
  end loop;
  -- Player 13: signed up, never uploaded anything.
  insert into auth.users (id) values ('00000000-0000-0000-0000-000000000113');
end;
$$;

set role anon;
do $$
declare
  top jsonb := public.leaderboard_top('addition');
begin
  -- 10 eligible (11 lacks a session, 12 is inactive), best first.
  assert jsonb_array_length(top) = 10, 'top size ' || jsonb_array_length(top);
  assert top -> 0 ->> 'name' = 'Player 10', 'first: ' || (top -> 0)::text;
  assert (top -> 0 ->> 'rank')::int = 1, 'first rank';
  assert (top -> 0 ->> 'level')::int = 8000, 'first level';
  assert top -> 9 ->> 'name' = 'Player 1', 'last';
  assert (top -> 0 ->> 'isMe')::boolean = false, 'anon is nobody';
  -- Signed out: no "me".
  assert public.leaderboard_around_me('addition') ->> 'reason' = 'signedOut', 'signed out';
  -- Internals are not callable.
  begin
    perform public.leaderboard_rows('addition');
    raise exception 'anon called leaderboard_rows';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.leaderboard_top('cube');
    raise exception 'unknown board accepted';
  exception when invalid_parameter_value then null;
  end;
end;
$$;
reset role;

set role authenticated;
-- Player 3: rank 8 of 10, top 80 %, neighbours ranks 3..10.
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000103', false);
do $$
declare
  me jsonb := public.leaderboard_around_me('addition');
begin
  assert (me ->> 'eligible')::boolean, 'player 3 eligible: ' || me::text;
  assert (me ->> 'rank')::int = 8, 'rank ' || (me ->> 'rank');
  assert (me ->> 'total')::int = 10, 'total';
  assert (me ->> 'topPercent')::int = 80, 'top % ' || (me ->> 'topPercent');
  assert jsonb_array_length(me -> 'neighbours') = 8, 'neighbours ' || jsonb_array_length(me -> 'neighbours');
  assert (me -> 'neighbours' -> 0 ->> 'rank')::int = 3, 'first neighbour';
  assert exists (select from jsonb_array_elements(me -> 'neighbours') e
    where (e ->> 'isMe')::boolean and e ->> 'name' = 'Player 3'), 'me among neighbours';
end;
$$;

-- Player 10 is first: top 10 %, five below only.
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000110', false);
do $$
declare
  me jsonb := public.leaderboard_around_me('addition');
begin
  assert (me ->> 'rank')::int = 1 and (me ->> 'topPercent')::int = 10, me::text;
  assert jsonb_array_length(me -> 'neighbours') = 6, 'top neighbours';
end;
$$;

-- Why not on the board.
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000111', false);
do $$
declare
  me jsonb := public.leaderboard_around_me('addition');
begin
  assert me ->> 'reason' = 'notEnoughSessions', me::text;
  assert (me ->> 'sessionsNeeded')::int = 1, me::text;
  -- Never played division.
  me := public.leaderboard_around_me('division');
  assert me ->> 'reason' = 'notEnoughSessions' and (me ->> 'sessionsNeeded')::int = 3, me::text;
end;
$$;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000112', false);
do $$
begin
  assert public.leaderboard_around_me('addition') ->> 'reason' = 'inactive', 'inactive';
end;
$$;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000113', false);
do $$
begin
  assert public.leaderboard_around_me('overall') ->> 'reason' = 'noSessions', 'no sessions';
end;
$$;

-- The main board ('overall'): the mean of the four basics, unplayed =
-- level 1; advanced levels never count (Redesign phase). Player 10:
-- (8000 + 3 × 100) / 4 = 2075, whatever their power level.
reset role;
insert into public.server_levels values
  ('00000000-0000-0000-0000-000000000110', 'power', 9900, 3, now());
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000110', false);
do $$
declare
  me jsonb := public.leaderboard_around_me('overall');
begin
  assert (me ->> 'level')::int = 2075, 'main level ' || (me ->> 'level');
  -- Player 11 has 3 completed games: on the overall board, not on addition.
  assert (me ->> 'total')::int = 11, 'overall total ' || (me ->> 'total');
end;
$$;

-- Still no direct access to the tables.
do $$
begin
  begin
    perform 1 from public.server_levels;
    raise exception 'read server_levels';
  exception when insufficient_privilege then null;
  end;
end;
$$;
reset role;

-- Only linked players (Phase 2 commit 10): a guest with the best level is
-- not on the board, and is told why; once linked, same id, there at once.
do $$
begin
  insert into auth.users (id, is_anonymous)
    values ('00000000-0000-0000-0000-000000000199', true);
  insert into public.server_players (player_id, version, last_session_at, has_completed_session)
    values ('00000000-0000-0000-0000-000000000199', 3, now(), true);
  insert into public.server_levels values
    ('00000000-0000-0000-0000-000000000199', 'addition', 9900, 5, now());
end;
$$;
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000199', false);
do $$
begin
  assert public.leaderboard_top('addition') -> 0 ->> 'name' = 'Player 10',
    'a guest topped the board';
  assert public.leaderboard_around_me('addition') ->> 'reason' = 'notLinked',
    'guest reason: ' || public.leaderboard_around_me('addition')::text;
end;
$$;
reset role;
update auth.users set is_anonymous = false
  where id = '00000000-0000-0000-0000-000000000199';
set role authenticated;
do $$
begin
  assert (public.leaderboard_top('addition') -> 0 ->> 'level')::int = 9900,
    'linked player missing';
  assert (public.leaderboard_around_me('addition') ->> 'rank')::int = 1, 'linked rank';
end;
$$;
reset role;
