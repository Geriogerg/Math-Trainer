-- Phase 6c commit 3 (plan v4.1; review B2): an account whose email was never
-- confirmed is a guest — off the boards, no duel, no friends, no name report
-- — exactly like an anonymous one; confirming it changes that.

delete from auth.users;
delete from public.duels;
insert into auth.users (id, is_anonymous, email, email_confirmed_at) values
  ('00000000-0000-0000-0000-0000000006c1', false, 'ana@test.example', now()),
  ('00000000-0000-0000-0000-0000000006c2', false, 'bo@test.example', null),
  ('00000000-0000-0000-0000-0000000006c3', true, null, null);
insert into public.profiles (id, display_name) values
  ('00000000-0000-0000-0000-0000000006c1', 'Ana'),
  ('00000000-0000-0000-0000-0000000006c2', 'Bo');
-- Both played enough to be ranked.
insert into public.server_players (player_id, version, last_session_at, completed_games) values
  ('00000000-0000-0000-0000-0000000006c1', 1, now(), 5),
  ('00000000-0000-0000-0000-0000000006c2', 1, now(), 5);
insert into public.server_levels (player_id, exercise_type, level, sessions_played, updated_at)
select p, t, 4000, 5, now()
from unnest(array[
  '00000000-0000-0000-0000-0000000006c1'::uuid,
  '00000000-0000-0000-0000-0000000006c2'::uuid
]) p,
unnest(array['addition', 'subtraction', 'multiplication', 'division']) t;
insert into public.duel_ratings (player_id, mode, rating, deviation, volatility, rated_duels, last_rated_at)
values
  ('00000000-0000-0000-0000-0000000006c1', 'basics', 1500, 60, 0.06, 12, now()),
  ('00000000-0000-0000-0000-0000000006c2', 'basics', 1600, 60, 0.06, 12, now());

-- The server's view (service role): who is linked, who is on a board.
do $$
declare
  ana uuid := '00000000-0000-0000-0000-0000000006c1';
  bo uuid := '00000000-0000-0000-0000-0000000006c2';
begin
  assert (public.duel_player(ana, 'basics') ->> 'linked')::boolean, 'confirmed: linked';
  assert not (public.duel_player(bo, 'basics') ->> 'linked')::boolean, 'unconfirmed: a guest';
  assert exists (select from public.leaderboard_rows('overall') r where r.player_id = ana);
  assert not exists (select from public.leaderboard_rows('overall') r where r.player_id = bo),
    'no unconfirmed account on the main board';
  assert not exists (select from public.leaderboard_rows('addition') r where r.player_id = bo);
  assert exists (select from public.duel_board_rows('basics') r where r.player_id = ana);
  assert not exists (select from public.duel_board_rows('basics') r where r.player_id = bo),
    'nor on a duel board';
  assert public.duel_create_challenge(gen_random_uuid(), 'basics', '{}'::jsonb, ana, bo) = 'notLinked',
    'an unconfirmed account cannot be challenged';
end;
$$;

set role authenticated;

-- Bo, unconfirmed, as the app: Ranks says "not linked", Online says guest,
-- friends and reports refused.
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000006c2', false);
do $$
declare
  refused boolean;
begin
  assert public.leaderboard_around_me('overall') ->> 'reason' = 'notLinked';
  assert public.duel_board_around_me('basics') ->> 'reason' = 'notLinked';
  assert not (public.duel_overview() ->> 'linked')::boolean;
  refused := false;
  begin
    perform public.my_friend_code();
  exception when insufficient_privilege then
    refused := true;
  end;
  assert refused, 'no friend code for an unconfirmed account';
  refused := false;
  begin
    perform public.report_player_name('00000000-0000-0000-0000-0000000006c1');
  exception when insufficient_privilege then
    refused := true;
  end;
  assert refused, 'an unconfirmed account cannot report a name';
end;
$$;

-- Ana, confirmed: all of it.
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000006c1', false);
do $$
begin
  assert (public.leaderboard_around_me('overall') ->> 'eligible')::boolean;
  assert (public.duel_overview() ->> 'linked')::boolean;
  assert public.my_friend_code() is not null;
end;
$$;

reset role;

-- Bo confirms: a saved account from then on.
update auth.users set email_confirmed_at = now()
where id = '00000000-0000-0000-0000-0000000006c2';
do $$
begin
  assert (public.duel_player('00000000-0000-0000-0000-0000000006c2', 'basics') ->> 'linked')::boolean;
  assert exists (
    select from public.leaderboard_rows('overall') r
    where r.player_id = '00000000-0000-0000-0000-0000000006c2'
  ), 'confirmed: on the board';
end;
$$;

delete from public.duels;
delete from auth.users;
