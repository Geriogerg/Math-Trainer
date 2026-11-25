-- Phase 7 commit 6: the Online tab's overview and the duel boards, read by
-- players through security definer functions on auth.uid().

delete from auth.users;
insert into auth.users (id, is_anonymous) values
  ('00000000-0000-0000-0000-0000000001a1', false),
  ('00000000-0000-0000-0000-0000000001a2', false),
  ('00000000-0000-0000-0000-0000000001a3', false),
  ('00000000-0000-0000-0000-0000000001a9', true);
insert into public.profiles (id, display_name) values
  ('00000000-0000-0000-0000-0000000001a1', 'Léa'),
  ('00000000-0000-0000-0000-0000000001a2', 'Tom');

-- Ratings: Léa 1600 (12 rated), Tom 1500 (10), the third provisional (3),
-- the guest 2000 (never on a board).
insert into public.duel_ratings
  (player_id, mode, rating, deviation, volatility, rated_duels, last_rated_at) values
  ('00000000-0000-0000-0000-0000000001a1', 'basics', 1600.4, 80, 0.06, 12, now()),
  ('00000000-0000-0000-0000-0000000001a2', 'basics', 1500.2, 90, 0.06, 10, now()),
  ('00000000-0000-0000-0000-0000000001a3', 'basics', 1700, 200, 0.06, 3, now()),
  ('00000000-0000-0000-0000-0000000001a9', 'basics', 2000, 80, 0.06, 20, now());

-- Duels: Tom raced Léa's run and won; Léa raced a practice and lost; Tom
-- challenged Léa (waiting for her); an expired challenge.
insert into public.duels (id, mode, kind, config, first_player, second_player, state,
  result, rated, created_at, finished_at, expires_at) values
  ('00000000-0000-0000-0000-0000000002b1', 'basics', 'pool', '{}',
   '00000000-0000-0000-0000-0000000001a1', '00000000-0000-0000-0000-0000000001a2', 'done',
   1, true, now() - interval '2 hours', now() - interval '1 hour', null),
  ('00000000-0000-0000-0000-0000000002b2', 'advanced', 'practice', '{}',
   null, '00000000-0000-0000-0000-0000000001a1', 'done',
   0, false, now() - interval '3 hours', now() - interval '3 hours', null),
  ('00000000-0000-0000-0000-0000000002b3', 'basics', 'challenge', '{}',
   '00000000-0000-0000-0000-0000000001a2', '00000000-0000-0000-0000-0000000001a1',
   'awaitingSecond', null, false, now(), null, now() + interval '7 days'),
  ('00000000-0000-0000-0000-0000000002b4', 'count', 'challenge', '{}',
   '00000000-0000-0000-0000-0000000001a2', '00000000-0000-0000-0000-0000000001a1',
   'awaitingSecond', null, false, now() - interval '8 days', null,
   now() - interval '1 day');

set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000001a1', false);
do $$
declare
  o jsonb := public.duel_overview();
begin
  assert (o ->> 'linked')::boolean, 'linked';
  assert (o -> 'ratings' -> 'basics' ->> 'ratedDuels')::integer = 12;
  assert jsonb_array_length(o -> 'waiting') = 1, 'one waiting (the expired one is not)';
  assert o -> 'waiting' -> 0 ->> 'from' = 'Tom';
  assert o -> 'waiting' -> 0 ->> 'mode' = 'basics';
  assert jsonb_array_length(o -> 'recent') = 2, 'raced and practice: ' || (o -> 'recent');
  assert (o -> 'recent' -> 0 ->> 'raced')::boolean, 'Tom raced her run (newest first)';
  assert o -> 'recent' -> 0 ->> 'opponent' = 'Tom';
  assert (o -> 'recent' -> 0 ->> 'result')::numeric = 0, 'from her side: lost';
  assert o -> 'recent' -> 1 ->> 'kind' = 'practice';
  assert o -> 'recent' -> 1 -> 'opponent' = 'null'::jsonb;
end;
$$;

-- Tom sees his challenge in Recent, waiting.
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000001a2', false);
do $$
declare
  o jsonb := public.duel_overview();
begin
  assert jsonb_array_length(o -> 'waiting') = 0;
  assert o -> 'recent' -> 0 ->> 'state' = 'awaitingSecond', 'his challenge, waiting';
  assert (o -> 'recent' -> 1 ->> 'result')::numeric = 1, 'he won';
end;
$$;

-- Boards: Léa 1600, Tom 1500; the provisional player and the guest are not
-- on them.
do $$
declare
  top jsonb := public.duel_board_top('basics');
  me jsonb := public.duel_board_around_me('basics');
begin
  assert jsonb_array_length(top) = 2, 'two ranked: ' || top;
  assert top -> 0 ->> 'name' = 'Léa' and (top -> 0 ->> 'rating')::integer = 1600;
  assert (top -> 1 ->> 'isMe')::boolean, 'Tom is the caller';
  assert (me ->> 'rank')::integer = 2 and (me ->> 'total')::integer = 2;
  assert (me ->> 'rating')::integer = 1500;
  assert jsonb_array_length(me -> 'neighbours') = 2;
  assert public.duel_board_top('count') = '[]'::jsonb, 'empty board';
end;
$$;

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000001a3', false);
do $$
declare
  me jsonb := public.duel_board_around_me('basics');
begin
  assert me ->> 'reason' = 'provisional', 'provisional: ' || me;
  assert (me ->> 'sessionsNeeded')::integer = 7;
  assert public.duel_board_around_me('advanced') ->> 'reason' = 'noDuels';
end;
$$;

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000001a9', false);
do $$
begin
  assert public.duel_overview() = '{"linked": false}'::jsonb, 'a guest';
  assert public.duel_board_around_me('basics') ->> 'reason' = 'notLinked';
end;
$$;
reset role;

-- Signed out: boards readable, standing signedOut; the overview is for
-- players only.
set role anon;
select set_config('request.jwt.claim.sub', '', false);
do $$
begin
  assert jsonb_array_length(public.duel_board_top('basics')) = 2;
  assert public.duel_board_around_me('basics') ->> 'reason' = 'signedOut';
end;
$$;
reset role;

do $$
begin
  assert not has_function_privilege('anon', 'public.duel_overview()', 'execute');
  assert has_function_privilege('authenticated', 'public.duel_overview()', 'execute');
  assert not has_function_privilege('authenticated', 'public.duel_board_rows(text)', 'execute');
  assert not has_table_privilege('authenticated', 'public.duels', 'select');
end;
$$;

do $$
begin
  perform public.duel_board_top('chain');
  assert false, 'an unknown board must raise';
exception when invalid_parameter_value then
  null;
end;
$$;
