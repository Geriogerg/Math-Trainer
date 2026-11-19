-- Cleanup of stale anonymous players (Phase 2 commit 11; plan 6.3: only
-- once the server knows their activity). A guest is deleted — with
-- everything the server holds for them, by cascade — when all of these hold:
--   * the account is anonymous and older than 30 days;
--   * no session uploaded in the last 30 days;
--   * no sign-in session renewed in the last 30 days (the app renews its
--     token whenever it is open: this keeps a guest who plays while the
--     upload server is not deployed, or offline, from being deleted).
-- Returns how many were deleted.
create or replace function public.cleanup_stale_guests()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  deleted integer;
begin
  with stale as (
    select u.id from auth.users u
    where u.is_anonymous
      and u.created_at < now() - interval '30 days'
      and not exists (
        select from public.uploaded_sessions s
        where s.player_id = u.id and s.received_at >= now() - interval '30 days'
      )
      and not exists (
        select from auth.sessions a
        where a.user_id = u.id
          and greatest(
            a.updated_at,
            a.created_at,
            a.refreshed_at at time zone 'UTC'
          ) >= now() - interval '30 days'
      )
  )
  delete from auth.users u using stale where u.id = stale.id;
  get diagnostics deleted = row_count;
  return deleted;
end;
$$;

revoke all on function public.cleanup_stale_guests() from public, anon, authenticated;

-- Daily at 03:17 UTC, where pg_cron exists (Supabase: yes; the plain
-- Postgres of the SQL tests: no — the function is tested directly there).
-- cron.schedule with a job name replaces the job: re-applying is harmless.
-- A failure here (a privilege missing) must not block the other
-- migrations: it warns, and the job can be added from the dashboard.
do $$
begin
  if exists (select from pg_available_extensions where name = 'pg_cron') then
    create extension if not exists pg_cron;
    perform cron.schedule(
      'cleanup-stale-guests',
      '17 3 * * *',
      'select public.cleanup_stale_guests()'
    );
  end if;
exception when others then
  raise warning 'cleanup-stale-guests not scheduled: %', sqlerrm;
end;
$$;
