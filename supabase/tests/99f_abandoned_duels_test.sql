-- Phase 7 close-out commit 1: progress sent during a duel, duels abandoned
-- for 24 hours listed for the server, unplayed challenges voided.

delete from auth.users;
-- Duels outlive their players (Phase 6a: "Deleted player"): cleared here.
delete from public.duels;
insert into auth.users (id, is_anonymous) values
  ('00000000-0000-0000-0000-0000000008a1', false),
  ('00000000-0000-0000-0000-0000000008a2', false);

insert into public.duels (id, mode, kind, config, first_player, second_player, state,
  created_at, opened_at, expires_at) values
  -- A pool duel handed out 25 hours ago: abandoned.
  ('00000000-0000-0000-0000-0000000009d1', 'basics', 'pool', '{}',
   '00000000-0000-0000-0000-0000000008a2', '00000000-0000-0000-0000-0000000008a1',
   'awaitingSecond', now() - interval '25 hours', null, null),
  -- A practice duel of 2 hours: not yet.
  ('00000000-0000-0000-0000-0000000009d2', 'count', 'practice', '{}',
   null, '00000000-0000-0000-0000-0000000008a1',
   'awaitingSecond', now() - interval '2 hours', null, null),
  -- A challenge sent 3 days ago, opened 30 hours ago: abandoned.
  ('00000000-0000-0000-0000-0000000009d3', 'advanced', 'challenge', '{}',
   '00000000-0000-0000-0000-0000000008a2', '00000000-0000-0000-0000-0000000008a1',
   'awaitingSecond', now() - interval '3 days', now() - interval '30 hours',
   now() + interval '4 days'),
  -- A challenge sent 3 days ago, never opened: waits (its 7 days).
  ('00000000-0000-0000-0000-0000000009d4', 'basics', 'challenge', '{}',
   '00000000-0000-0000-0000-0000000008a2', '00000000-0000-0000-0000-0000000008a1',
   'awaitingSecond', now() - interval '3 days', null, now() + interval '4 days'),
  -- A challenge whose challenger never played, 2 days ago: void.
  ('00000000-0000-0000-0000-0000000009d5', 'count', 'challenge', '{}',
   '00000000-0000-0000-0000-0000000008a1', '00000000-0000-0000-0000-0000000008a2',
   'awaitingFirst', now() - interval '2 days', null, now() + interval '5 days');

set role service_role;
do $$
declare
  a1 constant uuid := '00000000-0000-0000-0000-0000000008a1';
  a2 constant uuid := '00000000-0000-0000-0000-0000000008a2';
  list jsonb;
begin
  -- Progress: the second player's, on an open duel only.
  assert public.duel_save_progress('00000000-0000-0000-0000-0000000009d1', a1,
    '{"answers": [{"value": 1, "ms": 900}]}') = 'saved';
  assert public.duel_save_progress('00000000-0000-0000-0000-0000000009d1', a2, '{}')
    = 'notOpen', 'not the first player''s';
  assert public.duel_save_progress('00000000-0000-0000-0000-0000000009d5', a2, '{}')
    = 'notOpen', 'not before the challenger played';
  assert public.duel_context('00000000-0000-0000-0000-0000000009d1', a1) -> 'duel' -> 'progress'
    = '{"answers": [{"value": 1, "ms": 900}]}'::jsonb;

  -- Opening a challenge starts its 24 hours; once.
  perform public.duel_mark_opened('00000000-0000-0000-0000-0000000009d4', a1);
  assert (select opened_at from public.duels where id = '00000000-0000-0000-0000-0000000009d4')
    > now() - interval '1 minute';
  perform public.duel_mark_opened('00000000-0000-0000-0000-0000000009d3', a1);
  assert (select opened_at from public.duels where id = '00000000-0000-0000-0000-0000000009d3')
    < now() - interval '29 hours', 'opened before: unchanged';

  list := public.duel_abandoned(10);
  assert jsonb_array_length(list) = 2, 'pool and opened challenge: ' || list;
  assert list -> 0 ->> 'duelId' = '00000000-0000-0000-0000-0000000009d3', 'oldest start first';
  assert list -> 1 ->> 'player' = a1::text;
  assert jsonb_array_length(public.duel_abandoned(1)) = 1, 'the limit';
  assert (select state from public.duels where id = '00000000-0000-0000-0000-0000000009d5')
    = 'void', 'an unplayed challenge is void';
end;
$$;
reset role;

-- The owner's views: an abandoned run is not a flagged run to review.
insert into public.duel_runs (duel_id, player_id, mode, config, payload, lane, score, flags)
values
  ('00000000-0000-0000-0000-0000000009d1', '00000000-0000-0000-0000-0000000008a1', 'basics',
   '{}', '{}', '{}', '{"points": 1, "ms": 210000}', '{abandoned}'),
  ('00000000-0000-0000-0000-0000000009d3', '00000000-0000-0000-0000-0000000008a1', 'advanced',
   '{}', '{}', '{}', '{"points": 0, "ms": 240000}', '{abandoned,flatTimes}');
do $$
begin
  assert (select count(*) from owner_dashboard.flagged_runs) = 1, 'only the one with a real flag';
  assert (select abandoned from owner_dashboard.abandoned_duels) = 2;
end;
$$;

do $$
declare
  fn text;
begin
  foreach fn in array array[
    'public.duel_save_progress(uuid, uuid, jsonb)',
    'public.duel_mark_opened(uuid, uuid)',
    'public.duel_abandoned(integer)'
  ] loop
    assert not has_function_privilege('authenticated', fn, 'execute'), fn;
    assert has_function_privilege('service_role', fn, 'execute'), fn;
  end loop;
end;
$$;
