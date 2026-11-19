-- Names (Phase 2 commit 9): the filter in the database, reports, hidden
-- names. The same sample names are checked in Dart
-- (packages/math_core/test/account/display_name_test.dart).

do $$
declare
  c record;
begin
  for c in select * from (values
    ('Ada', null),
    ('Zoé Martin', null),
    ('Nguyễn Văn An', null),
    ('Ελένη', null),
    ('Пётр', null),
    ('O''Brien-2', null),
    ('Marc_Antoine.9', null),
    ('Mitsuko', null),
    ('', 'empty'),
    ('abcdefghijklmnopqrstuvwxyz12345', 'tooLong'),
    (' Ada', 'spaces'),
    ('Ada  Lovelace', 'spaces'),
    ('李雷', 'charset'),
    ('Ada 🙂', 'charset'),
    ('مريم', 'charset'),
    ('-._', 'noLetter'),
    ('Big Fucker', 'blocked'),
    ('s.a.l.o.p.e', 'blocked'),
    ('Shitake', 'blocked'),
    ('Enculé', 'blocked')
  ) as t(name, expected) loop
    assert public.display_name_problem(c.name) is not distinct from c.expected,
      format('%s: %s, expected %s', c.name, public.display_name_problem(c.name), c.expected);
  end loop;
end;
$$;

insert into auth.users (id) values
  ('00000000-0000-0000-0000-0000000002a1'),
  ('00000000-0000-0000-0000-0000000002a2'),
  ('00000000-0000-0000-0000-0000000002a3'),
  ('00000000-0000-0000-0000-0000000002a4');

-- The constraint: a refused name never lands, even written directly.
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000002a1', false);
do $$
begin
  begin
    insert into public.profiles (id, display_name)
      values ('00000000-0000-0000-0000-0000000002a1', '李雷');
    raise exception 'a refused name was saved';
  exception when check_violation then null;
  end;
end;
$$;
insert into public.profiles (id, display_name)
  values ('00000000-0000-0000-0000-0000000002a1', 'Target Name');
reset role;

-- Reports: one per reporter, never on oneself, hidden at three.
do $$
declare
  reporter text;
begin
  foreach reporter in array array[
    '00000000-0000-0000-0000-0000000002a2',
    '00000000-0000-0000-0000-0000000002a3'
  ] loop
    perform set_config('request.jwt.claim.sub', reporter, false);
    set local role authenticated;
    perform public.report_player_name('00000000-0000-0000-0000-0000000002a1');
    perform public.report_player_name('00000000-0000-0000-0000-0000000002a1');
    reset role;
  end loop;
  assert (select count(*) from public.name_reports) = 2, 'one report per reporter';
  assert public.public_display_name('00000000-0000-0000-0000-0000000002a1') = 'Target Name',
    'hidden after two reports';

  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000002a1', false);
  set local role authenticated;
  perform public.report_player_name('00000000-0000-0000-0000-0000000002a1');
  reset role;
  assert (select count(*) from public.name_reports) = 2, 'reported oneself';

  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000002a4', false);
  set local role authenticated;
  perform public.report_player_name('00000000-0000-0000-0000-0000000002a1');
  reset role;
  assert public.public_display_name('00000000-0000-0000-0000-0000000002a1') is null,
    'not hidden after three reports';

  -- A new name starts clean: the reports were about the old one.
  update public.profiles set display_name = 'Fresh Start'
  where id = '00000000-0000-0000-0000-0000000002a1';
  assert public.public_display_name('00000000-0000-0000-0000-0000000002a1') = 'Fresh Start',
    'new name still hidden';
end;
$$;

-- Signed out: no report; players never read the reports.
set role anon;
do $$
begin
  begin
    perform public.report_player_name('00000000-0000-0000-0000-0000000002a1');
    raise exception 'anon reported';
  exception when insufficient_privilege then null;
  end;
end;
$$;
reset role;
set role authenticated;
do $$
begin
  begin
    perform 1 from public.name_reports;
    raise exception 'a player read the reports';
  exception when insufficient_privilege then null;
  end;
end;
$$;
reset role;
