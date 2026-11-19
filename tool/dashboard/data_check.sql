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
  else 'Complete: every uploaded answer has all six.'
end as verdict;

\echo
\echo '== Not stored at all (no query can find these; decide before Phase 3b)'
\echo '   - Input device (on-screen keypad or physical keyboard): desktop typing is'
\echo '     faster, so t_rapide per operation would mix both. Needs a session field.'
\echo '   - App version per session: the build of each game, to set aside a buggy one.'
\echo '     Only feedback carries it today.'
\echo '   - The question timeout in force: a constant 15 s today. Must be stored with'
\echo '     the session once Phase 3b derives it from the level.'
