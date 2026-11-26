-- Phase 6a commit 3 (plan v3.9; review M5): when a session ended, and the
-- owner's moderation — read by the boards, the duel pool, friend search and
-- the player's own Profile.

delete from auth.users;
-- Duels outlive their players (Phase 6a: "Deleted player"): cleared here.
delete from public.duels;
insert into auth.users (id, is_anonymous) values
  ('00000000-0000-0000-0000-000000000ab1', false),
  ('00000000-0000-0000-0000-000000000ab2', false),
  ('00000000-0000-0000-0000-000000000ab3', false);
insert into public.profiles (id, display_name) values
  ('00000000-0000-0000-0000-000000000ab1', 'Maud'),
  ('00000000-0000-0000-0000-000000000ab2', 'Nils'),
  ('00000000-0000-0000-0000-000000000ab3', 'Olga');

-- The end of a session: its start plus its answers' times.
set role service_role;
do $$
declare
  p1 constant uuid := '00000000-0000-0000-0000-000000000ab1';
  start constant timestamptz := now() - interval '10 minutes';
  state jsonb;
  out text;
begin
  assert public.upload_played_ms('{"answers": [{"elapsedMs": 1000}, {"elapsedMs": 2500}]}') = 3500;
  assert public.upload_played_ms('{"session": {}}') = 0, 'no answers';
  assert public.upload_played_ms('{"answers": "x"}') = 0, 'not a list';

  state := public.player_server_state(p1);
  assert state -> 'lastSessionEndsAt' = 'null'::jsonb and state -> 'moderation' = 'null'::jsonb;
  select outcome into out from public.apply_validated_session(
    '00000000-0000-0000-0000-00000000ac01', p1, 0, start, 'game', true,
    '{"session": {"rulesVersion": 8}, "answers": [{"elapsedMs": 1000}, {"elapsedMs": 2500}]}',
    '{"addition": {"level": 4000, "sessionsPlayed": 12, "updatedAt": "2026-11-26T10:00:00Z"}}',
    '{overlapsPrevious}');
  assert out = 'applied', out;
  state := public.player_server_state(p1);
  assert (state ->> 'lastSessionEndsAt')::timestamptz = start + interval '3.5 seconds',
    state ->> 'lastSessionEndsAt';
  -- An earlier session accepted later does not move the end back.
  select outcome into out from public.apply_validated_session(
    '00000000-0000-0000-0000-00000000ac02', p1, 1, start - interval '1 hour', 'training', true,
    '{"answers": [{"elapsedMs": 9000}]}', '{}', '{}');
  assert (public.player_server_state(p1) ->> 'lastSessionEndsAt')::timestamptz
    = start + interval '3.5 seconds';
end;
$$;
reset role;

-- Three ranked players: a level board, a duel board, runs in the pool.
insert into public.server_players (player_id, version, last_session_at, has_completed_session)
values
  ('00000000-0000-0000-0000-000000000ab2', 1, now(), true),
  ('00000000-0000-0000-0000-000000000ab3', 1, now(), true)
on conflict (player_id) do nothing;
insert into public.server_levels (player_id, exercise_type, level, sessions_played, updated_at)
values
  ('00000000-0000-0000-0000-000000000ab2', 'addition', 3000, 12, now()),
  ('00000000-0000-0000-0000-000000000ab3', 'addition', 2000, 12, now());
insert into public.duel_ratings (player_id, mode, rating, deviation, volatility, rated_duels,
  last_rated_at)
select id, 'basics', 1500, 100, 0.06, 20, now() from auth.users;
insert into public.duels (id, mode, kind, config, second_player, state, result, finished_at)
values
  ('00000000-0000-0000-0000-00000000ad01', 'basics', 'practice', '{"seed": 31, "difficulty": 4}',
   '00000000-0000-0000-0000-000000000ab1', 'done', 1, now()),
  ('00000000-0000-0000-0000-00000000ad02', 'basics', 'practice', '{"seed": 32, "difficulty": 4}',
   '00000000-0000-0000-0000-000000000ab2', 'done', 1, now());
insert into public.duel_runs (duel_id, player_id, mode, config, payload, lane, score)
values
  ('00000000-0000-0000-0000-00000000ad01', '00000000-0000-0000-0000-000000000ab1', 'basics',
   '{"seed": 31, "difficulty": 4}', '{}', '{"answers": []}', '{"points": 3, "ms": 9000}'),
  ('00000000-0000-0000-0000-00000000ad02', '00000000-0000-0000-0000-000000000ab2', 'basics',
   '{"seed": 32, "difficulty": 4}', '{}', '{"answers": []}', '{"points": 3, "ms": 9000}');
insert into public.friend_codes (player_id, code) values
  ('00000000-0000-0000-0000-000000000ab1', 'MATH-AAAA-AAAA');
insert into public.friendships (player_a, player_b) values
  ('00000000-0000-0000-0000-000000000ab1', '00000000-0000-0000-0000-000000000ab2');

do $$
declare
  p1 constant uuid := '00000000-0000-0000-0000-000000000ab1';
  p2 constant uuid := '00000000-0000-0000-0000-000000000ab2';
  p3 constant uuid := '00000000-0000-0000-0000-000000000ab3';
begin
  assert (select count(*) from public.leaderboard_rows('addition')) = 3;
  assert (select count(*) from public.duel_board_rows('basics')) = 3;

  -- The owner hides Maud.
  assert owner_dashboard.moderate(p1, 'hidden', 'scripted uploads');
  assert not owner_dashboard.moderate('00000000-0000-0000-0000-0000000000ff', 'hidden', ''),
    'nobody';
  begin
    perform owner_dashboard.moderate(p1, 'erased', '');
    assert false, 'an unknown state must raise';
  exception when invalid_parameter_value then null;
  end;
  assert not public.player_visible(p1) and public.player_visible(p2);

  -- Off every board; the others keep their ranks among themselves.
  assert (select array_agg(player_id order by rank) from public.leaderboard_rows('addition'))
    = array[p2, p3], 'the level board';
  assert (select total from public.leaderboard_rows('addition') limit 1) = 2;
  assert not exists (select from public.duel_board_rows('basics') where player_id = p1);
end;
$$;

-- Out of the pool, both ways; no challenge from or to them; their code
-- finds nobody.
set role service_role;
do $$
declare
  p1 constant uuid := '00000000-0000-0000-0000-000000000ab1';
  p2 constant uuid := '00000000-0000-0000-0000-000000000ab2';
  p3 constant uuid := '00000000-0000-0000-0000-000000000ab3';
  offer jsonb;
begin
  offer := public.duel_take_run(p3, 'basics', 1500, null, null, gen_random_uuid());
  assert offer -> 'opponent' ->> 'id' = p2::text, 'never the hidden player''s run: ' || offer;
  assert public.duel_take_run(p3, 'basics', 1500, p1, 4, gen_random_uuid()) is null,
    'not even as a rematch';
  assert public.duel_take_run(p1, 'basics', 1500, null, null, gen_random_uuid()) is null,
    'a hidden player races nobody''s run: practice';
  assert public.duel_create_challenge(gen_random_uuid(), 'basics', '{}', p1, p2) = 'notAllowed';
  assert public.duel_create_challenge(gen_random_uuid(), 'basics', '{}', p2, p1) = 'notAllowed';
  assert public.duel_player(p1, 'basics') ->> 'moderation' = 'hidden';
  assert public.duel_player(p2, 'basics') -> 'moderation' = 'null'::jsonb;
  assert public.player_server_state(p1) ->> 'moderation' = 'hidden';
end;
$$;
reset role;

set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000ab3', false);
do $$
begin
  assert public.friend_request('MATH-AAAA-AAAA') = 'unknown', 'a hidden player is not found';
  assert not public.my_account_under_review();
end;
$$;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000ab1', false);
do $$
begin
  assert public.my_account_under_review(), 'the player is told, on their own Profile';
end;
$$;
reset role;
select set_config('request.jwt.claim.sub', '', false);

-- Banned, then lifted.
do $$
declare
  p1 constant uuid := '00000000-0000-0000-0000-000000000ab1';
  evidence record;
begin
  assert owner_dashboard.moderate(p1, 'banned', 'again');
  assert (select (state, reason) = ('banned', 'again') from owner_dashboard.moderation
    where player_id = p1), 'one row per player, the latest decision';
  assert public.player_server_state(p1) ->> 'moderation' = 'banned';

  select * into evidence from owner_dashboard.moderation_evidence where player_id = p1;
  assert evidence.flagged_sessions = 'overlapsPrevious 1', evidence.flagged_sessions;
  assert evidence.moderation = 'banned';

  assert owner_dashboard.unmoderate(p1);
  assert not owner_dashboard.unmoderate(p1), 'nothing left to lift';
  assert public.player_visible(p1);
  assert (select count(*) from public.leaderboard_rows('addition')) = 3, 'back on the board';
end;
$$;

set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000ab3', false);
do $$
begin
  assert public.friend_request('MATH-AAAA-AAAA') = 'sent', 'found again';
end;
$$;
reset role;
select set_config('request.jwt.claim.sub', '', false);

-- Closed to players; deleted with the account.
do $$
begin
  assert not has_table_privilege('authenticated', 'public.player_moderation', 'select');
  assert not has_table_privilege('anon', 'public.player_moderation', 'select');
  assert (select relrowsecurity from pg_class where oid = 'public.player_moderation'::regclass);
  assert not has_function_privilege('authenticated', 'public.player_visible(uuid)', 'execute');
  assert not has_function_privilege('anon', 'public.my_account_under_review()', 'execute');
  assert not has_function_privilege('authenticated',
    'owner_dashboard.moderate(uuid, text, text)', 'execute');
  perform owner_dashboard.moderate('00000000-0000-0000-0000-000000000ab2', 'hidden', 'x');
  delete from auth.users where id = '00000000-0000-0000-0000-000000000ab2';
  assert not exists (select from public.player_moderation);
end;
$$;
