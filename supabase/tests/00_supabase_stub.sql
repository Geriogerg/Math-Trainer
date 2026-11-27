-- A plain-Postgres stand-in for the parts of a Supabase project the
-- migrations rely on: the API roles, the `auth` schema with `auth.users`,
-- `auth.uid()`, and Supabase's default grants on `public`. Applied before
-- the migrations by `tool/sql/test_sql.sh`, locally and in CI — never to
-- the real project.

do $$
begin
  if not exists (select from pg_roles where rolname = 'anon') then
    create role anon nologin noinherit;
  end if;
  if not exists (select from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin noinherit;
  end if;
  if not exists (select from pg_roles where rolname = 'service_role') then
    -- Supabase's service role bypasses row-level security.
    create role service_role nologin noinherit bypassrls;
  end if;
end;
$$;

create schema if not exists auth;

create table if not exists auth.users (
  id uuid primary key,
  email text,
  is_anonymous boolean not null default false,
  created_at timestamptz not null default now()
);
-- When the email was confirmed (Phase 6c commit 3: a saved account is one
-- not anonymous with its email confirmed). Real Supabase leaves it null
-- until then; here it defaults to the insert's time, so the tests' saved
-- players are confirmed unless a test says otherwise.
alter table auth.users add column if not exists email_confirmed_at timestamptz default now();

-- A user's sign-in sessions: refreshed (updated_at, refreshed_at) each time
-- the app renews its token — the cleanup reads them as activity. The real
-- table has more columns; refreshed_at is without time zone there too.
create table if not exists auth.sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  refreshed_at timestamp
);

-- Supabase's definition: the caller's id from the request's JWT claims.
create or replace function auth.uid() returns uuid
language sql stable
as $$
  select coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')
  )::uuid
$$;

grant usage on schema auth to anon, authenticated, service_role;
grant execute on function auth.uid() to anon, authenticated, service_role;

-- Projects created before late 2026 grant the API roles everything on new
-- tables in `public` by default; newer ones (staging) grant nothing. The
-- stub models the newer kind: a migration grants each table it needs
-- explicitly, which works on both (staging, 24 Nov 2026: the server's
-- functions denied on `uploaded_sessions`). Functions keep the default.
grant usage on schema public to anon, authenticated, service_role;
alter default privileges in schema public
  grant execute on functions to anon, authenticated, service_role;

-- What the CLI keeps its migration history in (`supabase db push`): a
-- migration must not depend on it, but it exists in the real project.
create schema if not exists supabase_migrations;

-- The boards are cached for a minute in production (Phase 6a commit 5);
-- here every read recomputes, so each test step sees its own data. The
-- cache itself is tested with the setting back to 60 s
-- (99k_capacity_test.sql).
do $$
begin
  execute format('alter database %I set mt.board_cache_seconds = %L', current_database(), '0');
end;
$$;
