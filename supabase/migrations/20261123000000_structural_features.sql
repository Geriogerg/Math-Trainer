-- Structural features of every stored answer (Phase 5.1 commit 3, plan
-- v2.6): carries, borrows, digits 6-9, distance from a round number — what
-- Phase 3b checks against answer times and errors. For analysis only:
-- generation never reads them.
--
-- The rules are math_core's `structuralFeatures` (difficulty/
-- structural_features.dart), written again here; the Dart test runs this
-- migration's SQL test cases (supabase/tests/96_structural_features_test.sql)
-- against the Dart code, so the two cannot drift. Change both or neither.
--
-- In owner_dashboard (never served by the API). Idempotent: CI applies
-- every migration twice; the views are new, so `create or replace` holds.

-- Keyed on the answer's operationType alone (it names the family: an
-- addition is arithmetic, `power` is a power…). An operation it does not
-- know gives nulls, never a guess.
create or replace function owner_dashboard.structural_features(
  p_operation text,
  p_operands jsonb,
  out carries integer,
  out borrows integer,
  out big_digits integer,
  out round_distance integer
)
language plpgsql
immutable
set search_path = ''
as $$
declare
  nums integer[];
  a integer;
  b integer;
  x integer;
  d integer;
  carry integer := 0;
  borrow integer := 0;
begin
  nums := case p_operation
    when 'addition' then array[(p_operands ->> 'operandA')::int, (p_operands ->> 'operandB')::int]
    when 'subtraction' then array[(p_operands ->> 'operandA')::int, (p_operands ->> 'operandB')::int]
    when 'multiplication' then array[(p_operands ->> 'operandA')::int, (p_operands ->> 'operandB')::int]
    when 'division' then array[(p_operands ->> 'operandA')::int, (p_operands ->> 'operandB')::int]
    -- The exponent is never counted: always 2 or 3, never computed with.
    when 'power' then array[(p_operands ->> 'base')::int]
    when 'squareRoot' then array[(p_operands ->> 'radicand')::int]
    when 'percentage' then array[(p_operands ->> 'percent')::int, (p_operands ->> 'base')::int]
  end;
  if nums is null or array_position(nums, null) is not null then
    return;
  end if;

  carries := 0;
  borrows := 0;
  big_digits := 0;
  a := abs(nums[1]);
  b := abs(coalesce(nums[2], 0));
  if p_operation = 'addition' then
    -- Column by column from the units, the carry going on.
    while a > 0 or b > 0 loop
      carry := case when a % 10 + b % 10 + carry >= 10 then 1 else 0 end;
      carries := carries + carry;
      a := a / 10;
      b := b / 10;
    end loop;
  elsif p_operation = 'subtraction' then
    -- A borrow takes one off the next column.
    while a > 0 or b > 0 loop
      borrow := case when a % 10 - borrow < b % 10 then 1 else 0 end;
      borrows := borrows + borrow;
      a := a / 10;
      b := b / 10;
    end loop;
  end if;

  foreach x in array nums loop
    x := abs(x);
    -- The nearest multiple of ten, for operands of 10 or more.
    if x >= 10 then
      d := least(x % 10, 10 - x % 10);
      round_distance := least(coalesce(round_distance, d), d);
    end if;
    loop
      if x % 10 >= 6 then
        big_digits := big_digits + 1;
      end if;
      x := x / 10;
      exit when x = 0;
    end loop;
  end loop;
end;
$$;

-- Every stored answer, games and placements, with its features. The level
-- is the one a game froze for that operation (null for placements: theirs
-- moves within the session).
create or replace view owner_dashboard.answer_features as
select
  s.id as session_id,
  s.player_id,
  s.created_at as session_at,
  s.kind,
  a ->> 'operationType' as operation,
  case when s.kind = 'game'
    then (s.payload #>> array['session', 'levels', a ->> 'operationType'])::int
  end as level_hundredths,
  (a ->> 'elapsedMs')::int as elapsed_ms,
  (a ->> 'isCorrect')::boolean as is_correct,
  a ->> 'inputDevice' as input_device,
  f.carries,
  f.borrows,
  f.big_digits,
  f.round_distance
from public.uploaded_sessions s
cross join lateral jsonb_array_elements(s.payload -> 'answers') a
cross join lateral owner_dashboard.structural_features(
  a ->> 'operationType', a -> 'operands'
) f;

-- A first look for the owner (`dashboard.sh features`): per operation and
-- per value of each feature, how many answers, how many right, the median
-- time of the right ones. Timeouts (15 s) count as wrong. Values above 3
-- are grouped (rare, and too few to say anything alone).
create or replace view owner_dashboard.feature_summary as
with long as (
  select operation, 'carries' as feature, least(carries, 3) as value, is_correct, elapsed_ms
  from owner_dashboard.answer_features where operation = 'addition'
  union all
  select operation, 'borrows', least(borrows, 3), is_correct, elapsed_ms
  from owner_dashboard.answer_features where operation = 'subtraction'
  union all
  select operation, 'digits 6-9', least(big_digits, 3), is_correct, elapsed_ms
  from owner_dashboard.answer_features where big_digits is not null
  union all
  select operation, 'round distance', round_distance, is_correct, elapsed_ms
  from owner_dashboard.answer_features where round_distance is not null
)
select
  operation,
  feature,
  value,
  count(*) as answers,
  round(100.0 * count(*) filter (where is_correct) / count(*)) as correct_pct,
  percentile_disc(0.5) within group (order by elapsed_ms)
    filter (where is_correct) as median_ms_right
from long
group by operation, feature, value
order by operation, feature, value;

revoke all on all tables in schema owner_dashboard from public, anon, authenticated;
revoke all on function owner_dashboard.structural_features(text, jsonb) from public, anon, authenticated;
