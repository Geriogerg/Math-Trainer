-- Phase 6b commit 0 (plan v4.0, "Phase 6a outcome"): the close-out of 6a.
--
-- - Names: Greek and Cyrillic letters are allowed again, as before 6a (the
--   owner: "Latin letters only" meant no new alphabets at launch, not fewer).
--   The fold (`fold_display_name`) already covers both scripts, so the unique
--   index is unchanged.
-- - A session's end is its `created_at`: the app stores a game when its last
--   answer is given or when it is left. Phase 6a (commit 3) took
--   `created_at` for its start and stored `created_at` + its answers' times
--   as its end — too late by the whole game, so the next game could be
--   flagged `overlapsPrevious` for nothing. The stored ends are reset to the
--   latest session's `created_at`.
--
-- Every function keeps its signature.

-- The name rule (math_core's displayNameCharClass, the same text:
-- display_name_sql_parity_test.dart reads the newest migration defining it).
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
  -- Latin, modern Greek and basic Cyrillic letters the bundled Inter font
  -- draws, digits, space and . _ ' -
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

create or replace function public.apply_validated_session(
  p_session_id uuid,
  p_player_id uuid,
  p_expected_version integer,
  p_created_at timestamptz,
  p_kind text,
  p_completed boolean,
  p_payload jsonb,
  p_level_updates jsonb,
  p_flags text[]
)
returns table (outcome text, received_at timestamptz)
language plpgsql
set search_path = ''
as $$
declare
  current_version integer;
  existing_player uuid;
  stored_at timestamptz;
begin
  select s.player_id, s.received_at into existing_player, stored_at
  from public.uploaded_sessions s where s.id = p_session_id;
  if found then
    return query select
      case when existing_player = p_player_id then 'duplicate' else 'conflict' end,
      stored_at;
    return;
  end if;
  insert into public.server_players (player_id) values (p_player_id)
  on conflict (player_id) do nothing;
  select p.version into current_version
  from public.server_players p where p.player_id = p_player_id
  for update;
  if current_version <> p_expected_version then
    return query select 'stale'::text, null::timestamptz;
    return;
  end if;
  insert into public.uploaded_sessions
    (id, player_id, created_at, kind, payload, completed)
  values (p_session_id, p_player_id, p_created_at, p_kind, p_payload, p_completed)
  returning uploaded_sessions.received_at into stored_at;
  insert into public.server_levels
    (player_id, exercise_type, level, sessions_played, updated_at)
  select p_player_id, u.key, (u.value ->> 'level')::integer,
    (u.value ->> 'sessionsPlayed')::integer,
    (u.value ->> 'updatedAt')::timestamptz
  from jsonb_each(p_level_updates) u
  on conflict (player_id, exercise_type) do update set
    level = excluded.level,
    sessions_played = excluded.sessions_played,
    updated_at = excluded.updated_at;
  insert into public.upload_flags (session_id, flag)
  select p_session_id, f from unnest(p_flags) f
  on conflict do nothing;
  update public.server_players p set
    version = p.version + 1,
    last_session_at = greatest(p.last_session_at, p_created_at),
    -- A session's created_at is its end (the app stores a game when its
    -- last answer is given or it is left), not its start.
    last_session_ends_at = greatest(p.last_session_ends_at, p_created_at),
    has_completed_session = p.has_completed_session or p_completed,
    completed_games = p.completed_games + case
      when p_completed and p_kind = 'game'
        and coalesce((p_payload -> 'session' ->> 'rulesVersion')::integer, 1) >= 2
      then 1 else 0 end
  where p.player_id = p_player_id;
  return query select 'applied'::text, stored_at;
end;
$$;

update public.server_players p
set last_session_ends_at = p.last_session_at
where p.last_session_ends_at is distinct from p.last_session_at;
