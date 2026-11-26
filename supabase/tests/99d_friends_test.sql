-- Phase 7 commit 7: friend codes, requests (and their daily limit),
-- friendships, head-to-head and history; guests refused.

delete from auth.users;
-- Duels outlive their players (Phase 6a: "Deleted player"): cleared here.
delete from public.duels;
insert into auth.users (id, is_anonymous) values
  ('00000000-0000-0000-0000-0000000003a1', false),
  ('00000000-0000-0000-0000-0000000003a2', false),
  ('00000000-0000-0000-0000-0000000003a3', false),
  ('00000000-0000-0000-0000-0000000003a9', true);
insert into public.profiles (id, display_name) values
  ('00000000-0000-0000-0000-0000000003a1', 'Léa'),
  ('00000000-0000-0000-0000-0000000003a2', 'Tom'),
  ('00000000-0000-0000-0000-0000000003a3', 'Inès');

do $$
begin
  -- 8 characters since Phase 6a (99l_details_test.sql has the rest).
  assert public.normalize_friend_code('MATH-7K2P-QX4M') = 'MATH-7K2P-QX4M';
  assert public.normalize_friend_code(' math 7k2p qx4m ') = 'MATH-7K2P-QX4M';
  assert public.normalize_friend_code('7k2pqx4m') = 'MATH-7K2P-QX4M';
  assert public.normalize_friend_code('MATH-MATH-MATH') = 'MATH-MATH-MATH';
  assert public.normalize_friend_code('MATH-7K2P-QX4O') is null, 'O is never in a code';
  assert public.normalize_friend_code('MATH-7K2') is null, 'too short';
  assert public.normalize_friend_code(null) is null;
end;
$$;

set role authenticated;

-- Each linked player gets a code, the same every time.
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000003a1', false);
create temporary table codes (who text, code text);
grant all on codes to authenticated;
insert into codes select 'lea', public.my_friend_code();
do $$
begin
  assert (select code from codes where who = 'lea') ~ '^MATH-[A-HJ-NP-Z2-9]{4}-[A-HJ-NP-Z2-9]{4}$';
  assert public.my_friend_code() = (select code from codes where who = 'lea'), 'stable';
end;
$$;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000003a2', false);
insert into codes select 'tom', public.my_friend_code();
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000003a3', false);
insert into codes select 'ines', public.my_friend_code();

-- Tom asks Léa; Léa sees it and accepts. Inès asks Léa; Léa asks Inès back:
-- friends at once.
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000003a2', false);
do $$
declare
  lea text := (select code from codes where who = 'lea');
begin
  assert public.friend_request(lea) = 'sent';
  assert public.friend_request(lower(lea)) = 'pending', 'asked already';
  assert public.friend_request('MATH-2222-2222') = 'unknown';
  assert public.friend_request((select code from codes where who = 'tom')) = 'self';
end;
$$;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000003a1', false);
do $$
declare
  incoming jsonb := public.friend_requests_incoming();
begin
  assert jsonb_array_length(incoming) = 1 and incoming -> 0 ->> 'name' = 'Tom';
  assert (public.duel_overview() ->> 'friendRequests')::integer = 1, 'the badge counts it';
  assert public.friend_respond('00000000-0000-0000-0000-0000000003a2', true) = 'accepted';
  assert public.friend_respond('00000000-0000-0000-0000-0000000003a2', true) = 'none';
  assert jsonb_array_length(public.friend_requests_incoming()) = 0;
end;
$$;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000003a3', false);
do $$
begin
  assert public.friend_request((select code from codes where who = 'lea')) = 'sent';
end;
$$;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000003a1', false);
do $$
begin
  assert public.friend_request((select code from codes where who = 'ines')) = 'friends',
    'a request both ways: friends';
  assert public.friend_request((select code from codes where who = 'tom')) = 'already';
end;
$$;
reset role;

-- Duels between Léa and Tom: Léa won a challenge, Tom won a pool duel, a
-- draw; a practice duel of Léa's never counts.
insert into public.duels (id, mode, kind, config, first_player, second_player, state,
  result, rated, finished_at) values
  ('00000000-0000-0000-0000-0000000004d1', 'basics', 'challenge', '{}',
   '00000000-0000-0000-0000-0000000003a2', '00000000-0000-0000-0000-0000000003a1', 'done',
   1, true, now() - interval '3 hours'),
  ('00000000-0000-0000-0000-0000000004d2', 'count', 'pool', '{}',
   '00000000-0000-0000-0000-0000000003a1', '00000000-0000-0000-0000-0000000003a2', 'done',
   1, true, now() - interval '2 hours'),
  ('00000000-0000-0000-0000-0000000004d3', 'advanced', 'challenge', '{}',
   '00000000-0000-0000-0000-0000000003a1', '00000000-0000-0000-0000-0000000003a2', 'done',
   0.5, false, now() - interval '1 hour'),
  ('00000000-0000-0000-0000-0000000004d4', 'basics', 'practice', '{}',
   null, '00000000-0000-0000-0000-0000000003a1', 'done', 1, false, now());
insert into public.duel_runs (duel_id, player_id, mode, config, payload, lane, score) values
  ('00000000-0000-0000-0000-0000000004d1', '00000000-0000-0000-0000-0000000003a1', 'basics',
   '{}', '{}', '{}', '{"points": 7, "ms": 38000}'),
  ('00000000-0000-0000-0000-0000000004d1', '00000000-0000-0000-0000-0000000003a2', 'basics',
   '{}', '{}', '{}', '{"points": 6, "ms": 31000}');

set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000003a1', false);
do $$
declare
  friends jsonb := public.friend_list();
  tom jsonb;
  history jsonb;
begin
  assert jsonb_array_length(friends) = 2, 'Inès and Tom: ' || friends;
  assert friends -> 0 ->> 'name' = 'Inès', 'by name';
  tom := friends -> 1;
  assert (tom ->> 'wins', tom ->> 'losses', tom ->> 'draws') = ('1'::text, '1'::text, '1'::text),
    'head-to-head: ' || tom;
  history := public.friend_history('00000000-0000-0000-0000-0000000003a2');
  assert jsonb_array_length(history) = 3, 'no practice';
  assert history -> 2 ->> 'mode' = 'basics', 'oldest last';
  assert (history -> 2 ->> 'result')::numeric = 1;
  assert history -> 2 -> 'you' = '{"points": 7, "ms": 38000}'::jsonb;
  assert history -> 2 -> 'them' = '{"points": 6, "ms": 31000}'::jsonb;
end;
$$;

-- Tom sees the same duels from his side.
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000003a2', false);
do $$
declare
  lea jsonb := public.friend_list() -> 0;
begin
  assert (lea ->> 'wins', lea ->> 'losses') = ('1'::text, '1'::text);
end;
$$;

-- Removing a friend: gone from both lists; the duels stay in history.
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000003a1', false);
do $$
begin
  perform public.friend_remove('00000000-0000-0000-0000-0000000003a2');
  assert jsonb_array_length(public.friend_list()) = 1;
  assert jsonb_array_length(public.friend_history('00000000-0000-0000-0000-0000000003a2')) = 3;
end;
$$;

-- 20 attempts a day, failed lookups included.
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000003a3', false);
do $$
declare
  i integer;
begin
  for i in 1..19 loop
    assert public.friend_request('MATH-2222-2222') = 'unknown';
  end loop;
  assert public.friend_request('MATH-2222-2222') = 'tooMany', 'Inès made 1 + 19 already';
end;
$$;

-- A guest: no code, no request.
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000003a9', false);
do $$
begin
  perform public.my_friend_code();
  assert false, 'a guest has no code';
exception when insufficient_privilege then
  null;
end;
$$;
reset role;

do $$
begin
  assert not has_function_privilege('anon', 'public.friend_request(text)', 'execute');
  assert not has_function_privilege('authenticated', 'public.duels_between(uuid, uuid)', 'execute');
  assert not has_table_privilege('authenticated', 'public.friend_codes', 'select');
end;
$$;

-- Deleting an account removes its code, requests and friendships.
delete from auth.users where id = '00000000-0000-0000-0000-0000000003a3';
do $$
begin
  assert not exists (select from public.friend_codes
    where player_id = '00000000-0000-0000-0000-0000000003a3');
  assert not exists (select from public.friendships
    where '00000000-0000-0000-0000-0000000003a3' in (player_a, player_b));
end;
$$;
drop table codes;
