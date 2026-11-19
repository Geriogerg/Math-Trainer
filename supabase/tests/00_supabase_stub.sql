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

-- Supabase grants the API roles everything on `public` by default; row-level
-- security and explicit revokes are what restrict them.
grant usage on schema public to anon, authenticated, service_role;
alter default privileges in schema public
  grant all on tables to anon, authenticated, service_role;
alter default privileges in schema public
  grant all on sequences to anon, authenticated, service_role;
alter default privileges in schema public
  grant execute on functions to anon, authenticated, service_role;

-- What the CLI keeps its migration history in (`supabase db push`): a
-- migration must not depend on it, but it exists in the real project.
create schema if not exists supabase_migrations;
