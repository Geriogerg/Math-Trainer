-- Phase 6a commit 1 (plan v3.9; review B5, M1, M2, M3, n1): duel results
-- hold. Chosen duels and the rolling 24 hours, the expiry of an opened
-- challenge, who may be challenged, forfeits recorded without voiding.

delete from auth.users;
-- Duels outlive their players (Phase 6a: "Deleted player"): cleared here.
delete from public.duels;
insert into auth.users (id, is_anonymous) values
  ('00000000-0000-0000-0000-000000000ca1', false),
  ('00000000-0000-0000-0000-000000000ca2', false),
  ('00000000-0000-0000-0000-000000000ca3', false),
  ('00000000-0000-0000-0000-000000000ca4', true);

insert into public.duel_ratings (player_id, mode, rating, deviation, volatility) values
  ('00000000-0000-0000-0000-000000000ca1', 'basics', 1500, 200, 0.06),
  ('00000000-0000-0000-0000-000000000ca2', 'basics', 1500, 200, 0.06);

-- Two pool runs of player 2 (different configs), one flagged.
insert into public.duels (id, mode, kind, config, second_player, state, result, finished_at)
values
  ('00000000-0000-0000-0000-000000000cb1', 'basics', 'practice', '{"seed": 1, "difficulty": 4}',
   '00000000-0000-0000-0000-000000000ca2', 'done', 1, now() - interval '3 days'),
  ('00000000-0000-0000-0000-000000000cb2', 'basics', 'practice', '{"seed": 2, "difficulty": 4}',
   '00000000-0000-0000-0000-000000000ca2', 'done', 1, now() - interval '3 days');
insert into public.duel_runs (id, duel_id, player_id, mode, config, payload, lane, score, flags)
values
  ('00000000-0000-0000-0000-000000000cc1', '00000000-0000-0000-0000-000000000cb1',
   '00000000-0000-0000-0000-000000000ca2', 'basics', '{"seed": 1, "difficulty": 4}',
   '{}', '{"answers": []}', '{"points": 3, "ms": 9000}', '{}'),
  ('00000000-0000-0000-0000-000000000cc2', '00000000-0000-0000-0000-000000000cb2',
   '00000000-0000-0000-0000-000000000ca2', 'basics', '{"seed": 2, "difficulty": 4}',
   '{}', '{"answers": []}', '{"points": 3, "ms": 9000}', '{}');

set role service_role;
do $$
declare
  p1 constant uuid := '00000000-0000-0000-0000-000000000ca1';
  p2 constant uuid := '00000000-0000-0000-0000-000000000ca2';
  p3 constant uuid := '00000000-0000-0000-0000-000000000ca3';
  guest constant uuid := '00000000-0000-0000-0000-000000000ca4';
  matched constant uuid := '00000000-0000-0000-0000-000000000cd1';
  rematch constant uuid := '00000000-0000-0000-0000-000000000cd2';
  challenge constant uuid := '00000000-0000-0000-0000-000000000cd3';
  late constant uuid := '00000000-0000-0000-0000-000000000cd4';
  start constant jsonb := '{"rating": 1500, "deviation": 350, "volatility": 0.06}';
  ctx jsonb;
  out text;
  ratings jsonb;
begin
  -- M3. A challenge only to a friend or an opponent of the last 30 days.
  assert public.duel_create_challenge(challenge, 'basics', '{"seed": 9}', p1, p3) = 'notAllowed',
    'a stranger cannot be challenged';
  assert public.duel_create_challenge(challenge, 'basics', '{"seed": 9}', p1, guest) = 'notLinked';
  assert not exists (select from public.duels where id = challenge);

  -- A matchmaking duel is not chosen; a rematch (p_opponent) is.
  assert public.duel_take_run(p1, 'basics', 1500, null, null, matched) is not null;
  assert not (select chosen from public.duels where id = matched);
  ctx := public.duel_context(matched, p1);
  assert (ctx -> 'duel' ->> 'chosen')::boolean = false;
  assert ctx ->> 'now' is not null, 'the database''s clock';
  assert ctx -> 'firstFlags' = '[]'::jsonb;
  assert (ctx ->> 'pairRatedToday')::boolean = false;

  -- B5. The second player's refused run is recorded without voiding the
  -- duel; then the forfeited run decides it, rated.
  perform public.record_duel_run_forfeit(matched, p1, 'wrongShape', 'no answers', '{"answers": []}');
  perform public.record_duel_run_forfeit(matched, p1, 'badElapsed', 'again', '{}');
  assert (select state from public.duels where id = matched) = 'awaitingSecond', 'not void';
  assert (select reason from public.duel_run_rejections where duel_id = matched) = 'wrongShape',
    'recorded once';
  perform public.record_duel_run_forfeit(matched, p2, 'wrongShape', 'not theirs', '{}');
  assert (select count(*) from public.duel_run_rejections where duel_id = matched) = 1,
    'only the second player''s';
  ratings := jsonb_build_object(
    p2::text, '{"rating": 1510, "deviation": 190, "volatility": 0.06, "expectedVersion": 0}'::jsonb,
    p1::text, '{"rating": 1490, "deviation": 190, "volatility": 0.06, "expectedVersion": 0}'::jsonb);
  select outcome into out from public.apply_duel_run(matched, p1, '{"answers": []}',
    '{"answers": []}', '{"points": 0, "ms": 240000}', array['forfeited'], start, 0, true, ratings);
  assert out = 'applied', out;
  assert (select (state, result, rated) = ('done', 0::double precision, true)
    from public.duels where id = matched);
  ctx := public.duel_context(matched, p1);
  assert ctx -> 'rejection' ->> 'reason' = 'wrongShape' and ctx -> 'run' is not null,
    'a forfeit: a reason and a run';
  -- The forfeited run is never in the pool, nor in the owner's review list.
  assert public.duel_take_run(p3, 'basics', 1490, p1, 4, gen_random_uuid()) is null;

  -- M3. Having played, the two may challenge each other.
  assert public.duel_create_challenge(challenge, 'basics', '{"seed": 9}', p1, p2) = 'created';
  assert (select chosen from public.duels where id = challenge), 'a challenge is chosen';
  -- Opened during 6 days, played 24 hours from then: 7 days in all.
  assert (select expires_at between now() + interval '5 days 23 hours'
    and now() + interval '6 days 1 hour' from public.duels where id = challenge);

  -- A rematch takes the opponent's other run: a chosen pool duel.
  assert public.duel_take_run(p1, 'basics', 1490, p2, 4, rematch) ->> 'kind' = 'pool';
  assert (select chosen from public.duels where id = rematch);
  -- n1, M3. No chosen duel of the pair was rated yet (the first was not chosen).
  assert (public.duel_context(rematch, p1) ->> 'pairRatedToday')::boolean = false;
  ratings := jsonb_build_object(
    p2::text, '{"rating": 1500, "deviation": 185, "volatility": 0.06, "expectedVersion": 1}'::jsonb,
    p1::text, '{"rating": 1500, "deviation": 185, "volatility": 0.06, "expectedVersion": 1}'::jsonb);
  select outcome into out from public.apply_duel_run(rematch, p1, '{"answers": []}',
    '{"answers": []}', '{"points": 5, "ms": 30000}', '{}', start, 1, true, ratings);
  assert out = 'applied', out;

  -- The challenge of the same pair and mode, minutes later: its context
  -- says the pair was rated; applying it rated anyway is 'stale'.
  select outcome into out from public.apply_duel_run(challenge, p1, '{"answers": []}',
    '{"answers": []}', '{"points": 5, "ms": 30000}', '{}', start, null, false, null);
  assert out = 'applied', 'the challenger''s run: ' || out;
  perform public.duel_mark_opened(challenge, p2);
  assert (public.duel_context(challenge, p2) ->> 'pairRatedToday')::boolean,
    'a chosen pool duel counts for the pair, not only challenges';
  select outcome into out from public.apply_duel_run(challenge, p2, '{"answers": []}',
    '{"answers": []}', '{"points": 5, "ms": 30000}', '{}', start, 0.5, true, ratings);
  assert out = 'stale', out;

  -- n1. Rolling 24 hours, not the UTC day: 23 hours ago still counts, 25 no longer.
  reset role;
  update public.duels set finished_at = now() - interval '23 hours' where id = rematch;
  assert public.duel_pair_rated_recently(challenge, 'basics', p1, p2);
  update public.duels set finished_at = now() - interval '25 hours' where id = rematch;
  assert not public.duel_pair_rated_recently(challenge, 'basics', p1, p2);
  assert not public.duel_pair_rated_recently(challenge, 'advanced', p1, p2), 'per mode';

  -- B5. An opened challenge is played or lost whatever its expiry; an
  -- unopened one expires (an hour's grace).
  update public.duels set expires_at = now() - interval '2 days',
    opened_at = now() - interval '3 days' where id = challenge;
  set role service_role;
  select outcome into out from public.apply_duel_run(challenge, p2, '{"answers": []}',
    '{"answers": []}', '{"points": 0, "ms": 240000}', array['abandoned'], start, 0, true,
    jsonb_build_object(
      p1::text, '{"rating": 1505, "deviation": 180, "volatility": 0.06, "expectedVersion": 2}'::jsonb,
      p2::text, '{"rating": 1495, "deviation": 180, "volatility": 0.06, "expectedVersion": 2}'::jsonb));
  assert out = 'applied', 'scored after its expiry: ' || out;
  assert (select (state, result, rated) = ('done', 0::double precision, true)
    from public.duels where id = challenge);

  assert public.duel_create_challenge(late, 'advanced', '{"seed": 10}', p2, p1) = 'created';
  select outcome into out from public.apply_duel_run(late, p2, '{"answers": []}',
    '{"answers": []}', '{"points": 1, "ms": 1}', '{}', start, null, false, null);
  reset role;
  update public.duels set expires_at = now() - interval '2 hours' where id = late;
  set role service_role;
  select outcome into out from public.apply_duel_run(late, p1, '{"answers": []}',
    '{"answers": []}', '{"points": 1, "ms": 1}', '{}', start, 0.5, false, null);
  assert out = 'expired', 'never opened: ' || out;

  -- M1. A first run's flags reach the context until the owner reviews it ok.
  reset role;
  update public.duel_runs set flags = '{implausiblyFast}'
  where duel_id = late and player_id = p2;
  assert public.duel_context(late, p1) -> 'firstFlags' = '["implausiblyFast"]'::jsonb;
  update public.duel_runs set review = 'ok' where duel_id = late and player_id = p2;
  assert public.duel_context(late, p1) -> 'firstFlags' = '[]'::jsonb;

  -- The owner's lists: forfeits by reason; a forfeited run is not a review matter.
  assert (select (reason, forfeits) = ('wrongShape', 1::bigint)
    from owner_dashboard.forfeited_duels where player_id = p1);
  assert not exists (
    select from owner_dashboard.flagged_runs f
    join public.duel_runs r on r.id = f.run_id where 'forfeited' = any(r.flags));
end;
$$;
reset role;

-- Service role only.
do $$
begin
  assert not has_function_privilege('authenticated',
    'public.record_duel_run_forfeit(uuid, uuid, text, text, jsonb)', 'execute');
  assert not has_function_privilege('anon',
    'public.duel_pair_rated_recently(uuid, text, uuid, uuid)', 'execute');
end;
$$;
