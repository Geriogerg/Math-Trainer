-- Phase 7 commit 4 (plan v3.7): what the server's matchmaking endpoint
-- reads and writes beyond the pool (`duel_take_run`, commit 2). Service
-- role only, like every duel function.

-- A player as matchmaking sees them in p_mode: linked or not, the name
-- shown, their rating row if any, and their server levels (a missing
-- rating starts from them, `startingDuelRating`). Null: no such player.
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
    'levels', coalesce((
      select jsonb_object_agg(l.exercise_type, l.level)
      from public.server_levels l where l.player_id = u.id
    ), '{}'::jsonb)
  )
  from auth.users u
  where u.id = p_player_id
$$;

-- The caller's unanswered pool or practice duel of p_mode opened within
-- the last hour, as an offer — matchmaking hands it back instead of a new
-- one, so asking again never burns other players' runs nor shops for an
-- easier opponent. Null: none.
create or replace function public.duel_open_offer(p_player_id uuid, p_mode text)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'duelId', d.id,
    'kind', d.kind,
    'config', d.config,
    'lane', d.first_lane,
    'opponent', case when d.first_player is null then null else jsonb_build_object(
      'id', d.first_player,
      'name', public.public_display_name(d.first_player),
      'rating', o.rating,
      'ratedDuels', o.rated_duels
    ) end
  )
  from public.duels d
  left join public.duel_ratings o on o.player_id = d.first_player and o.mode = d.mode
  where d.second_player = p_player_id
    and d.mode = p_mode
    and d.kind in ('pool', 'practice')
    and d.state = 'awaitingSecond'
    and d.created_at > now() - interval '1 hour'
  order by d.created_at desc
  limit 1
$$;

-- A challenge from p_challenger to p_target in p_mode (the challenger plays
-- first; 7 days). 'created'; 'self'; 'notLinked' (no such player, or a
-- guest: online play needs a linked account); 'exists' (an open challenge
-- between the two in this mode, either way round: one at a time).
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
  -- Serialise challenges between the same two players.
  perform pg_advisory_xact_lock(hashtext(least(p_challenger, p_target)::text
    || greatest(p_challenger, p_target)::text || p_mode));
  if exists (
    select from public.duels d
    where d.kind = 'challenge' and d.mode = p_mode
      and d.state in ('awaitingFirst', 'awaitingSecond')
      and (d.expires_at is null or d.expires_at > now())
      and least(d.first_player, d.second_player) = least(p_challenger, p_target)
      and greatest(d.first_player, d.second_player) = greatest(p_challenger, p_target)
  ) then
    return 'exists';
  end if;
  perform public.duel_insert(p_duel_id, p_mode, 'challenge', p_config, p_challenger,
    p_target, null, now() + interval '7 days');
  return 'created';
end;
$$;

revoke all on function public.duel_player(uuid, text) from public, anon, authenticated;
revoke all on function public.duel_open_offer(uuid, text) from public, anon, authenticated;
revoke all on function public.duel_create_challenge(uuid, text, jsonb, uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.duel_player(uuid, text) to service_role;
grant execute on function public.duel_open_offer(uuid, text) to service_role;
grant execute on function public.duel_create_challenge(uuid, text, jsonb, uuid, uuid)
  to service_role;
