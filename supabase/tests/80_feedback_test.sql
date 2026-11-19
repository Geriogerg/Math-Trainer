-- In-app feedback (Phase 3a commit 5): sent by a signed-in player, stored
-- with the app version, capped per day, unreadable by players, deleted with
-- the account.

insert into auth.users (id, is_anonymous) values
  ('00000000-0000-0000-0000-0000000000a7', true);

set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000a7', false);
do $$
declare
  i integer;
begin
  assert public.send_feedback('  The timer feels short on roots.  ', 'a1b2c3d') = 'sent', 'first';
  begin
    perform public.send_feedback('   ', 'a1b2c3d');
    assert false, 'blank feedback stored';
  exception when check_violation then null;
  end;
  begin
    perform public.send_feedback(repeat('x', 2001), 'a1b2c3d');
    assert false, 'overlong feedback stored';
  exception when check_violation then null;
  end;
  for i in 2..20 loop
    assert public.send_feedback('note ' || i, 'a1b2c3d') = 'sent', 'note ' || i;
  end loop;
  assert public.send_feedback('one too many', 'a1b2c3d') = 'tooMany', 'daily cap';
  begin
    perform 1 from public.feedback;
    assert false, 'a player read feedback';
  exception when insufficient_privilege then null;
  end;
end;
$$;
select set_config('request.jwt.claim.sub', '', false);
reset role;

set role anon;
do $$
begin
  perform public.send_feedback('hello', 'x');
  assert false, 'anon sent feedback';
exception when insufficient_privilege then null;
end;
$$;
reset role;

do $$
begin
  assert (select count(*) from public.feedback
    where player_id = '00000000-0000-0000-0000-0000000000a7') = 20, 'twenty stored';
  assert exists (select from public.feedback
    where message = 'The timer feels short on roots.' and app_version = 'a1b2c3d'),
    'trimmed, with its version';
end;
$$;

delete from auth.users where id = '00000000-0000-0000-0000-0000000000a7';
do $$
begin
  assert not exists (select from public.feedback
    where player_id = '00000000-0000-0000-0000-0000000000a7'), 'kept after deletion';
end;
$$;
