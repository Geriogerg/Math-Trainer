-- Input device per answer and app version per session (owner decision after
-- Phase 3a): stored in the upload's payload by the app (schema v8) — no new
-- column, the server keeps the payload as validated. Here the dashboard
-- reads them: answer times split by input device, games per build, and two
-- more data-check requirements. Idempotent, and safe after the earlier
-- migrations are applied again (tests): no view they define changes shape.

-- Answer times per operation, level band and input device: a physical
-- keyboard is faster than the on-screen keypad, so Phase 3b's targets are
-- read per device. "(unknown)": uploaded before the field, or a timeout
-- with no key pressed. Games only, as `answer_times` was — which this
-- replaces: a view under a new name, because the migrations are applied
-- twice in tests and an older `create or replace` cannot drop columns.
create or replace view owner_dashboard.answer_times_by_input as
with banded as (
  select
    a ->> 'operationType' as operation,
    greatest(1, ((s.payload #>> array['session', 'levels', a ->> 'operationType'])::int / 1000) * 10) as band_start,
    coalesce(a ->> 'inputDevice', '(unknown)') as input,
    (a ->> 'elapsedMs')::int as elapsed_ms,
    (a ->> 'isCorrect')::boolean as is_correct
  from public.uploaded_sessions s
  cross join lateral jsonb_array_elements(s.payload -> 'answers') a
  where s.kind = 'game'
    and s.payload #> array['session', 'levels', a ->> 'operationType'] is not null
)
select
  operation,
  case when band_start = 1 then '1–9' else band_start || '–' || (band_start + 9) end as level_band,
  input,
  count(*) as answers,
  round(100.0 * avg(is_correct::int), 1) as percent_right,
  percentile_cont(0.5) within group (order by elapsed_ms)::int as median_ms,
  percentile_cont(0.25) within group (order by elapsed_ms)::int as p25_ms,
  percentile_cont(0.75) within group (order by elapsed_ms)::int as p75_ms
from banded
group by operation, band_start, input
order by operation, band_start, input;

drop view if exists owner_dashboard.answer_times;

-- Games per build: to set aside the games of a faulty one.
create or replace view owner_dashboard.app_versions as
select
  coalesce(payload #>> '{session,appVersion}', '(unknown)') as app_version,
  count(*) filter (where kind = 'game') as games,
  count(*) filter (where kind <> 'game') as placements,
  count(distinct player_id) as players,
  min(created_at) as first_at,
  max(created_at) as last_at
from public.uploaded_sessions
group by 1
order by last_at desc;

-- The data check, now eight requirements: the six of Phase 3a commit 8,
-- then the input device (a timeout with no key pressed has none, and is
-- complete without it) and the app version.
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
      'division', 'power', 'squareRoot', 'percentage') as operation_ok,
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
    -- Time: milliseconds, within the 15 s a question lasts.
    case when jsonb_typeof(a -> 'elapsedMs') = 'number'
      then (a ->> 'elapsedMs')::numeric between 0 and 15000
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

revoke all on all tables in schema owner_dashboard from public, anon, authenticated;
