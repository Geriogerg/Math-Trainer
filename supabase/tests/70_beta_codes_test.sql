-- Beta gate (Phase 3a commit 3): codes checked before the guest exists,
-- redeemed once per player, within their use limit; nothing exposed.

insert into auth.users (id, is_anonymous) values
  ('00000000-0000-0000-0000-0000000000f1', true),
  ('00000000-0000-0000-0000-0000000000f2', true),
  ('00000000-0000-0000-0000-0000000000f3', true);

-- The owner creates codes (as the database owner).
create temporary table test_codes (name text primary key, code text);
insert into test_codes values
  ('solo', public.create_beta_code('Alice', 1)),
  ('club', public.create_beta_code('Chess club', 5));
insert into test_codes
  select 'off', public.create_beta_code('Old', 3);
update public.beta_codes set disabled = true
  where code = (select code from test_codes where name = 'off');
grant select on test_codes to anon, authenticated;

do $$
declare
  c text;
begin
  for c in select code from test_codes loop
    assert c ~ '^[A-HJ-NP-Z2-9]{8}$', 'code shape: ' || c;
  end loop;
  assert public.normalize_beta_code(' ab-cd ef ') = 'ABCDEF', 'normalize';
end;
$$;

-- Before any session: the gate screen's check.
set role anon;
do $$
declare
  solo text := (select code from test_codes where name = 'solo');
begin
  assert public.beta_code_status(solo) = 'ok', 'solo ok';
  -- Typed in lower case with a dash and spaces: same code.
  assert public.beta_code_status(lower(substr(solo, 1, 4)) || '- ' || lower(substr(solo, 5))) = 'ok',
    'normalized lookup';
  assert public.beta_code_status('NOPE2345') = 'unknown', 'unknown';
  assert public.beta_code_status((select code from test_codes where name = 'off')) = 'disabled',
    'disabled';
  begin
    perform public.redeem_beta_code(solo);
    assert false, 'anon redeemed';
  exception when insufficient_privilege then null;
  end;
  begin
    perform 1 from public.beta_codes;
    assert false, 'anon read beta_codes';
  exception when insufficient_privilege then null;
  end;
end;
$$;
reset role;

-- Guests redeem.
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000f1', false);
do $$
begin
  assert public.redeem_beta_code((select code from test_codes where name = 'solo')) = 'redeemed',
    'first redeem';
  -- Asked again (a retry after a lost answer): nothing changes.
  assert public.redeem_beta_code((select code from test_codes where name = 'club')) = 'already',
    'second code for the same player';
  begin
    perform 1 from public.beta_code_uses;
    assert false, 'player read beta_code_uses';
  exception when insufficient_privilege then null;
  end;
end;
$$;

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000f2', false);
do $$
begin
  -- Alice's code had one use.
  assert public.beta_code_status((select code from test_codes where name = 'solo')) = 'full',
    'status full';
  assert public.redeem_beta_code((select code from test_codes where name = 'solo')) = 'full',
    'redeem full';
  assert public.redeem_beta_code('NOPE2345') = 'unknown', 'redeem unknown';
  assert public.redeem_beta_code((select code from test_codes where name = 'off')) = 'disabled',
    'redeem disabled';
  assert public.redeem_beta_code((select code from test_codes where name = 'club')) = 'redeemed',
    'club redeem';
  begin
    perform public.create_beta_code('Mine', 1000);
    assert false, 'a player created a code';
  exception when insufficient_privilege then null;
  end;
end;
$$;
select set_config('request.jwt.claim.sub', '', false);
reset role;

do $$
begin
  assert (select code from public.beta_code_uses
    where player_id = '00000000-0000-0000-0000-0000000000f2')
    = (select code from test_codes where name = 'club'), 'use recorded with its code';
end;
$$;

-- A deleted account frees its use.
delete from auth.users where id = '00000000-0000-0000-0000-0000000000f1';
set role anon;
do $$
begin
  assert public.beta_code_status((select code from test_codes where name = 'solo')) = 'ok',
    'use freed by deletion';
end;
$$;
reset role;
drop table test_codes;
