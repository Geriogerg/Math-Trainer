-- Owner dashboard (Phase 3a commit 6): the views count what they say, the
-- API roles cannot reach them, and a name review shows or clears a name.

-- The views count everything in the database: start from no player at all
-- (a scratch database; the earlier test files' players cascade away).
delete from auth.users;

insert into auth.users (id, is_anonymous) values
  ('00000000-0000-0000-0000-0000000000d1', false),
  ('00000000-0000-0000-0000-0000000000d2', false),
  ('00000000-0000-0000-0000-0000000000d3', false),
  ('00000000-0000-0000-0000-0000000000d4', false),
  ('00000000-0000-0000-0000-0000000000d5', false);
insert into public.profiles (id, display_name) values
  ('00000000-0000-0000-0000-0000000000d1', 'Dana'),
  ('00000000-0000-0000-0000-0000000000d2', 'Rudename');

-- d1 came in with a code; d2 without.
insert into public.beta_codes (code, label, max_uses) values ('DASHTEST', 'Dana', 2);
insert into public.beta_code_uses (player_id, code)
  values ('00000000-0000-0000-0000-0000000000d1', 'DASHTEST');

-- Three games for d1 (one interrupted), one for d2, one placement for d2,
-- each written the way the server writes them.
set role service_role;
do $$
declare
  r record;
  ver integer := 0;
  payload jsonb;
  i integer;
begin
  for i in 1..3 loop
    payload := jsonb_build_object(
      'session', jsonb_build_object('levels', jsonb_build_object('addition', 1250, 'division', 300)),
      'answers', jsonb_build_array(
        jsonb_build_object('operationType', 'addition', 'elapsedMs', 1000 * i, 'isCorrect', true),
        jsonb_build_object('operationType', 'division', 'elapsedMs', 4000, 'isCorrect', i <> 2)
      ));
    select * into r from public.apply_validated_session(
      ('90000000-0000-0000-0000-00000000000' || i)::uuid,
      '00000000-0000-0000-0000-0000000000d1', ver,
      now() - interval '1 hour' * i, 'game', i <> 3, payload, '{}', array[]::text[]);
    assert r.outcome = 'applied', 'd1 game ' || i || ': ' || r.outcome;
    ver := ver + 1;
  end loop;
  select * into r from public.apply_validated_session(
    '90000000-0000-0000-0000-000000000004',
    '00000000-0000-0000-0000-0000000000d2', 0, now() - interval '2 hours', 'placementV2', true,
    '{"session": {"levels": {"addition": 3500}}, "answers": [{"operationType": "addition", "elapsedMs": 99999, "isCorrect": true}]}',
    '{}', array[]::text[]);
  assert r.outcome = 'applied', 'placement';
  select * into r from public.apply_validated_session(
    '90000000-0000-0000-0000-000000000005',
    '00000000-0000-0000-0000-0000000000d2', 1, now() - interval '40 days', 'game', true,
    '{"session": {"levels": {"addition": 100}}, "answers": [{"operationType": "addition", "elapsedMs": 2000, "isCorrect": false}]}',
    '{}', array['implausiblyFast']);
  assert r.outcome = 'applied', 'old game';
  perform public.record_rejected_upload(
    '90000000-0000-0000-0000-000000000006',
    '00000000-0000-0000-0000-0000000000d2', 'levelsMismatch', 'x', '{}');
end;
$$;
reset role;

-- Rudename reported by three players: hidden, and in the review queue.
insert into public.name_reports (reporter_id, reported_id, reported_name) values
  ('00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000d2', 'Rudename'),
  ('00000000-0000-0000-0000-0000000000d3', '00000000-0000-0000-0000-0000000000d2', 'Rudename'),
  ('00000000-0000-0000-0000-0000000000d4', '00000000-0000-0000-0000-0000000000d2', 'Rudename');
insert into public.feedback (player_id, message, app_version)
  values ('00000000-0000-0000-0000-0000000000d1', 'Division is slow', 'abc1234');

do $$
declare
  r record;
begin
  select * into r from owner_dashboard.active_testers;
  assert r.last_day = 2 and r.ever = 2, 'active testers: ' || row_to_json(r)::text;

  -- Games only: the placement's 99,999 ms answer is not counted.
  select * into r from owner_dashboard.answer_times_by_input
    where operation = 'addition' and level_band = '10–19' and input = '(unknown)';
  assert r.answers = 3, 'addition answers: ' || row_to_json(r)::text;
  assert r.median_ms = 2000, 'addition median: ' || r.median_ms;
  assert r.percent_right = 100.0, 'addition right';
  select * into r from owner_dashboard.answer_times_by_input
    where operation = 'division' and level_band = '1–9' and input = '(unknown)';
  assert r.answers = 3 and r.percent_right = 66.7, 'division: ' || row_to_json(r)::text;
  assert not exists (select from owner_dashboard.answer_times_by_input where median_ms > 50000),
    'a placement answer leaked into the times';

  select * into r from owner_dashboard.abandonment where period = '7 days';
  assert r.games = 3 and r.interrupted = 1 and r.percent_interrupted = 33.3,
    'abandonment: ' || row_to_json(r)::text;
  select * into r from owner_dashboard.abandonment where period = '30 days';
  assert r.games = 3, 'the 40-day-old game is outside 30 days';

  select * into r from owner_dashboard.testers_by_code where code = 'Dana [DASHTEST]';
  assert r.players = 1 and r.games_completed = 2, 'by code: ' || row_to_json(r)::text;
  select * into r from owner_dashboard.testers_by_code where code = '(no code)';
  assert r.players = 1 and r.games_completed = 1, 'no code: ' || row_to_json(r)::text;
  assert (select uses from owner_dashboard.codes where code = 'DASHTEST') = 1, 'code uses';

  assert (select uploads from owner_dashboard.refusals where reason = 'levelsMismatch') = 1,
    'refusals';
  -- Dated when the server raised it (now), whatever the session's own date.
  assert (select sessions from owner_dashboard.flags where flag = 'implausiblyFast') = 1,
    'flags';

  select * into r from owner_dashboard.calibration_readiness;
  assert r.completed_games = 3 and r.testers = 2 and not r.ready, 'readiness';

  assert (select count(*) from owner_dashboard.recent_feedback) = 1, 'feedback';

  select * into r from owner_dashboard.names_to_review;
  assert r.display_name = 'Rudename' and r.reports = 3 and r.hidden, 'review queue';
  assert public.public_display_name('00000000-0000-0000-0000-0000000000d2') is null,
    'reported name shown';

  -- Approved: shown again, out of the queue.
  assert owner_dashboard.review_name('00000000-0000-0000-0000-0000000000d2', 'approve')
    = 'approved: Rudename', 'approve';
  assert public.public_display_name('00000000-0000-0000-0000-0000000000d2') = 'Rudename',
    'approved name hidden';
  assert not exists (select from owner_dashboard.names_to_review), 'approved still queued';

  -- Cleared: no name until the player picks one.
  assert owner_dashboard.review_name('00000000-0000-0000-0000-0000000000d2', 'clear')
    = 'cleared: Rudename', 'clear';
  assert (select display_name from public.profiles
    where id = '00000000-0000-0000-0000-0000000000d2') is null, 'name kept';
  assert owner_dashboard.review_name('00000000-0000-0000-0000-0000000000d5', 'approve')
    = 'no name', 'no name';
end;
$$;

-- Nothing of it for the API roles.
set role anon;
do $$
begin
  perform 1 from owner_dashboard.active_testers;
  assert false, 'anon read the dashboard';
exception when insufficient_privilege then null;
end;
$$;
reset role;
set role authenticated;
do $$
begin
  perform owner_dashboard.review_name('00000000-0000-0000-0000-0000000000d1', 'clear');
  assert false, 'a player reviewed a name';
exception when insufficient_privilege then null;
end;
$$;
reset role;
