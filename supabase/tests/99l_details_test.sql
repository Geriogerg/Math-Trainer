-- Phase 6a commit 6 (plan v3.9; review m7, n3): friend codes of 8
-- characters and a new one on demand; every function has a fixed
-- search_path.

delete from auth.users;
-- Duels outlive their players (Phase 6a: "Deleted player"): cleared here.
delete from public.duels;
insert into auth.users (id, is_anonymous) values
  ('00000000-0000-0000-0000-000000000da1', false),
  ('00000000-0000-0000-0000-000000000da2', false);

do $$
begin
  assert public.normalize_friend_code('MATH-7K2P-QX4M') = 'MATH-7K2P-QX4M';
  assert public.normalize_friend_code(' math 7k2p qx4m ') = 'MATH-7K2P-QX4M';
  assert public.normalize_friend_code('7K2PQX4M') = 'MATH-7K2P-QX4M';
  assert public.normalize_friend_code('MATHMATH') = 'MATH-MATH-MATH';
  -- An old 4-character code reads as an 8-character one nobody has.
  assert public.normalize_friend_code('MATH-7K2P') = 'MATH-MATH-7K2P';
  assert public.normalize_friend_code('7K2P') is null, 'too short';
  assert public.normalize_friend_code('MATH-7K2P-QX4O') is null, 'no O';
  assert public.normalize_friend_code(null) is null;
end;
$$;

set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000da1', false);
create temp table codes (who text, code text);
grant all on codes to authenticated;
insert into codes select 'first', public.my_friend_code();
do $$
declare
  first_code text := (select code from codes where who = 'first');
  fresh text;
begin
  assert first_code ~ '^MATH-[A-HJ-NP-Z2-9]{4}-[A-HJ-NP-Z2-9]{4}$', first_code;
  assert public.my_friend_code() = first_code, 'stable';
  fresh := public.new_friend_code();
  assert fresh <> first_code and fresh ~ '^MATH-[A-HJ-NP-Z2-9]{4}-[A-HJ-NP-Z2-9]{4}$', fresh;
  assert public.my_friend_code() = fresh, 'the new one is the code now';
end;
$$;
-- The old code finds nobody; the new one does.
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000da2', false);
do $$
begin
  assert public.friend_request((select code from codes where who = 'first')) = 'unknown';
end;
$$;
reset role;
do $$
declare
  fresh text := (select c.code from public.friend_codes c
    where c.player_id = '00000000-0000-0000-0000-000000000da1');
begin
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000da2', false);
  set local role authenticated;
  assert public.friend_request(lower(replace(fresh, '-', ' '))) = 'sent';
  reset role;
end;
$$;
select set_config('request.jwt.claim.sub', '', false);

-- A guest has no code to renew; nobody draws codes directly.
do $$
begin
  assert has_function_privilege('authenticated', 'public.new_friend_code()', 'execute');
  assert not has_function_privilege('anon', 'public.new_friend_code()', 'execute');
  assert not has_function_privilege('authenticated', 'public.draw_friend_code()', 'execute');
end;
$$;

-- Every function of public and owner_dashboard has a fixed search_path.
do $$
declare
  missing text;
begin
  select string_agg(n.nspname || '.' || p.proname, ', ') into missing
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname in ('public', 'owner_dashboard') and p.prokind = 'f'
    and not exists (
      select from unnest(coalesce(p.proconfig, '{}')) c where c like 'search_path=%');
  assert missing is null, 'no search_path: ' || missing;
end;
$$;
