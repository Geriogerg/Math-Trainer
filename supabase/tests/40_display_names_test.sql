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

-- Reports (Phase 6a commit 4): from a saved account only, one per reporter
-- and player; the first one hides the player's name until the owner
-- reviews it — renaming does not bring it back.
insert into auth.users (id, is_anonymous) values
  ('00000000-0000-0000-0000-0000000002a5', true);
do $$
begin
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000002a2', false);
  set local role authenticated;
  perform public.report_player_name('00000000-0000-0000-0000-0000000002a1');
  perform public.report_player_name('00000000-0000-0000-0000-0000000002a1');
  reset role;
  assert (select count(*) from public.name_reports) = 1, 'one report per reporter';
  assert public.public_display_name('00000000-0000-0000-0000-0000000002a1') is null,
    'shown after a report';

  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000002a1', false);
  set local role authenticated;
  perform public.report_player_name('00000000-0000-0000-0000-0000000002a1');
  reset role;
  assert (select count(*) from public.name_reports) = 1, 'reported oneself';

  -- A guest cannot report.
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000002a5', false);
  set local role authenticated;
  begin
    perform public.report_player_name('00000000-0000-0000-0000-0000000002a1');
    raise exception 'a guest reported';
  exception when insufficient_privilege then null;
  end;
  reset role;
  assert (select count(*) from public.name_reports) = 1;

  -- A new spelling stays hidden: the report is about the player.
  update public.profiles set display_name = 'Fresh Start'
  where id = '00000000-0000-0000-0000-0000000002a1';
  assert public.public_display_name('00000000-0000-0000-0000-0000000002a1') is null,
    'renaming brought a reported name back';
  assert (select display_name from owner_dashboard.names_to_review
    where player_id = '00000000-0000-0000-0000-0000000002a1') = 'Fresh Start',
    'the owner reviews the name as it is now';
end;
$$;

-- The owner approves it (a later transaction): shown again.
do $$
begin
  assert owner_dashboard.review_name('00000000-0000-0000-0000-0000000002a1', 'approve')
    = 'approved: Fresh Start';
  assert public.public_display_name('00000000-0000-0000-0000-0000000002a1') = 'Fresh Start';
  assert not exists (select from owner_dashboard.names_to_review);
end;
$$;

-- Reported again after the review: hidden again, back in the queue.
do $$
begin
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000002a2', false);
  set local role authenticated;
  perform public.report_player_name('00000000-0000-0000-0000-0000000002a1');
  reset role;
  assert public.public_display_name('00000000-0000-0000-0000-0000000002a1') is null;
  assert (select reports from owner_dashboard.names_to_review) = 1;
end;
$$;

-- Cleared (a later transaction): the player picks another, shown.
do $$
begin
  assert owner_dashboard.review_name('00000000-0000-0000-0000-0000000002a1', 'clear')
    = 'cleared: Fresh Start';
  update public.profiles set display_name = 'Second Try'
  where id = '00000000-0000-0000-0000-0000000002a1';
  assert public.public_display_name('00000000-0000-0000-0000-0000000002a1') = 'Second Try';
end;
$$;

-- At most 10 reports a day per reporter.
insert into auth.users (id, is_anonymous)
select ('00000000-0000-0000-0000-0000000003' || lpad(i::text, 2, '0'))::uuid, false
from generate_series(1, 11) i;
insert into public.profiles (id, display_name)
select ('00000000-0000-0000-0000-0000000003' || lpad(i::text, 2, '0'))::uuid, 'Rate ' || i
from generate_series(1, 11) i;
do $$
begin
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000002a3', false);
  set local role authenticated;
  for i in 1..10 loop
    perform public.report_player_name(
      ('00000000-0000-0000-0000-0000000003' || lpad(i::text, 2, '0'))::uuid);
  end loop;
  begin
    perform public.report_player_name('00000000-0000-0000-0000-000000000311');
    raise exception 'an 11th report in a day went through';
  exception when program_limit_exceeded then null;
  end;
  reset role;
  assert public.public_display_name('00000000-0000-0000-0000-000000000311') = 'Rate 11';
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
