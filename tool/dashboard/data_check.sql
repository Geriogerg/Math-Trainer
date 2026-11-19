-- Phase 3a commit 8: does every uploaded answer carry what Phase 3b's
-- calibration needs? `bash tool/dashboard/dashboard.sh data-check`.
-- Read-only.

\pset footer off
\pset null '—'

\echo
\echo '== What Phase 3b needs, per uploaded answer'
select requirement, checked, failing, example_session
from owner_dashboard.data_check;

\echo
select case
  when not exists (select from owner_dashboard.data_check where checked > 0)
    then 'No answer uploaded yet: nothing to check.'
  when exists (select from owner_dashboard.data_check where failing > 0)
    then 'GAPS: see the failing rows above (example_session: one upload to inspect).'
  else 'Complete: every uploaded answer has all eight.'
end as verdict;

\echo
\echo '   Games uploaded before 20 Nov 2026 have no input device or app version:'
\echo '   those two rows count them as failing.'

\echo
\echo '== Not stored at all (no query can find it)'
\echo '   - The question timeout in force: a constant 15 s today. Must be stored with'
\echo '     the session once Phase 3b derives it from the level.'
