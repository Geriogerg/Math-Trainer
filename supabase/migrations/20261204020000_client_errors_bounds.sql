-- Phase 6c commit 6: the capacity report's correction of commit 5. At 2,000
-- reports a day kept 30 days, a flood of the longest reports (about 5 KB
-- each) could hold some 300 MB — most of the free plan's 500 MB. Now 500 a
-- day for 14 days: at most about 38 MB, still far more than a broken
-- release sends.
create or replace function public.client_errors_per_day() returns integer
language sql immutable set search_path = '' as $$ select 500 $$;

create or replace function public.client_errors_kept() returns interval
language sql immutable set search_path = '' as $$ select interval '14 days' $$;
