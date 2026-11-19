-- Player names (Phase 2 commit 9): a filter enforced by the database, and a
-- report action. The rule mirrors math_core's displayNameProblem
-- (packages/math_core/lib/account/display_name.dart); a test there checks
-- this file holds the same character class and word lists.

-- Why a name cannot be saved, or null if it can (null name: none chosen).
create or replace function public.display_name_problem(p_name text)
returns text
language plpgsql
immutable
set search_path = ''
as $$
declare
  lowered text;
  joined text;
  w text;
begin
  if p_name is null then
    return null;
  end if;
  if p_name = '' then
    return 'empty';
  end if;
  if char_length(p_name) > 30 then
    return 'tooLong';
  end if;
  if btrim(p_name) <> p_name or position('  ' in p_name) > 0 then
    return 'spaces';
  end if;
  -- Letters the bundled Inter font draws, digits, space and . _ ' -
  if p_name !~ ('^' || '[A-Za-z0-9À-ÖØ-öø-ňŊ-ſΆΈ-ΊΌΎ-ΡΣ-ώЀ-џẠ-ỹ ._''-]' || '+$') then
    return 'charset';
  end if;
  if p_name !~ '[^ ._''-]' then
    return 'noLetter';
  end if;
  lowered := lower(p_name);
  joined := regexp_replace(lowered, '[ ._''-]+', '', 'g');
  foreach w in array array[
    'nigger', 'nigga', 'faggot', 'retard', 'whore', 'salope', 'connard',
    'connasse', 'encule', 'enculé', 'batard', 'bâtard', 'hitler'
  ] loop
    if position(w in joined) > 0 then
      return 'blocked';
    end if;
  end loop;
  foreach w in array array['fuck', 'shit', 'cunt', 'bitch', 'slut', 'pute'] loop
    if exists (
      select from regexp_split_to_table(lowered, '[ ._''-]+') t
      where left(t, char_length(w)) = w
    ) then
      return 'blocked';
    end if;
  end loop;
  return null;
end;
$$;

-- Enforced on every new or changed name. NOT VALID: names already stored
-- are left as they are (the report action covers them).
do $$
begin
  if not exists (
    select from pg_constraint where conname = 'profiles_display_name_allowed'
  ) then
    alter table public.profiles
      add constraint profiles_display_name_allowed
      check (public.display_name_problem(display_name) is null) not valid;
  end if;
end;
$$;

-- One report per reporter and player, with the name it was about.
create table if not exists public.name_reports (
  reporter_id uuid not null references auth.users (id) on delete cascade,
  reported_id uuid not null references auth.users (id) on delete cascade,
  reported_name text,
  created_at timestamptz not null default now(),
  primary key (reporter_id, reported_id),
  check (reporter_id <> reported_id)
);

alter table public.name_reports enable row level security;
revoke all on table public.name_reports from anon, authenticated;

-- Any signed-in player (guests included) reports another player's name.
-- Repeating it changes nothing.
create or replace function public.report_player_name(p_player_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
begin
  if me is null then
    raise exception 'not signed in' using errcode = '28000';
  end if;
  if me = p_player_id then
    return;
  end if;
  insert into public.name_reports (reporter_id, reported_id, reported_name)
  select me, p_player_id, pr.display_name
  from public.profiles pr
  where pr.id = p_player_id and pr.display_name is not null
  on conflict (reporter_id, reported_id) do nothing;
end;
$$;

revoke all on function public.report_player_name(uuid) from public, anon;
grant execute on function public.report_player_name(uuid) to authenticated;

-- A name reported by 3 different players, as it is now, is hidden on the
-- boards ("Player") until reviewed (provisional, doc/decisions.md).
create or replace function public.public_display_name(p_player_id uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when (
      select count(*) from public.name_reports r
      where r.reported_id = p_player_id and r.reported_name = pr.display_name
    ) >= 3 then null
    else pr.display_name
  end
  from public.profiles pr
  where pr.id = p_player_id
$$;

revoke all on function public.public_display_name(uuid) from public, anon, authenticated;

-- Board entries now carry the player's id (needed to report a name; ids
-- are already public with the names in `profiles`) and the name as shown.
create or replace function public.leaderboard_entry(
  p_player_id uuid, p_rank bigint, p_level integer
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'playerId', p_player_id,
    'rank', p_rank,
    'name', public.public_display_name(p_player_id),
    'level', p_level,
    'isMe', p_player_id is not distinct from auth.uid()
  )
$$;

revoke all on function public.leaderboard_entry(uuid, bigint, integer) from public, anon, authenticated;
