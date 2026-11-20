-- Structural features (Phase 5.1 commit 3). The cases below are also run
-- against math_core's Dart code: packages/math_core/test/difficulty/
-- structural_features_test.dart reads every `('operation', '{...}', …)`
-- line of this block — keep one case per line, in this shape.
-- Columns: operation, operands, carries, borrows, digits 6-9, round distance.

do $$
declare
  c record;
  f record;
begin
  for c in select * from (values
    ('addition', '{"operandA": 47, "operandB": 38}', 1, 0, 2, 2),
    ('addition', '{"operandA": 45, "operandB": 32}', 0, 0, 0, 2),
    ('addition', '{"operandA": 999, "operandB": 1}', 3, 0, 3, 1),
    ('addition', '{"operandA": 5, "operandB": 3}', 0, 0, 0, null),
    ('addition', '{"operandA": 65, "operandB": 75}', 2, 0, 2, 5),
    ('subtraction', '{"operandA": 52, "operandB": 38}', 0, 1, 1, 2),
    ('subtraction', '{"operandA": 603, "operandB": 298}', 0, 2, 3, 2),
    ('subtraction', '{"operandA": 1000, "operandB": 1}', 0, 3, 0, 0),
    ('subtraction', '{"operandA": 87, "operandB": 42}', 0, 0, 2, 2),
    ('multiplication', '{"operandA": 7, "operandB": 46}', 0, 0, 2, 4),
    ('multiplication', '{"operandA": 0, "operandB": 6}', 0, 0, 1, null),
    ('multiplication', '{"operandA": 47, "operandB": 53}', 0, 0, 1, 3),
    ('division', '{"operandA": 84, "operandB": 7}', 0, 0, 2, 4),
    ('power', '{"base": 48, "exponent": 2}', 0, 0, 1, 2),
    ('power', '{"base": 9, "exponent": 3}', 0, 0, 1, null),
    ('squareRoot', '{"radicand": 1369}', 0, 0, 2, 1),
    ('percentage', '{"percent": 25, "base": 80}', 0, 0, 1, 0),
    ('percentage', '{"percent": 8, "base": 25}', 0, 0, 1, 5)
  ) as t(operation, operands, carries, borrows, big_digits, round_distance) loop
    select * into f from owner_dashboard.structural_features(c.operation, c.operands::jsonb);
    assert f.carries = c.carries and f.borrows = c.borrows
        and f.big_digits = c.big_digits
        and f.round_distance is not distinct from c.round_distance,
      format('%s %s: got %s', c.operation, c.operands, row_to_json(f));
  end loop;

  -- An operation it does not know: nulls, never a guess.
  select * into f from owner_dashboard.structural_features('mystery', '{"operandA": 4}');
  assert f.carries is null and f.big_digits is null and f.round_distance is null,
    'unknown operation';
  -- A malformed answer (an operand missing): nulls too.
  select * into f from owner_dashboard.structural_features('addition', '{"operandA": 4}');
  assert f.carries is null, 'missing operand';
end;
$$;

-- The view: every stored answer, games and placements.
delete from auth.users;
insert into auth.users (id, is_anonymous) values
  ('00000000-0000-0000-0000-0000000000c1', true);

set role service_role;
do $$
declare
  r record;
begin
  select * into r from public.apply_validated_session(
    '96000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-0000000000c1', 0, now() - interval '1 hour', 'game', true,
    '{"session": {"seed": 1, "exerciseCount": 2, "levels": {"addition": 1250, "power": 300},
                  "typeSequence": ["addition", "power"]},
      "answers": [
        {"operationType": "addition", "operands": {"operandA": 47, "operandB": 38},
         "submittedValue": 85, "isCorrect": true, "elapsedMs": 2100, "inputDevice": "keypad",
         "answeredAt": "2026-11-23T10:00:02.100Z"},
        {"operationType": "power", "operands": {"base": 48, "exponent": 2},
         "submittedValue": -1, "isCorrect": false, "elapsedMs": 15000,
         "answeredAt": "2026-11-23T10:00:17.100Z"}]}',
    '{}', array[]::text[]);
  assert r.outcome = 'applied', 'game';
end;
$$;
reset role;

do $$
declare
  n integer;
  r record;
begin
  select count(*) into n from owner_dashboard.answer_features;
  assert n = 2, format('answers with features: %s', n);
  select * into r from owner_dashboard.answer_features where operation = 'addition';
  assert r.carries = 1 and r.big_digits = 2 and r.round_distance = 2
      and r.level_hundredths = 1250 and r.input_device = 'keypad' and r.kind = 'game',
    format('addition row: %s', row_to_json(r));
  select * into r from owner_dashboard.feature_summary
  where operation = 'addition' and feature = 'carries' and value = 1;
  assert r.answers = 1 and r.correct_pct = 100 and r.median_ms_right = 2100,
    format('summary: %s', row_to_json(r));
  select * into r from owner_dashboard.feature_summary
  where operation = 'power' and feature = 'digits 6-9' and value = 1;
  assert r.answers = 1 and r.correct_pct = 0 and r.median_ms_right is null,
    format('summary, a timeout: %s', row_to_json(r));
end;
$$;

-- Never readable by players.
do $$
begin
  assert not has_table_privilege('anon', 'owner_dashboard.answer_features', 'select'), 'anon';
  assert not has_table_privilege('authenticated', 'owner_dashboard.feature_summary', 'select'),
    'authenticated';
  assert not has_function_privilege('authenticated',
    'owner_dashboard.structural_features(text, jsonb)', 'execute'), 'function';
end;
$$;
