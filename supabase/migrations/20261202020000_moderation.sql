-- Phase 6a commit 3 (plan v3.9; review finding M5): solo integrity and
-- moderation.
--
-- - The server learns when a player's last accepted session ended
--   (`server_players.last_session_ends_at`: its start plus its answers'
--   times) and flags a session created before that.
-- - `player_moderation`: the owner's decision on a player — 'hidden' (off
--   every board, out of the duel pool and of friend search, matched with
--   practice opponents only) or 'banned' (hidden, and the server accepts
--   nothing more from them). The player's Profile says "Account under
--   review" (`my_account_under_review`). Written from the dashboard only.
--
-- Every function keeps its signature (the server deployed before this
-- migration keeps working).

alter table public.server_players add column if not exists last_session_ends_at timestamptz;

-- A session's answering time, from its stored upload.
create or replace function public.upload_played_ms(p_payload jsonb)
returns bigint
language sql
immutable
set search_path = ''
as $$
  select coalesce(sum((a ->> 'elapsedMs')::bigint), 0)
  from jsonb_array_elements(
    case when jsonb_typeof(p_payload -> 'answers') = 'array'
      then p_payload -> 'answers' else '[]'::jsonb end) a
$$;

-- Players who already played: the end of their latest session.
update public.server_players p set last_session_ends_at = (
  select s.created_at + public.upload_played_ms(s.payload) * interval '1 millisecond'
  from public.uploaded_sessions s
  where s.player_id = p.player_id
  order by s.created_at desc
  limit 1
)
where p.last_session_ends_at is null and p.last_session_at is not null;

create table if not exists public.player_moderation (
  player_id uuid primary key references auth.users (id) on delete cascade,
  state text not null check (state in ('hidden', 'banned')),
  reason text not null default '',
  decided_at timestamptz not null default now()
);
alter table public.player_moderation enable row level security;
revoke all on table public.player_moderation from anon, authenticated;
grant select, insert, update, delete on table public.player_moderation to service_role;

-- Whether a player is shown to others: no moderation row.
create or replace function public.player_visible(p_player_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select not exists (
    select from public.player_moderation m where m.player_id = p_player_id
  )
$$;

-- For the caller's own Profile: "Account under review" (hidden or banned;
-- the app is not told which, nor why).
create or replace function public.my_account_under_review()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select from public.player_moderation m where m.player_id = auth.uid()
  )
$$;

-- apply_validated_session, also recording when the session ended.
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
    last_session_ends_at = greatest(p.last_session_ends_at,
      p_created_at + public.upload_played_ms(p_payload) * interval '1 millisecond'),
    has_completed_session = p.has_completed_session or p_completed
  where p.player_id = p_player_id;
  return query select 'applied'::text, stored_at;
end;
$$;

-- player_server_state, with when the last session ended and the owner's
-- decision on the player ('hidden', 'banned' or null).
create or replace function public.player_server_state(p_player_id uuid)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'version', coalesce(p.version, 0),
    'lastSessionAt', p.last_session_at,
    'lastSessionEndsAt', p.last_session_ends_at,
    'hasCompletedSession', coalesce(p.has_completed_session, false),
    'acceptedToday', (
      select count(*) from public.uploaded_sessions s
      where s.player_id = p_player_id and s.received_at > now() - interval '24 hours'
    ),
    'moderation', (
      select m.state from public.player_moderation m where m.player_id = p_player_id
    ),
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

-- The level boards, without the players the owner hid.
create or replace function public.leaderboard_rows(p_board text)
returns table (player_id uuid, level integer, rank bigint, total bigint)
language sql
stable
security definer
set search_path = ''
as $$
  with active as (
    select p.player_id
    from public.server_players p
    join auth.users u on u.id = p.player_id
    where p.last_session_at >= now() - interval '30 days'
      and not u.is_anonymous
      and public.player_visible(p.player_id)
  ),
  board as (
    select l.player_id, l.level
    from public.server_levels l
    join active a on a.player_id = l.player_id
    where p_board <> 'overall'
      and l.exercise_type = p_board
      and l.sessions_played >= public.leaderboard_min_sessions()
    union all
    select a.player_id,
      round(coalesce(sum(l.level), 0) / 4.0)::integer
    from active a
    left join public.server_levels l
      on l.player_id = a.player_id
      and l.exercise_type in ('addition', 'subtraction', 'multiplication', 'division')
    where p_board = 'overall'
      and (select count(*) from public.uploaded_sessions s
           where s.player_id = a.player_id and s.completed and s.kind = 'game'
             and s.rules_version >= 2)
          >= public.leaderboard_min_sessions()
    group by a.player_id
  )
  select b.player_id, b.level,
    rank() over (order by b.level desc),
    count(*) over ()
  from board b
$$;

-- The duel boards likewise.
create or replace function public.duel_board_rows(p_mode text)
returns table (player_id uuid, rating integer, rank bigint, total bigint)
language sql
stable
security definer
set search_path = ''
as $$
  select o.player_id, round(o.rating)::integer,
    rank() over (order by round(o.rating) desc),
    count(*) over ()
  from public.duel_ratings o
  join auth.users u on u.id = o.player_id
  where o.mode = p_mode
    and not u.is_anonymous
    and o.rated_duels >= public.duel_board_min_duels()
    and o.last_rated_at >= now() - interval '30 days'
    and public.player_visible(o.player_id)
$$;

-- duel_take_run: a hidden player's runs are not in the pool, and a hidden
-- caller is given no one's run (the server then makes a practice duel).
create or replace function public.duel_take_run(
  p_player_id uuid,
  p_mode text,
  p_rating double precision,
  p_opponent uuid,
  p_difficulty integer,
  p_duel_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  picked public.duel_runs;
  owner public.duel_ratings;
begin
  if not public.player_visible(p_player_id) then
    return null;
  end if;
  select r.* into picked
  from public.duel_runs r
  join public.duel_ratings o on o.player_id = r.player_id and o.mode = r.mode
  join auth.users u on u.id = r.player_id
  where r.mode = p_mode
    and not u.is_anonymous
    and r.player_id <> p_player_id
    and (p_opponent is null or r.player_id = p_opponent)
    and public.player_visible(r.player_id)
    and r.serves < public.duel_max_serves()
    and ((cardinality(r.flags) = 0 and r.review is distinct from 'rejected')
      or r.review = 'ok')
    and r.id in (
      select x.id from (
        select l.id, row_number() over (
          partition by l.player_id order by l.created_at desc, l.id desc
        ) as n
        from public.duel_runs l where l.mode = p_mode
      ) x where x.n <= public.duel_pool_latest()
    )
    and not exists (
      select from public.duels d
      where d.config = r.config
        and (d.first_player = p_player_id or d.second_player = p_player_id)
    )
  order by
    case when p_opponent is null then abs(o.rating - p_rating)
      else abs((r.config ->> 'difficulty')::integer - coalesce(p_difficulty, 0)) end,
    r.created_at desc,
    r.id
  limit 1
  for update of r skip locked;
  if not found then
    return null;
  end if;

  update public.duel_runs set serves = serves + 1 where id = picked.id;
  insert into public.duels
    (id, mode, kind, config, first_player, second_player, first_run, first_lane, state, chosen)
  values
    (p_duel_id, p_mode, 'pool', picked.config, picked.player_id, p_player_id,
     picked.id, picked.lane, 'awaitingSecond', p_opponent is not null);
  select o.* into owner from public.duel_ratings o
  where o.player_id = picked.player_id and o.mode = p_mode;
  return jsonb_build_object(
    'duelId', p_duel_id,
    'kind', 'pool',
    'config', picked.config,
    'lane', picked.lane,
    'opponent', jsonb_build_object(
      'id', picked.player_id,
      'name', public.public_display_name(picked.player_id),
      'rating', owner.rating,
      'ratedDuels', owner.rated_duels
    )
  );
end;
$$;

-- duel_create_challenge: not from or to a hidden player ('notAllowed', as
-- for a stranger — the challenger is not told the other is under review).
create or replace function public.duel_create_challenge(
  p_duel_id uuid,
  p_mode text,
  p_config jsonb,
  p_challenger uuid,
  p_target uuid
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_challenger = p_target then
    return 'self';
  end if;
  if not exists (select from auth.users u where u.id = p_target and not u.is_anonymous) then
    return 'notLinked';
  end if;
  if not public.player_visible(p_challenger) or not public.player_visible(p_target) then
    return 'notAllowed';
  end if;
  if not exists (
    select from public.friendships f
    where f.player_a = least(p_challenger, p_target)
      and f.player_b = greatest(p_challenger, p_target)
  ) and not exists (
    select from public.duels d
    where d.state = 'done'
      and d.finished_at > now() - public.duel_recent_opponent_window()
      and least(d.first_player, d.second_player) = least(p_challenger, p_target)
      and greatest(d.first_player, d.second_player) = greatest(p_challenger, p_target)
  ) then
    return 'notAllowed';
  end if;
  -- Serialise challenges between the same two players.
  perform pg_advisory_xact_lock(hashtext(least(p_challenger, p_target)::text
    || greatest(p_challenger, p_target)::text || p_mode));
  if exists (
    select from public.duels d
    where d.kind = 'challenge' and d.mode = p_mode
      and d.state in ('awaitingFirst', 'awaitingSecond')
      and (d.opened_at is not null or d.expires_at is null or d.expires_at > now())
      and least(d.first_player, d.second_player) = least(p_challenger, p_target)
      and greatest(d.first_player, d.second_player) = greatest(p_challenger, p_target)
  ) then
    return 'exists';
  end if;
  perform public.duel_insert(p_duel_id, p_mode, 'challenge', p_config, p_challenger,
    p_target, null, now() + interval '7 days' - public.duel_abandon_after());
  return 'created';
end;
$$;

-- duel_player, with the owner's decision on the player.
create or replace function public.duel_player(p_player_id uuid, p_mode text)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', u.id,
    'linked', not u.is_anonymous,
    'name', public.public_display_name(u.id),
    'rating', (
      select jsonb_build_object(
        'rating', o.rating,
        'deviation', o.deviation,
        'volatility', o.volatility,
        'ratedDuels', o.rated_duels,
        'version', o.version
      )
      from public.duel_ratings o where o.player_id = u.id and o.mode = p_mode
    ),
    'duelsToday', (
      select count(*) from public.duels d
      where d.created_at > now() - interval '24 hours'
        and ((d.second_player = u.id and d.kind <> 'challenge')
          or (d.first_player = u.id and d.kind = 'challenge'))
    ),
    'moderation', (
      select m.state from public.player_moderation m where m.player_id = u.id
    ),
    'levels', coalesce((
      select jsonb_object_agg(l.exercise_type, l.level)
      from public.server_levels l where l.player_id = u.id
    ), '{}'::jsonb)
  )
  from auth.users u
  where u.id = p_player_id
$$;

-- friend_request: a hidden player's code finds nobody.
create or replace function public.friend_request(p_code text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := public.friend_caller();
  target uuid;
begin
  if (select count(*) from public.friend_request_attempts a
      where a.player_id = me and a.at > now() - interval '24 hours')
     >= public.friend_daily_requests() then
    return 'tooMany';
  end if;
  insert into public.friend_request_attempts (player_id) values (me);
  select c.player_id into target
  from public.friend_codes c
  join auth.users u on u.id = c.player_id and not u.is_anonymous
  where c.code = public.normalize_friend_code(p_code)
    and public.player_visible(c.player_id);
  if target is null then
    return 'unknown';
  end if;
  if target = me then
    return 'self';
  end if;
  if exists (select from public.friendships f
             where f.player_a = least(me, target) and f.player_b = greatest(me, target)) then
    return 'already';
  end if;
  if exists (select from public.friend_requests r
             where r.from_player = target and r.to_player = me) then
    delete from public.friend_requests r where r.from_player = target and r.to_player = me;
    insert into public.friendships (player_a, player_b)
    values (least(me, target), greatest(me, target))
    on conflict do nothing;
    return 'friends';
  end if;
  insert into public.friend_requests (from_player, to_player) values (me, target)
  on conflict do nothing;
  if not found then
    return 'pending';
  end if;
  return 'sent';
end;
$$;

-- The owner's side (the dashboard connects as the database owner).

-- Hides or bans a player, or changes the decision; false if no such player.
create or replace function owner_dashboard.moderate(p_player_id uuid, p_state text, p_reason text)
returns boolean
language plpgsql
set search_path = ''
as $$
begin
  if p_state not in ('hidden', 'banned') then
    raise exception 'state must be hidden or banned' using errcode = '22023';
  end if;
  if not exists (select from auth.users u where u.id = p_player_id) then
    return false;
  end if;
  insert into public.player_moderation (player_id, state, reason)
  values (p_player_id, p_state, coalesce(p_reason, ''))
  on conflict (player_id) do update set
    state = excluded.state, reason = excluded.reason, decided_at = now();
  return true;
end;
$$;

-- Lifts the decision; false if there was none.
create or replace function owner_dashboard.unmoderate(p_player_id uuid)
returns boolean
language plpgsql
set search_path = ''
as $$
begin
  delete from public.player_moderation where player_id = p_player_id;
  return found;
end;
$$;

-- Who is hidden or banned.
create or replace view owner_dashboard.moderation as
select m.player_id,
  public.public_display_name(m.player_id) as player,
  m.state,
  m.reason,
  m.decided_at
from public.player_moderation m;

-- What the owner decides on, one row per player with anything to look at
-- over the last 30 days: flagged sessions by flag, refused uploads, flagged
-- duel runs, forfeited and abandoned duels.
create or replace view owner_dashboard.moderation_evidence as
with flagged as (
  select s.player_id, f.flag, count(*) as n
  from public.upload_flags f
  join public.uploaded_sessions s on s.id = f.session_id
  where s.received_at > now() - interval '30 days'
  group by 1, 2
),
sessions as (
  select player_id, string_agg(flag || ' ' || n, ', ' order by flag) as flagged_sessions,
    sum(n) as flags
  from flagged group by 1
),
refusals as (
  select player_id, count(*) as refused_uploads
  from public.upload_rejections
  where received_at > now() - interval '30 days'
  group by 1
),
runs as (
  select player_id,
    count(*) filter (where 'forfeited' = any(flags)) as forfeited_duels,
    count(*) filter (where 'abandoned' = any(flags) and not 'forfeited' = any(flags))
      as abandoned_duels,
    count(*) filter (where cardinality(
      array_remove(array_remove(flags, 'abandoned'), 'forfeited')) > 0) as flagged_runs
  from public.duel_runs
  where created_at > now() - interval '30 days'
  group by 1
),
players as (
  select player_id from sessions
  union select player_id from refusals
  union select player_id from runs
    where forfeited_duels + abandoned_duels + flagged_runs > 0
)
select p.player_id,
  public.public_display_name(p.player_id) as player,
  coalesce(s.flagged_sessions, '') as flagged_sessions,
  coalesce(r.refused_uploads, 0) as refused_uploads,
  coalesce(d.flagged_runs, 0) as flagged_runs,
  coalesce(d.forfeited_duels, 0) as forfeited_duels,
  coalesce(d.abandoned_duels, 0) as abandoned_duels,
  coalesce(m.state, '') as moderation
from players p
left join sessions s using (player_id)
left join refusals r using (player_id)
left join runs d using (player_id)
left join public.player_moderation m using (player_id)
order by coalesce(s.flags, 0) + coalesce(r.refused_uploads, 0) + coalesce(d.flagged_runs, 0)
  + coalesce(d.forfeited_duels, 0) desc;

revoke all on function public.upload_played_ms(jsonb) from public, anon, authenticated;
revoke all on function public.player_visible(uuid) from public, anon, authenticated;
revoke all on function public.my_account_under_review() from public, anon;
revoke all on function owner_dashboard.moderate(uuid, text, text) from public, anon, authenticated;
revoke all on function owner_dashboard.unmoderate(uuid) from public, anon, authenticated;
grant execute on function public.upload_played_ms(jsonb) to service_role;
grant execute on function public.player_visible(uuid) to service_role;
grant execute on function public.my_account_under_review() to authenticated;
