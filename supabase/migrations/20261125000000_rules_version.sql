-- Levels phase commit 0 (doc/levels.md, section 4): every uploaded session
-- carries the rules it was played under. Read from the stored payload, so
-- no write path changes; sessions uploaded before the field existed are
-- rules v1. The boards and the dashboard filter on it from the transition
-- (commit 4) on.
alter table public.uploaded_sessions
  add column if not exists rules_version integer
  generated always as (
    coalesce((payload -> 'session' ->> 'rulesVersion')::integer, 1)
  ) stored;
