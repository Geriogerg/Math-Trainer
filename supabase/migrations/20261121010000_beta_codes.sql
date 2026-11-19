-- Beta gate (Phase 3a commit 3, plan v2.3): an invitation code is asked
-- once, before the anonymous sign-in. Codes live here, one per tester or
-- group, each with a use limit, so every tester's data can be followed
-- (`beta_code_uses`: which player came in with which code).
--
-- Not exposed to the API: players only reach the two functions below.
-- Codes are created by the owner (`create_beta_code`, from the dashboard
-- script — never in a migration: the repository is public).
-- Idempotent: CI applies every migration twice in its SQL tests.

create table if not exists public.beta_codes (
  -- Upper-case letters and digits only (spaces and dashes are stripped
  -- before any lookup: `normalize_beta_code`).
  code text primary key check (code ~ '^[A-Z0-9]{4,32}$'),
  -- Who it is for ("Alice", "Chess club"): what the dashboard shows.
  label text not null check (char_length(label) between 1 and 80),
  max_uses integer not null check (max_uses > 0),
  disabled boolean not null default false,
  created_at timestamptz not null default now()
);

-- One row per player who came in with a code. A deleted account frees its
-- use (cascade): uses are counted, not stored.
create table if not exists public.beta_code_uses (
  player_id uuid primary key references auth.users (id) on delete cascade,
  code text not null references public.beta_codes (code),
  redeemed_at timestamptz not null default now()
);
create index if not exists beta_code_uses_code on public.beta_code_uses (code);

alter table public.beta_codes enable row level security;
alter table public.beta_code_uses enable row level security;
revoke all on public.beta_codes, public.beta_code_uses from anon, authenticated;

create or replace function public.normalize_beta_code(p_code text)
returns text
language sql
immutable
set search_path = ''
as $$
  select upper(regexp_replace(coalesce(p_code, ''), '[\s-]', '', 'g'));
$$;

-- What the gate screen asks before creating the guest: 'ok', 'unknown',
-- 'full' or 'disabled'. Callable without a session (there is none yet).
create or replace function public.beta_code_status(p_code text)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  c public.beta_codes;
begin
  select * into c from public.beta_codes
  where code = public.normalize_beta_code(p_code);
  if not found then
    return 'unknown';
  elsif c.disabled then
    return 'disabled';
  elsif (select count(*) from public.beta_code_uses u where u.code = c.code)
        >= c.max_uses then
    return 'full';
  end if;
  return 'ok';
end;
$$;

-- Ties the caller (the new guest) to the code: 'redeemed', 'already' (this
-- player has a code: nothing changes), 'unknown', 'full' or 'disabled'. The
-- row lock makes two players racing for the last use safe.
create or replace function public.redeem_beta_code(p_code text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller uuid := auth.uid();
  c public.beta_codes;
begin
  if caller is null then
    raise exception 'not signed in' using errcode = '28000';
  end if;
  if exists (select from public.beta_code_uses where player_id = caller) then
    return 'already';
  end if;
  select * into c from public.beta_codes
  where code = public.normalize_beta_code(p_code)
  for update;
  if not found then
    return 'unknown';
  elsif c.disabled then
    return 'disabled';
  elsif (select count(*) from public.beta_code_uses u where u.code = c.code)
        >= c.max_uses then
    return 'full';
  end if;
  insert into public.beta_code_uses (player_id, code) values (caller, c.code);
  return 'redeemed';
end;
$$;

-- For the owner (dashboard script, as the database owner): a new random
-- code of 8 characters from 32 easy-to-read ones (no I, O, 0, 1), returned
-- once. 40 random bits, from bytes of a version-4 UUID that carry no version
-- or variant bits — no extension needed.
create or replace function public.create_beta_code(p_label text, p_max_uses integer)
returns text
language plpgsql
set search_path = ''
as $$
declare
  alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  bytes bytea;
  new_code text;
  i integer;
begin
  loop
    bytes := uuid_send(gen_random_uuid());
    new_code := '';
    foreach i in array array[0, 1, 2, 3, 4, 5, 10, 11] loop
      new_code := new_code || substr(alphabet, get_byte(bytes, i) % 32 + 1, 1);
    end loop;
    exit when not exists (select from public.beta_codes where code = new_code);
  end loop;
  insert into public.beta_codes (code, label, max_uses)
  values (new_code, p_label, p_max_uses);
  return new_code;
end;
$$;

revoke all on function public.normalize_beta_code(text) from public;
revoke all on function public.beta_code_status(text) from public;
revoke all on function public.redeem_beta_code(text) from public, anon;
revoke all on function public.create_beta_code(text, integer) from public, anon, authenticated;
grant execute on function public.normalize_beta_code(text) to anon, authenticated;
grant execute on function public.beta_code_status(text) to anon, authenticated;
grant execute on function public.redeem_beta_code(text) to authenticated;
