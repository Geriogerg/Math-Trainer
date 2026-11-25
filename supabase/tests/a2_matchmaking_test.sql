-- Phase 7 commit 4: matchmaking's reads (a player, an unanswered duel to
-- resume) and challenges (one open per pair and mode). Service role only.

delete from auth.users;
insert into auth.users (id, is_anonymous) values
  ('00000000-0000-0000-0000-0000000000e1', false),
  ('00000000-0000-0000-0000-0000000000e2', false),
  ('00000000-0000-0000-0000-0000000000e9', true);
insert into public.profiles (id, display_name) values
  ('00000000-0000-0000-0000-0000000000e2', 'Inès');
insert into public.server_levels (player_id, exercise_type, level, sessions_played, updated_at)
values ('00000000-0000-0000-0000-0000000000e1', 'addition', 4000, 3, now());

set role service_role;
do $$
declare
  e1 constant uuid := '00000000-0000-0000-0000-0000000000e1';
  e2 constant uuid := '00000000-0000-0000-0000-0000000000e2';
  e9 constant uuid := '00000000-0000-0000-0000-0000000000e9';
  cfg constant jsonb := '{"mode":"basics","seed":5,"difficulty":4,"rules":8,"duelRules":1}';
  p jsonb;
  offer jsonb;
begin
  p := public.duel_player(e1, 'basics');
  assert (p ->> 'linked')::boolean, 'linked';
  assert p -> 'rating' = 'null'::jsonb, 'no rating yet';
  assert p -> 'levels' = '{"addition": 4000}'::jsonb, 'server levels';
  assert not (public.duel_player(e9, 'basics') ->> 'linked')::boolean, 'a guest';
  assert public.duel_player('00000000-0000-0000-0000-0000000000ff', 'basics') is null;

  -- An unanswered practice duel is handed back within the hour.
  assert public.duel_open_offer(e1, 'basics') is null, 'nothing open';
  perform public.duel_insert('00000000-0000-0000-0000-00000000f001', 'basics', 'practice',
    cfg, null, e1, '{"answers":[]}', null);
  offer := public.duel_open_offer(e1, 'basics');
  assert offer ->> 'duelId' = '00000000-0000-0000-0000-00000000f001', 'resumed';
  assert offer -> 'lane' = '{"answers":[]}'::jsonb;
  assert offer -> 'opponent' = 'null'::jsonb, 'practice: no opponent';
  assert public.duel_open_offer(e1, 'count') is null, 'another mode';
  update public.duels set created_at = now() - interval '2 hours'
  where id = '00000000-0000-0000-0000-00000000f001';
  assert public.duel_open_offer(e1, 'basics') is null, 'not after an hour';

  -- Challenges.
  assert public.duel_create_challenge('00000000-0000-0000-0000-00000000f002', 'basics', cfg,
    e1, e1) = 'self';
  assert public.duel_create_challenge('00000000-0000-0000-0000-00000000f002', 'basics', cfg,
    e1, e9) = 'notLinked', 'a guest';
  assert public.duel_create_challenge('00000000-0000-0000-0000-00000000f002', 'basics', cfg,
    e1, '00000000-0000-0000-0000-0000000000ff') = 'notLinked', 'nobody';
  assert public.duel_create_challenge('00000000-0000-0000-0000-00000000f002', 'basics', cfg,
    e1, e2) = 'created';
  assert (select (kind, state, first_player, second_player) from public.duels
          where id = '00000000-0000-0000-0000-00000000f002')
    = ('challenge', 'awaitingFirst', e1, e2), 'the challenger plays first';
  assert (select expires_at from public.duels where id = '00000000-0000-0000-0000-00000000f002')
    between now() + interval '7 days' - interval '1 minute' and now() + interval '7 days',
    '7 days';
  assert public.duel_create_challenge('00000000-0000-0000-0000-00000000f003', 'basics', cfg,
    e2, e1) = 'exists', 'one open challenge per pair, either way round';
  assert public.duel_create_challenge('00000000-0000-0000-0000-00000000f003', 'count', cfg,
    e2, e1) = 'created', 'another mode';
  update public.duels set expires_at = now() - interval '1 minute'
  where id = '00000000-0000-0000-0000-00000000f002';
  assert public.duel_create_challenge('00000000-0000-0000-0000-00000000f004', 'basics', cfg,
    e2, e1) = 'created', 'the old one expired';
end;
$$;
reset role;

do $$
declare
  fn text;
begin
  foreach fn in array array[
    'public.duel_player(uuid, text)',
    'public.duel_open_offer(uuid, text)',
    'public.duel_create_challenge(uuid, text, jsonb, uuid, uuid)'
  ] loop
    assert not has_function_privilege('anon', fn, 'execute'), 'anon: ' || fn;
    assert not has_function_privilege('authenticated', fn, 'execute'), 'authenticated: ' || fn;
    assert has_function_privilege('service_role', fn, 'execute'), 'service role: ' || fn;
  end loop;
end;
$$;
