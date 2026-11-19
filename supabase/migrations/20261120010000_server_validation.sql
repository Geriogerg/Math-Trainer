-- Server replay and validation (Phase 2 commit 6). The server replays every
-- upload with math_core and only then writes; these tables are its state.
-- Nobody but the service role reads or writes them through the API yet
-- (the leaderboard's read access comes with commit 7).

-- Per player: the time of the last accepted session, whether one was
-- completed, and a version bumped by every accepted session — two uploads
-- validated against the same state cannot both apply (optimistic lock).
create table if not exists public.server_players (
  player_id uuid primary key references auth.users (id) on delete cascade,
  version integer not null default 0,
  last_session_at timestamptz,
  has_completed_session boolean not null default false
);

-- The server's level cache: written only from replayed sessions.
create table if not exists public.server_levels (
  player_id uuid not null references auth.users (id) on delete cascade,
  exercise_type text not null check (exercise_type in (
    'addition', 'subtraction', 'multiplication', 'division',
    'power', 'squareRoot', 'percentage'
  )),
  -- Hundredths, like the app (3742 = level 37.42).
  level integer not null check (level between 100 and 10000),
  sessions_played integer not null check (sessions_played >= 0),
  updated_at timestamptz not null,
  primary key (player_id, exercise_type)
);

-- Refused uploads, kept for review and so a resend gets the same answer.
create table if not exists public.upload_rejections (
  session_id uuid primary key,
  player_id uuid not null references auth.users (id) on delete cascade,
  reason text not null,
  detail text,
  payload jsonb not null,
  received_at timestamptz not null default now()
);

-- Accepted sessions worth a human look (implausible timing: plan 6.4).
create table if not exists public.upload_flags (
  session_id uuid not null references public.uploaded_sessions (id) on delete cascade,
  flag text not null,
  created_at timestamptz not null default now(),
  primary key (session_id, flag)
);

alter table public.uploaded_sessions
  add column if not exists completed boolean not null default false;

alter table public.server_players enable row level security;
alter table public.server_levels enable row level security;
alter table public.upload_rejections enable row level security;
alter table public.upload_flags enable row level security;
revoke all on table public.server_players, public.server_levels,
  public.upload_rejections, public.upload_flags from anon, authenticated;

-- Commit 5's store-without-checking entry point is gone: every write now
-- goes through a validation.
drop function if exists public.record_session_upload(uuid, uuid, timestamptz, text, jsonb);

-- What the server knows of an upload id: 'accepted' or 'rejected' (with its
-- player, time and reason), or no row.
create or replace function public.upload_status(p_session_id uuid)
returns table (state text, player_id uuid, received_at timestamptz, reason text)
language sql
stable
set search_path = ''
as $$
  select 'accepted', s.player_id, s.received_at, null::text
  from public.uploaded_sessions s where s.id = p_session_id
  union all
  select 'rejected', r.player_id, r.received_at, r.reason
  from public.upload_rejections r where r.session_id = p_session_id
$$;

-- The player's server state, as math_core's ServerPlayerState reads it.
create or replace function public.player_server_state(p_player_id uuid)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'version', coalesce(p.version, 0),
    'lastSessionAt', p.last_session_at,
    'hasCompletedSession', coalesce(p.has_completed_session, false),
    'levels', coalesce((
      select jsonb_object_agg(l.exercise_type, jsonb_build_object(
        'level', l.level,
        'sessionsPlayed', l.sessions_played,
        'updatedAt', l.updated_at
      ))
      from public.server_levels l where l.player_id = p_player_id
    ), '{}'::jsonb)
  )
  from (select 1) one
  left join public.server_players p on p.player_id = p_player_id
$$;

-- Applies one validated session, all or nothing: stores it, writes its
-- level updates ({type: {level, sessionsPlayed, updatedAt}}) and flags,
-- bumps the player's version. Outcome 'applied'; 'stale' if the version
-- moved since the server read the state (it re-reads and re-validates);
-- 'duplicate' / 'conflict' if the id is already stored.
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
    has_completed_session = p.has_completed_session or p_completed
  where p.player_id = p_player_id;

  return query select 'applied'::text, stored_at;
end;
$$;

-- Records a refused upload (once per id).
create or replace function public.record_rejected_upload(
  p_session_id uuid,
  p_player_id uuid,
  p_reason text,
  p_detail text,
  p_payload jsonb
)
returns void
language sql
set search_path = ''
as $$
  insert into public.upload_rejections (session_id, player_id, reason, detail, payload)
  values (p_session_id, p_player_id, p_reason, p_detail, p_payload)
  on conflict (session_id) do nothing
$$;

revoke all on function public.upload_status(uuid) from public, anon, authenticated;
revoke all on function public.player_server_state(uuid) from public, anon, authenticated;
revoke all on function public.apply_validated_session(uuid, uuid, integer, timestamptz, text, boolean, jsonb, jsonb, text[])
  from public, anon, authenticated;
revoke all on function public.record_rejected_upload(uuid, uuid, text, text, jsonb)
  from public, anon, authenticated;
grant execute on function public.upload_status(uuid) to service_role;
grant execute on function public.player_server_state(uuid) to service_role;
grant execute on function public.apply_validated_session(uuid, uuid, integer, timestamptz, text, boolean, jsonb, jsonb, text[])
  to service_role;
grant execute on function public.record_rejected_upload(uuid, uuid, text, text, jsonb)
  to service_role;
