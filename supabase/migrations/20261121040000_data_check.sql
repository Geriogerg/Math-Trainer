-- Data check for Phase 3b (Phase 3a commit 8, plan v2.3): is everything
-- calibration needs stored with every uploaded answer — operation, level,
-- time, correctness, structure of the exercise? One row per requirement:
-- how many answers were checked and how many fail it. Printed by
-- `tool/dashboard/dashboard.sh data-check`. Read by the owner only (the
-- schema is not served by the API). Idempotent.

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
    (a ->> 'answeredAt') ~ '^\d{4}-\d\d-\d\dT' as answered_at_ok
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
) r
order by ord;

revoke all on owner_dashboard.data_check from public, anon, authenticated;
