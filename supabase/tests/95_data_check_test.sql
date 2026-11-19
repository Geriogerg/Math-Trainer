-- Data check (Phase 3a commit 8, then input device and app version):
-- well-formed answers pass every requirement; each kind of gap is counted
-- under its own. The first three sessions predate the last two fields.

delete from auth.users;
insert into auth.users (id, is_anonymous) values
  ('00000000-0000-0000-0000-0000000000b1', true);

set role service_role;
do $$
declare
  r record;
begin
  -- A well-formed game: two answers, one timed out (-1).
  select * into r from public.apply_validated_session(
    '95000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-0000000000b1', 0, now() - interval '3 hours', 'game', true,
    '{"session": {"seed": 1, "exerciseCount": 2, "levels": {"addition": 1250, "power": 300},
                  "typeSequence": ["addition", "power"]},
      "answers": [
        {"operationType": "addition", "operands": {"operandA": 47, "operandB": 38},
         "submittedValue": 85, "isCorrect": true, "elapsedMs": 2100,
         "answeredAt": "2026-11-21T10:00:02.100Z"},
        {"operationType": "power", "operands": {"base": 7, "exponent": 2},
         "submittedValue": -1, "isCorrect": false, "elapsedMs": 15000,
         "answeredAt": "2026-11-21T10:00:17.100Z"}]}',
    '{}', array[]::text[]);
  assert r.outcome = 'applied', 'good game';
  -- A well-formed type placement: its level is replayable, not stored.
  select * into r from public.apply_validated_session(
    '95000000-0000-0000-0000-000000000002',
    '00000000-0000-0000-0000-0000000000b1', 1, now() - interval '2 hours', 'typePlacementV3', false,
    '{"session": {"seed": 9, "exerciseCount": 5, "levels": {"squareRoot": 3500},
                  "typeSequence": ["squareRoot", "squareRoot", "squareRoot", "squareRoot", "squareRoot"]},
      "answers": [
        {"operationType": "squareRoot", "operands": {"radicand": 1369},
         "submittedValue": 37, "isCorrect": true, "elapsedMs": 2900,
         "answeredAt": "2026-11-21T11:00:03Z"}]}',
    '{}', array[]::text[]);
  assert r.outcome = 'applied', 'good placement';
  -- A broken game, one gap per answer.
  select * into r from public.apply_validated_session(
    '95000000-0000-0000-0000-000000000003',
    '00000000-0000-0000-0000-0000000000b1', 2, now() - interval '1 hour', 'game', true,
    '{"session": {"seed": 2, "exerciseCount": 5, "levels": {"addition": 900},
                  "typeSequence": ["addition", "addition", "addition", "division", "percentage"]},
      "answers": [
        {"operationType": "addition", "operands": {"operandA": "12", "operandB": 3},
         "submittedValue": 15, "isCorrect": true, "elapsedMs": 1000, "answeredAt": "2026-11-21T12:00:01Z"},
        {"operationType": "addition", "operands": {"operandA": 1, "operandB": 2},
         "submittedValue": 3, "isCorrect": true, "elapsedMs": 20000, "answeredAt": "2026-11-21T12:00:21Z"},
        {"operationType": "addition", "operands": {"operandA": 1, "operandB": 2},
         "submittedValue": 3, "elapsedMs": 900, "answeredAt": "2026-11-21T12:00:22Z"},
        {"operationType": "division", "operands": {"operandA": 8, "operandB": 2},
         "submittedValue": 4, "isCorrect": true, "elapsedMs": 900, "answeredAt": "2026-11-21T12:00:23Z"},
        {"operationType": "modulo", "operands": {"percent": 10},
         "submittedValue": 1, "isCorrect": true, "elapsedMs": 900, "answeredAt": "later"}]}',
    '{}', array[]::text[]);
  assert r.outcome = 'applied', 'broken game';
  -- A game from a build that records both: three good answers (a timeout
  -- with no key pressed has no device), one with an unknown device.
  select * into r from public.apply_validated_session(
    '95000000-0000-0000-0000-000000000004',
    '00000000-0000-0000-0000-0000000000b1', 3, now() - interval '30 minutes', 'game', true,
    '{"session": {"seed": 3, "exerciseCount": 4, "levels": {"addition": 1000},
                  "typeSequence": ["addition", "addition", "addition", "addition"],
                  "appVersion": "e9bd019"},
      "answers": [
        {"operationType": "addition", "operands": {"operandA": 1, "operandB": 2},
         "submittedValue": 3, "isCorrect": true, "elapsedMs": 900,
         "answeredAt": "2026-11-21T13:00:01Z", "inputDevice": "keypad"},
        {"operationType": "addition", "operands": {"operandA": 1, "operandB": 2},
         "submittedValue": 3, "isCorrect": true, "elapsedMs": 900,
         "answeredAt": "2026-11-21T13:00:02Z", "inputDevice": "keyboard"},
        {"operationType": "addition", "operands": {"operandA": 1, "operandB": 2},
         "submittedValue": -1, "isCorrect": false, "elapsedMs": 15000,
         "answeredAt": "2026-11-21T13:00:17Z"},
        {"operationType": "addition", "operands": {"operandA": 1, "operandB": 2},
         "submittedValue": 3, "isCorrect": true, "elapsedMs": 900,
         "answeredAt": "2026-11-21T13:00:18Z", "inputDevice": "mouse"}]}',
    '{}', array[]::text[]);
  assert r.outcome = 'applied', 'game with device and version';
end;
$$;
reset role;

do $$
declare
  r record;
begin
  for r in select * from owner_dashboard.data_check loop
    assert r.checked = 12, r.requirement || ' checked ' || r.checked;
    assert r.failing = case r.requirement
      when 'operation' then 1                              -- "modulo"
      when 'level at the time of the answer' then 2         -- division unfrozen, "modulo"
      when 'response time' then 1                           -- 20 s
      when 'correctness (and timeouts)' then 1              -- isCorrect missing
      when 'structure of the exercise (operands)' then 2    -- "12", "modulo"'s
      when 'time answered' then 1                           -- "later"
      -- The 7 answers before the field that are not timeouts, and "mouse".
      when 'input device' then 8
      when 'app version' then 8                             -- sessions 1-3
    end, r.requirement || ': ' || r.failing;
    assert r.failing = 0 or r.example_session = case
        when r.requirement in ('input device', 'app version') then r.example_session
        else '95000000-0000-0000-0000-000000000003'::uuid end,
      r.requirement || ' example';
  end loop;
  assert (select count(*) from owner_dashboard.data_check) = 8, 'eight requirements';

  -- Answer times per input device: session 4's three timed answers.
  select * into r from owner_dashboard.answer_times_by_input
    where operation = 'addition' and level_band = '10–19' and input = 'keypad';
  assert r.answers = 1 and r.median_ms = 900, 'keypad: ' || row_to_json(r)::text;
  select * into r from owner_dashboard.app_versions where app_version = 'e9bd019';
  assert r.games = 1 and r.players = 1, 'app versions: ' || row_to_json(r)::text;
  select * into r from owner_dashboard.app_versions where app_version = '(unknown)';
  assert r.games = 2 and r.placements = 1, 'unknown versions: ' || row_to_json(r)::text;
end;
$$;
