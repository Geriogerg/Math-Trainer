-- Phase 6a commit 2 (plan v3.9; review finding B4): a floor under abuse.
--
-- - A refused upload no longer stores its whole payload (up to 256 KB, as
--   often as a client liked: ~2,000 requests filled a free database). It
--   stores a digest — the payload's SHA-256, its size, its first 1,000
--   characters — and at most 50 a day per player. Same for refused duel
--   runs. Rows already stored are reduced the same way.
-- - The server reads two daily counts with calls it already makes, to cap
--   accepted sessions and new duels per player: `player_server_state`
--   (`acceptedToday`) and `duel_player` (`duelsToday`).
--
-- Every function keeps its signature (the server deployed before this
-- migration keeps working; it simply does not read the new keys yet).

-- What is kept of a refused payload. Already a digest: unchanged.
create or replace function public.refusal_digest(p_payload jsonb)
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select case
    when p_payload ? 'sha256' and p_payload ? 'head' then p_payload
    else jsonb_build_object(
      'sha256', encode(sha256(convert_to(p_payload::text, 'UTF8')), 'hex'),
      'bytes', octet_length(p_payload::text),
      'head', left(p_payload::text, 1000)
    )
  end
$$;

-- Refusals kept per player over a rolling 24 hours.
create or replace function public.refusals_kept_per_day() returns integer
language sql immutable set search_path = '' as $$ select 50 $$;

create index if not exists upload_rejections_player_received
  on public.upload_rejections (player_id, received_at desc);
create index if not exists uploaded_sessions_player_received
  on public.uploaded_sessions (player_id, received_at desc);

update public.upload_rejections set payload = public.refusal_digest(payload)
where not (payload ? 'sha256' and payload ? 'head');
update public.duel_run_rejections set payload = public.refusal_digest(payload)
where not (payload ? 'sha256' and payload ? 'head');

-- Records a refused upload (once per id): a digest, and nothing past the
-- player's daily count — a refusal not kept is decided again if it is ever
-- resent (the same verdict; the app never resends one).
create or replace function public.record_rejected_upload(
  p_session_id uuid,
  p_player_id uuid,
  p_reason text,
  p_detail text,
  p_payload jsonb
)
returns void
language plpgsql
set search_path = ''
as $$
begin
  -- One player's refusals at a time: the count below cannot be raced.
  perform pg_advisory_xact_lock(hashtext('upload_rejections' || p_player_id::text));
  if (
    select count(*) from public.upload_rejections r
    where r.player_id = p_player_id and r.received_at > now() - interval '24 hours'
  ) >= public.refusals_kept_per_day() then
    return;
  end if;
  insert into public.upload_rejections (session_id, player_id, reason, detail, payload)
  values (p_session_id, p_player_id, p_reason, left(p_detail, 500),
    public.refusal_digest(p_payload))
  on conflict (session_id) do nothing;
end;
$$;

-- A challenger's refused first run: a digest of it; the duel is void.
create or replace function public.record_duel_run_refused(
  p_duel_id uuid,
  p_player_id uuid,
  p_reason text,
  p_detail text,
  p_payload jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.duel_run_rejections (duel_id, player_id, reason, detail, payload)
  values (p_duel_id, p_player_id, p_reason, left(p_detail, 500),
    public.refusal_digest(p_payload))
  on conflict (duel_id, player_id) do nothing;
  update public.duels set state = 'void', finished_at = now()
  where id = p_duel_id and state in ('awaitingFirst', 'awaitingSecond')
    and p_player_id in (first_player, second_player);
end;
$$;

-- The second player's forfeit: a digest of what was sent.
create or replace function public.record_duel_run_forfeit(
  p_duel_id uuid,
  p_player_id uuid,
  p_reason text,
  p_detail text,
  p_payload jsonb
)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.duel_run_rejections (duel_id, player_id, reason, detail, payload)
  select p_duel_id, p_player_id, p_reason, left(p_detail, 500),
    public.refusal_digest(p_payload)
  where exists (
    select from public.duels d
    where d.id = p_duel_id and d.second_player = p_player_id
  )
  on conflict (duel_id, player_id) do nothing
$$;

-- player_server_state, with the sessions accepted from the player over the
-- last 24 hours (the server's daily cap).
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
    'acceptedToday', (
      select count(*) from public.uploaded_sessions s
      where s.player_id = p_player_id and s.received_at > now() - interval '24 hours'
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

-- duel_player, with the duels handed out to the player (or challenges they
-- sent) over the last 24 hours, every mode together.
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
    'levels', coalesce((
      select jsonb_object_agg(l.exercise_type, l.level)
      from public.server_levels l where l.player_id = u.id
    ), '{}'::jsonb)
  )
  from auth.users u
  where u.id = p_player_id
$$;

revoke all on function public.refusal_digest(jsonb) from public, anon, authenticated;
revoke all on function public.refusals_kept_per_day() from public, anon, authenticated;
grant execute on function public.refusal_digest(jsonb) to service_role;
grant execute on function public.refusals_kept_per_day() to service_role;
