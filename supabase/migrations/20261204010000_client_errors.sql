-- Phase 6c commit 5 (plan v4.1): error reporting to our own server.
--
-- What went wrong in a player's app — an uncaught error, a start that
-- failed, the loading page giving up — sent to the Dart server
-- (`POST /v1/errors`), which masks tokens and email addresses, cuts the
-- text and stores it here through `record_client_error`. Nothing about the
-- player: no account id, no address. Kept 30 days (each insert deletes what
-- is older), at most `client_errors_per_day()` a day in all — a flood of
-- reports can neither fill the database nor push out the real ones for
-- long. Read by the owner only (`dashboard.sh errors`).

create table if not exists public.client_errors (
  id uuid primary key default gen_random_uuid(),
  received_at timestamptz not null default now(),
  kind text not null check (kind in ('flutter', 'zone', 'start', 'loader', 'other')),
  message text not null check (length(message) between 1 and 1000),
  stack text check (length(stack) <= 4000),
  app_version text check (length(app_version) <= 40),
  user_agent text check (length(user_agent) <= 300)
);
create index if not exists client_errors_received on public.client_errors (received_at);

alter table public.client_errors enable row level security;
revoke all on table public.client_errors from anon, authenticated;
grant select, insert, delete on table public.client_errors to service_role;

-- Reports kept over a rolling 24 hours, all players together.
create or replace function public.client_errors_per_day() returns integer
language sql immutable set search_path = '' as $$ select 2000 $$;

-- How long a report is kept.
create or replace function public.client_errors_kept() returns interval
language sql immutable set search_path = '' as $$ select interval '30 days' $$;

-- Stores one report: 'stored', or 'capped' past the day's count (nothing
-- stored). Old reports go first. One at a time: the count cannot be raced.
create or replace function public.record_client_error(
  p_kind text,
  p_message text,
  p_stack text,
  p_app_version text,
  p_user_agent text
)
returns text
language plpgsql
set search_path = ''
as $$
begin
  perform pg_advisory_xact_lock(hashtext('client_errors'));
  delete from public.client_errors
  where received_at < now() - public.client_errors_kept();
  if (
    select count(*) from public.client_errors
    where received_at > now() - interval '24 hours'
  ) >= public.client_errors_per_day() then
    return 'capped';
  end if;
  insert into public.client_errors (kind, message, stack, app_version, user_agent)
  values (
    case when p_kind in ('flutter', 'zone', 'start', 'loader') then p_kind else 'other' end,
    left(p_message, 1000),
    left(p_stack, 4000),
    left(p_app_version, 40),
    left(p_user_agent, 300)
  );
  return 'stored';
end;
$$;

revoke all on function public.client_errors_per_day() from public, anon, authenticated;
revoke all on function public.client_errors_kept() from public, anon, authenticated;
revoke all on function public.record_client_error(text, text, text, text, text)
  from public, anon, authenticated;
grant execute on function public.client_errors_per_day() to service_role;
grant execute on function public.client_errors_kept() to service_role;
grant execute on function public.record_client_error(text, text, text, text, text)
  to service_role;

-- The owner's view: the same message once, with how often, where and when
-- (the last 7 days).
create or replace view owner_dashboard.client_errors as
select kind,
  left(message, 160) as message,
  count(*) as reports,
  count(distinct app_version) as versions,
  max(app_version) as last_version,
  min(received_at) as first_at,
  max(received_at) as last_at
from public.client_errors
where received_at > now() - interval '7 days'
group by kind, left(message, 160)
order by count(*) desc, max(received_at) desc;

revoke all on all tables in schema owner_dashboard from public, anon, authenticated;
