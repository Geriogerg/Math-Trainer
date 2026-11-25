-- Phase 7 commit 2: duels, runs, the pool, ratings applied with optimistic
-- locks, challenges and their daily rating limit, expiry, refusals. The
-- server calls these as the service role; players cannot.

delete from auth.users;
insert into auth.users (id, is_anonymous) values
  ('00000000-0000-0000-0000-0000000000c1', false),
  ('00000000-0000-0000-0000-0000000000c2', false),
  ('00000000-0000-0000-0000-0000000000c3', false),
  ('00000000-0000-0000-0000-0000000000c9', true);
insert into public.profiles (id, display_name) values
  ('00000000-0000-0000-0000-0000000000c1', 'Léa'),
  ('00000000-0000-0000-0000-0000000000c2', 'Tom');

set role service_role;
do $$
declare
  c1 constant uuid := '00000000-0000-0000-0000-0000000000c1';
  c2 constant uuid := '00000000-0000-0000-0000-0000000000c2';
  c3 constant uuid := '00000000-0000-0000-0000-0000000000c3';
  c9 constant uuid := '00000000-0000-0000-0000-0000000000c9';
  start constant jsonb := '{"rating": 1500, "deviation": 350, "volatility": 0.06}';
  cfg constant jsonb := '{"mode":"basics","seed":1,"difficulty":4,"rules":8,"duelRules":1}';
  lane constant jsonb := '{"answers":[]}';
  score constant jsonb := '{"points":6,"ms":30000}';
  offer jsonb;
  ctx jsonb;
  outcome text;
  run uuid;
  served integer;
begin
  -- Practice: c1 races a simulated lane; c1's run is stored, its rating
  -- created at the start values, no rating change.
  perform public.duel_insert('00000000-0000-0000-0000-00000000d001', 'basics', 'practice',
    cfg, null, c1, lane, null);
  select a.outcome, a.run_id into outcome, run from public.apply_duel_run(
    '00000000-0000-0000-0000-00000000d001', c1, '{"run":1}', lane, score, '{}', start,
    1, false, null) a;
  assert outcome = 'applied', 'practice run applied: ' || outcome;
  assert (select state from public.duels where id = '00000000-0000-0000-0000-00000000d001') = 'done';
  assert (select rating from public.duel_ratings where player_id = c1 and mode = 'basics') = 1500,
    'rating created at the start';
  assert (select rated_duels from public.duel_ratings where player_id = c1) = 0, 'practice not rated';
  select a.outcome into outcome from public.apply_duel_run(
    '00000000-0000-0000-0000-00000000d001', c1, '{"run":1}', lane, score, '{}', start,
    1, false, null) a;
  assert outcome = 'duplicate', 'resent: duplicate';

  -- The pool: c2 (no rating yet) gets c1's run.
  offer := public.duel_take_run(c2, 'basics', 1600, null, null,
    '00000000-0000-0000-0000-00000000d002');
  assert offer ->> 'kind' = 'pool', 'a pool duel';
  assert offer -> 'opponent' ->> 'name' = 'Léa', 'the owner''s name';
  assert (offer -> 'opponent' ->> 'rating')::numeric = 1500, 'the owner''s rating';
  assert offer -> 'config' = cfg, 'the run''s config';
  assert (select serves from public.duel_runs where id = run) = 1, 'served once';
  -- Not twice for c2 (same config), never for c1 (own run), not for a mode
  -- without runs.
  assert public.duel_take_run(c2, 'basics', 1600, null, null,
    '00000000-0000-0000-0000-00000000d003') is null, 'never the same questions again';
  assert public.duel_take_run(c1, 'basics', 1500, null, null,
    '00000000-0000-0000-0000-00000000d003') is null, 'never one''s own run';
  assert public.duel_take_run(c3, 'count', 1300, null, null,
    '00000000-0000-0000-0000-00000000d003') is null, 'empty pool: null';

  -- c2's run decides the duel, rated: both ratings move, versions checked.
  ctx := public.duel_context('00000000-0000-0000-0000-00000000d002', c2);
  assert ctx -> 'duel' ->> 'state' = 'awaitingSecond';
  assert ctx -> 'duel' ->> 'opponentName' = 'Léa';
  assert (ctx -> 'ratings' -> c1::text ->> 'version')::integer = 0;
  assert ctx -> 'ratings' -> c2::text is null, 'c2 has no rating yet';
  assert not (ctx ->> 'pairRatedToday')::boolean;
  select a.outcome into outcome from public.apply_duel_run(
    '00000000-0000-0000-0000-00000000d002', c2, '{"run":2}', lane, score, '{}',
    '{"rating": 1600, "deviation": 350, "volatility": 0.06}', 1, true,
    jsonb_build_object(c1, '{"rating":1480,"deviation":300,"volatility":0.06,"expectedVersion":1}'::jsonb,
                       c2, '{"rating":1620,"deviation":300,"volatility":0.06,"expectedVersion":0}'::jsonb)) a;
  assert outcome = 'stale', 'a version that moved: stale';
  select a.outcome into outcome from public.apply_duel_run(
    '00000000-0000-0000-0000-00000000d002', c2, '{"run":2}', lane, score, '{}',
    '{"rating": 1600, "deviation": 350, "volatility": 0.06}', 1, true,
    jsonb_build_object(c1, '{"rating":1480,"deviation":300,"volatility":0.06,"expectedVersion":0}'::jsonb,
                       c2, '{"rating":1620,"deviation":300,"volatility":0.06,"expectedVersion":0}'::jsonb)) a;
  assert outcome = 'applied', 'applied: ' || outcome;
  assert (select rating from public.duel_ratings where player_id = c1) = 1480;
  assert (select rating from public.duel_ratings where player_id = c2) = 1620;
  assert (select rated_duels from public.duel_ratings where player_id = c2) = 1;
  assert (select version from public.duel_ratings where player_id = c1) = 1;
  assert (select (state, result, rated, first_rating_before, second_rating_after)
          from public.duels where id = '00000000-0000-0000-0000-00000000d002')
    = ('done'::text, 1::double precision, true, 1500::double precision, 1620::double precision);
  select a.outcome into outcome from public.apply_duel_run(
    '00000000-0000-0000-0000-00000000d002', c1, '{}', lane, score, '{}', start, 1, false, null) a;
  assert outcome = 'notOpen', 'not the first player''s turn';

  -- c2's run is in the pool too (the same questions as c1's): c3 could
  -- race either. Pool limits on both: 5 serves; a flagged run until
  -- reviewed ok; 10 latest per owner; never an anonymous owner's.
  assert (select count(*) from public.duel_runs where mode = 'basics') = 2;
  update public.duel_runs set serves = 5 where mode = 'basics';
  assert public.duel_take_run(c3, 'basics', 1500, null, null,
    '00000000-0000-0000-0000-00000000d003') is null, 'served 5 times: out';
  update public.duel_runs set serves = 0, flags = '{implausiblyFast}' where mode = 'basics';
  assert public.duel_take_run(c3, 'basics', 1500, null, null,
    '00000000-0000-0000-0000-00000000d003') is null, 'flagged: out';
  update public.duel_runs set review = 'rejected' where mode = 'basics' and player_id = c2;
  update public.duel_runs set review = 'ok' where id = run;
  offer := public.duel_take_run(c3, 'basics', 1500, null, null,
    '00000000-0000-0000-0000-00000000d003');
  assert offer -> 'opponent' ->> 'id' = c1::text, 'reviewed ok: in; rejected: out';

  -- c1 plays 11 practice duels in Advanced, each on its own config.
  for i in 1..11 loop
    perform public.duel_insert(('00000000-0000-0000-0000-0000000e' || lpad(i::text, 4, '0'))::uuid,
      'advanced', 'practice',
      jsonb_build_object('mode', 'advanced', 'seed', i, 'difficulty', 4, 'rules', 8, 'duelRules', 1),
      null, c1, lane, null);
    perform public.apply_duel_run(('00000000-0000-0000-0000-0000000e' || lpad(i::text, 4, '0'))::uuid,
      c1, '{}', lane, score, '{}', start, 0, false, null);
    update public.duel_runs set created_at = now() - make_interval(mins => 20 - i)
    where duel_id = ('00000000-0000-0000-0000-0000000e' || lpad(i::text, 4, '0'))::uuid;
  end loop;
  served := 0;
  for i in 1..11 loop
    offer := public.duel_take_run(c3, 'advanced', 1500, null, null,
      ('00000000-0000-0000-0000-0000000f' || lpad(i::text, 4, '0'))::uuid);
    exit when offer is null;
    served := served + 1;
    assert (offer -> 'config' ->> 'seed')::integer > 1, 'the oldest run is out of the pool';
  end loop;
  assert served = 10, '10 runs served, then none: ' || served;

  -- An anonymous owner's run is never served.
  perform public.duel_insert('00000000-0000-0000-0000-00000000d009', 'count', 'practice',
    '{"mode":"count","seed":9,"difficulty":1,"rules":8,"duelRules":1}', null, c9, lane, null);
  perform public.apply_duel_run('00000000-0000-0000-0000-00000000d009', c9, '{}', lane, score,
    '{}', start, 0, false, null);
  assert public.duel_take_run(c3, 'count', 1300, null, null,
    '00000000-0000-0000-0000-00000000d00a') is null, 'a guest''s run: never served';

  -- A rematch: only that opponent's runs, the closest tier first.
  update public.duel_runs set serves = 0;
  update public.duel_runs set config = jsonb_set(config, '{difficulty}', '7')
  where mode = 'advanced' and (config ->> 'seed')::integer = 11;
  offer := public.duel_take_run(c2, 'advanced', 1500, c1, 7,
    '00000000-0000-0000-0000-00000000d00b');
  assert (offer -> 'config' ->> 'seed')::integer = 11, 'the run of the closest tier';
  assert public.duel_take_run(c2, 'advanced', 1500, c3, 4,
    '00000000-0000-0000-0000-00000000d00c') is null, 'an opponent without runs: null';

  -- A challenge: c1 plays first, then c2; rated once a day per pair.
  perform public.duel_insert('00000000-0000-0000-0000-00000000d010', 'basics', 'challenge',
    '{"mode":"basics","seed":10,"difficulty":4,"rules":8,"duelRules":1}', c1, c2, null,
    now() + interval '7 days');
  assert (select state from public.duels where id = '00000000-0000-0000-0000-00000000d010')
    = 'awaitingFirst';
  select a.outcome into outcome from public.apply_duel_run('00000000-0000-0000-0000-00000000d010',
    c2, '{}', lane, score, '{}', start, 1, false, null) a;
  assert outcome = 'notOpen', 'the friend waits for the challenger';
  select a.outcome into outcome from public.apply_duel_run('00000000-0000-0000-0000-00000000d010',
    c1, '{}', '{"answers":[1]}', score, '{}', start, null, false, null) a;
  assert outcome = 'applied';
  assert (select (state, first_lane) from public.duels
          where id = '00000000-0000-0000-0000-00000000d010')
    = ('awaitingSecond'::text, '{"answers":[1]}'::jsonb), 'open to the friend, with the lane';
  select a.outcome into outcome from public.apply_duel_run('00000000-0000-0000-0000-00000000d010',
    c2, '{}', lane, score, '{}', start, 0, true,
    jsonb_build_object(c1, '{"rating":1490,"deviation":290,"volatility":0.06,"expectedVersion":1}'::jsonb,
                       c2, '{"rating":1610,"deviation":290,"volatility":0.06,"expectedVersion":1}'::jsonb)) a;
  assert outcome = 'applied', 'first challenge of the day: rated';
  perform public.duel_insert('00000000-0000-0000-0000-00000000d011', 'basics', 'challenge',
    '{"mode":"basics","seed":11,"difficulty":4,"rules":8,"duelRules":1}', c2, c1, null,
    now() + interval '7 days');
  perform public.apply_duel_run('00000000-0000-0000-0000-00000000d011', c2, '{}', lane, score,
    '{}', start, null, false, null);
  ctx := public.duel_context('00000000-0000-0000-0000-00000000d011', c1);
  assert (ctx ->> 'pairRatedToday')::boolean, 'the pair was rated today (either way round)';
  select a.outcome into outcome from public.apply_duel_run('00000000-0000-0000-0000-00000000d011',
    c1, '{}', lane, score, '{}', start, 1, true,
    jsonb_build_object(c1, '{"rating":1,"deviation":1,"volatility":1,"expectedVersion":2}'::jsonb,
                       c2, '{"rating":1,"deviation":1,"volatility":1,"expectedVersion":2}'::jsonb)) a;
  assert outcome = 'stale', 'a second rated challenge the same day: stale';
  select a.outcome into outcome from public.apply_duel_run('00000000-0000-0000-0000-00000000d011',
    c1, '{}', lane, score, '{}', start, 1, false, null) a;
  assert outcome = 'applied', 'played and recorded, unrated';

  -- Expired: 7 days and an hour's grace.
  perform public.duel_insert('00000000-0000-0000-0000-00000000d012', 'count', 'challenge',
    '{"mode":"count","seed":12,"difficulty":1,"rules":8,"duelRules":1}', c1, c2, null,
    now() - interval '2 hours');
  update public.duels set state = 'awaitingSecond' where id = '00000000-0000-0000-0000-00000000d012';
  select a.outcome into outcome from public.apply_duel_run('00000000-0000-0000-0000-00000000d012',
    c2, '{}', lane, score, '{}', start, 1, false, null) a;
  assert outcome = 'expired', 'past its 7 days';

  -- A refused run: recorded once, the duel void.
  perform public.duel_insert('00000000-0000-0000-0000-00000000d013', 'basics', 'practice',
    cfg, null, c3, lane, null);
  perform public.record_duel_run_refused('00000000-0000-0000-0000-00000000d013', c3,
    'badDerivation', 'round 1', '{"forged":true}');
  perform public.record_duel_run_refused('00000000-0000-0000-0000-00000000d013', c3,
    'other', 'again', '{}');
  ctx := public.duel_context('00000000-0000-0000-0000-00000000d013', c3);
  assert ctx -> 'duel' ->> 'state' = 'void', 'a refused run voids its duel';
  assert ctx -> 'rejection' ->> 'reason' = 'badDerivation', 'the first reason stays';
  assert public.duel_context('00000000-0000-0000-0000-0000000000ff', c3) is null, 'no duel';
end;
$$;
reset role;

-- A deleted account takes its duels, runs and ratings with it.
delete from auth.users where id = '00000000-0000-0000-0000-0000000000c1';
do $$
begin
  assert not exists (select from public.duel_ratings
    where player_id = '00000000-0000-0000-0000-0000000000c1'), 'ratings deleted';
  assert not exists (select from public.duel_runs
    where player_id = '00000000-0000-0000-0000-0000000000c1'), 'runs deleted';
  assert not exists (select from public.duels
    where first_player = '00000000-0000-0000-0000-0000000000c1'
       or second_player = '00000000-0000-0000-0000-0000000000c1'), 'duels deleted';
end;
$$;

do $$
declare
  fn text;
begin
  foreach fn in array array[
    'public.duel_take_run(uuid, text, double precision, uuid, integer, uuid)',
    'public.duel_insert(uuid, text, text, jsonb, uuid, uuid, jsonb, timestamptz)',
    'public.duel_context(uuid, uuid)',
    'public.apply_duel_run(uuid, uuid, jsonb, jsonb, jsonb, text[], jsonb, double precision, boolean, jsonb)',
    'public.record_duel_run_refused(uuid, uuid, text, text, jsonb)'
  ] loop
    assert not has_function_privilege('anon', fn, 'execute'), 'anon: ' || fn;
    assert not has_function_privilege('authenticated', fn, 'execute'), 'authenticated: ' || fn;
    assert has_function_privilege('service_role', fn, 'execute'), 'service role: ' || fn;
  end loop;
  assert not has_table_privilege('authenticated', 'public.duel_runs', 'select'), 'runs closed';
  assert not has_table_privilege('anon', 'public.duel_ratings', 'select'), 'ratings closed';
end;
$$;
