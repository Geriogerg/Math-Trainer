-- Integrals (Redesign phase commit 4): a new operation, with its own level
-- and its own board. The server already stores whatever levels its replay
-- produces; these are the lists that name every operation.

-- The server's level cache accepts the new type.
alter table public.server_levels
  drop constraint if exists server_levels_exercise_type_check;
alter table public.server_levels
  add constraint server_levels_exercise_type_check check (exercise_type in (
    'addition', 'subtraction', 'multiplication', 'division',
    'power', 'squareRoot', 'percentage', 'integral'
  ));

-- Its board.
create or replace function public.leaderboard_check_board(p_board text)
returns void
language plpgsql
immutable
set search_path = ''
as $$
begin
  if p_board not in ('overall', 'addition', 'subtraction', 'multiplication',
      'division', 'power', 'squareRoot', 'percentage', 'integral') then
    raise exception 'unknown board %', p_board using errcode = '22023';
  end if;
end;
$$;

-- Structural features: an integral's operands are its bounds (what is
-- raised to powers), like math_core's structuralFeatures.
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
    when 'integral' then array[(p_operands ->> 'lower')::int, (p_operands ->> 'upper')::int]
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

revoke all on function owner_dashboard.structural_features(text, jsonb) from public, anon, authenticated;

-- The data check knows the new operation and its operands (same view
-- columns as before).
create or replace view owner_dashboard.data_check as
with answers as (
  select
    s.id as session_id,
    s.kind,
    s.payload -> 'session' as session,
    a
  from public.uploaded_sessions s
  cross join lateral jsonb_array_elements(s.payload -> 'answers') a
),
checks as (
  select
    session_id,
    kind,
    -- Operation: one of the seven, as the boards name them.
    (a ->> 'operationType') in ('addition', 'subtraction', 'multiplication',
      'division', 'power', 'squareRoot', 'percentage', 'integral') as operation_ok,
    -- Level at the time of the answer: a game froze one per operation; a
    -- placement's moves with its staircase, replayable from its seed, its
    -- rotation and the answers before.
    case
      -- (Casts only behind a `case`: SQL may evaluate either side of an
      -- `and` first.)
      when kind = 'game' then
        case when jsonb_typeof(session -> 'levels' -> (a ->> 'operationType')) = 'number'
          then (session -> 'levels' ->> (a ->> 'operationType'))::numeric between 100 and 10000
          else false end
      else
        jsonb_typeof(session -> 'seed') = 'number'
        and case when jsonb_typeof(session -> 'typeSequence') = 'array'
              and jsonb_typeof(session -> 'exerciseCount') = 'number'
          then jsonb_array_length(session -> 'typeSequence') = (session ->> 'exerciseCount')::numeric
          else false end
    end as level_ok,
    -- Time: milliseconds, within the 30 s a question lasts (15 s before
    -- the Redesign phase).
    case when jsonb_typeof(a -> 'elapsedMs') = 'number'
      then (a ->> 'elapsedMs')::numeric between 0 and 30000
      else false end as time_ok,
    -- Correctness, and what was typed (-1: the question timed out).
    jsonb_typeof(a -> 'isCorrect') = 'boolean'
      and jsonb_typeof(a -> 'submittedValue') = 'number' as correctness_ok,
    -- Structure: the operands each operation is generated from, integers.
    jsonb_typeof(a -> 'operands') = 'object'
      and case a ->> 'operationType'
        when 'power' then a -> 'operands' ?& array['base', 'exponent']
        when 'squareRoot' then a -> 'operands' ? 'radicand'
        when 'percentage' then a -> 'operands' ?& array['percent', 'base']
        when 'integral' then a -> 'operands' ?& array['lower', 'upper', 'c0', 'c1', 'c2', 'c3']
        else a -> 'operands' ?& array['operandA', 'operandB']
      end
      and not exists (
        select from jsonb_each(a -> 'operands') o
        where case when jsonb_typeof(o.value) = 'number'
          then (o.value #>> '{}')::numeric <> trunc((o.value #>> '{}')::numeric)
          else true end
      ) as structure_ok,
    -- When it was answered (pace within a session, time of day).
    (a ->> 'answeredAt') ~ '^\d{4}-\d\d-\d\dT' as answered_at_ok,
    -- How it was typed; none only for a timeout with no key pressed.
    case
      when a ? 'inputDevice' then (a ->> 'inputDevice') in ('keypad', 'keyboard', 'mixed')
      else a ->> 'submittedValue' = '-1'
    end as input_device_ok,
    -- The build that played it.
    coalesce(length(session ->> 'appVersion'), 0) between 1 and 40 as app_version_ok
  from answers
)
select requirement, checked, failing, example_session
from (
  select 1 as ord, 'operation' as requirement, count(*) as checked,
    count(*) filter (where not operation_ok) as failing,
    (array_agg(session_id) filter (where not operation_ok))[1] as example_session
  from checks
  union all
  select 2, 'level at the time of the answer', count(*),
    count(*) filter (where not coalesce(level_ok, false)),
    (array_agg(session_id) filter (where not coalesce(level_ok, false)))[1]
  from checks
  union all
  select 3, 'response time', count(*),
    count(*) filter (where not coalesce(time_ok, false)),
    (array_agg(session_id) filter (where not coalesce(time_ok, false)))[1]
  from checks
  union all
  select 4, 'correctness (and timeouts)', count(*),
    count(*) filter (where not coalesce(correctness_ok, false)),
    (array_agg(session_id) filter (where not coalesce(correctness_ok, false)))[1]
  from checks
  union all
  select 5, 'structure of the exercise (operands)', count(*),
    count(*) filter (where not coalesce(structure_ok, false)),
    (array_agg(session_id) filter (where not coalesce(structure_ok, false)))[1]
  from checks
  union all
  select 6, 'time answered', count(*),
    count(*) filter (where not coalesce(answered_at_ok, false)),
    (array_agg(session_id) filter (where not coalesce(answered_at_ok, false)))[1]
  from checks
  union all
  select 7, 'input device', count(*),
    count(*) filter (where not coalesce(input_device_ok, false)),
    (array_agg(session_id) filter (where not coalesce(input_device_ok, false)))[1]
  from checks
  union all
  select 8, 'app version', count(*),
    count(*) filter (where not coalesce(app_version_ok, false)),
    (array_agg(session_id) filter (where not coalesce(app_version_ok, false)))[1]
  from checks
) r
order by ord;
