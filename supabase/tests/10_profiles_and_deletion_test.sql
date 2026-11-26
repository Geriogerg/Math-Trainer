-- Profiles row-level security and `delete_my_account()` (Phase 1 SQL, a
-- migration since Phase 2 commit 2). Each block raises on failure;
-- `tool/sql/test_sql.sh` stops at the first error.

insert into auth.users (id, email, is_anonymous) values
  ('00000000-0000-0000-0000-00000000000a', null, true),
  ('00000000-0000-0000-0000-00000000000b', 'b@example.com', false);

-- A player writes their own profile, not someone else's.
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000a', false);
insert into public.profiles (id, display_name)
  values ('00000000-0000-0000-0000-00000000000a', 'Ada');
do $$
begin
  begin
    insert into public.profiles (id, display_name)
      values ('00000000-0000-0000-0000-00000000000b', 'Not me');
    raise exception 'inserted another player''s profile';
  exception when insufficient_privilege then
    null; -- refused by row-level security, as it must be
  end;
end;
$$;
reset role;

-- Each player reads their own profile only (Phase 6a commit 4; boards
-- read names through `public_display_name`); signed out, none.
insert into public.profiles (id, display_name)
  values ('00000000-0000-0000-0000-00000000000b', 'Bea');
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000a', false);
do $$
begin
  assert (select array_agg(display_name) from public.profiles) = array['Ada'],
    'a player read someone else''s profile';
end;
$$;
reset role;
set role anon;
do $$
begin
  begin
    perform 1 from public.profiles;
    raise exception 'anon read profiles';
  exception when insufficient_privilege then null;
  end;
end;
$$;
-- Signed out: the deletion function is not even callable.
do $$
begin
  begin
    perform public.delete_my_account();
    raise exception 'anon called delete_my_account';
  exception when insufficient_privilege then
    null;
  end;
end;
$$;
reset role;

-- A signed-in player deletes exactly their own account; the profile goes
-- with it, the other account stays.
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000a', false);
select public.delete_my_account();
reset role;
do $$
begin
  assert not exists (
    select from auth.users where id = '00000000-0000-0000-0000-00000000000a'
  ), 'caller not deleted';
  assert not exists (
    select from public.profiles where id = '00000000-0000-0000-0000-00000000000a'
  ), 'profile not deleted by cascade';
  assert exists (
    select from auth.users where id = '00000000-0000-0000-0000-00000000000b'
  ), 'another account was deleted';
end;
$$;

-- No JWT subject: refused with the "not signed in" error.
set role authenticated;
select set_config('request.jwt.claim.sub', '', false);
do $$
begin
  begin
    perform public.delete_my_account();
    raise exception 'deleted without a caller';
  exception when sqlstate '28000' then
    null;
  end;
end;
$$;
reset role;
