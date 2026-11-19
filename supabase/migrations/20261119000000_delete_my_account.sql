-- In-app account deletion — Phase 1, commit 7 (doc/plan.md, section 6.3).
-- Run by hand by the owner in Phase 1; a migration since Phase 2 commit 2.
-- Idempotent: re-applying it replaces the function with the same definition.
--
-- `delete_my_account()` deletes the CALLER's own auth user and nothing else:
-- the only id it ever touches is `auth.uid()`, taken from the caller's JWT,
-- so no argument can point it at another account. It runs as its owner
-- (`security definer`) because `authenticated` cannot write `auth.users`;
-- that is what keeps the service-role key out of the app.
--
-- What goes with the user: `public.profiles` (on delete cascade), and
-- Supabase's own `auth.sessions`, `auth.refresh_tokens`, `auth.identities`
-- (cascades inside the auth schema). Every future table holding a player's
-- server data must reference `auth.users (id) on delete cascade` too.
-- Anonymous users included: they are ordinary rows of `auth.users`.

create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
-- Empty search path: every name below is schema-qualified, so a caller
-- cannot shadow `auth.users` with an object of their own.
set search_path = ''
as $$
declare
  caller uuid := auth.uid();
begin
  if caller is null then
    raise exception 'not signed in' using errcode = '28000';
  end if;
  delete from auth.users where id = caller;
end;
$$;

-- Postgres grants EXECUTE to PUBLIC by default: only signed-in callers
-- (anonymous users carry the `authenticated` role too) may call it.
revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
