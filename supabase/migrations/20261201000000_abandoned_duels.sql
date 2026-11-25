-- Phase 7 close-out commit 1 (plan v3.8): an abandoned duel is a loss. The
-- app sends its run as it stands after every answer and round
-- (`duel_save_progress`); a duel started but not submitted within 24 hours
-- is recorded by the Dart server as a loss, from that progress
-- (`duel_abandoned` lists them). Started: a pool or practice duel when it
-- was handed out, a challenge when the friend opened it (`opened_at`). A
-- challenge whose challenger never played within 24 hours is void: there
-- is no run to lose against. Clearing the browser or switching device no
-- longer escapes a loss.

alter table public.duels add column if not exists progress jsonb;
alter table public.duels add column if not exists opened_at timestamptz;

-- How long a started duel waits for its run.
create or replace function public.duel_abandon_after() returns interval
language sql immutable as $$ select interval '24 hours' $$;

-- The second player's run as it stands (not replayed now: the replay comes
-- with the run, or with the abandonment). 'saved', or 'notOpen' when the
-- duel is not this player's to play.
create or replace function public.duel_save_progress(
  p_duel_id uuid,
  p_player_id uuid,
  p_payload jsonb
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.duels d set progress = p_payload
  where d.id = p_duel_id and d.second_player = p_player_id
    and d.state = 'awaitingSecond';
  return case when found then 'saved' else 'notOpen' end;
end;
$$;

-- The friend opened a challenge: its 24 hours start.
create or replace function public.duel_mark_opened(p_duel_id uuid, p_player_id uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  update public.duels d set opened_at = coalesce(d.opened_at, now())
  where d.id = p_duel_id and d.second_player = p_player_id
    and d.kind = 'challenge' and d.state = 'awaitingSecond'
$$;

-- Up to p_limit duels abandoned by their second player, oldest first:
-- [{duelId, player}]. Voids, on the way, the challenges whose challenger
-- never played within the delay.
create or replace function public.duel_abandoned(p_limit integer)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.duels d set state = 'void', finished_at = now()
  where d.kind = 'challenge' and d.state = 'awaitingFirst'
    and d.created_at < now() - public.duel_abandon_after();
  return coalesce((
    select jsonb_agg(jsonb_build_object('duelId', x.id, 'player', x.second_player)
      order by x.started)
    from (
      select d.id, d.second_player,
        case when d.kind = 'challenge' then d.opened_at else d.created_at end as started
      from public.duels d
      where d.state = 'awaitingSecond'
        and ((d.kind in ('pool', 'practice')
              and d.created_at < now() - public.duel_abandon_after())
          or (d.kind = 'challenge'
              and d.opened_at < now() - public.duel_abandon_after()))
      order by 3
      limit p_limit
    ) x
  ), '[]'::jsonb);
end;
$$;

-- duel_context, with the progress and when the duel started.
create or replace function public.duel_context(p_duel_id uuid, p_player_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'duel', jsonb_build_object(
      'id', d.id,
      'mode', d.mode,
      'kind', d.kind,
      'config', d.config,
      'firstPlayer', d.first_player,
      'secondPlayer', d.second_player,
      'firstLane', d.first_lane,
      'state', d.state,
      'result', d.result,
      'rated', d.rated,
      'firstRatingBefore', d.first_rating_before,
      'firstRatingAfter', d.first_rating_after,
      'secondRatingBefore', d.second_rating_before,
      'secondRatingAfter', d.second_rating_after,
      'expiresAt', d.expires_at,
      'openedAt', d.opened_at,
      'createdAt', d.created_at,
      -- The second player's run as it stood, sent during the duel (close-
      -- out commit 1): what an abandoned duel is recorded from.
      'progress', d.progress,
      'opponentName', public.public_display_name(
        case when d.first_player = p_player_id then d.second_player else d.first_player end
      )
    ),
    'run', (
      select jsonb_build_object('lane', r.lane, 'score', r.score, 'flags', to_jsonb(r.flags))
      from public.duel_runs r where r.duel_id = d.id and r.player_id = p_player_id
    ),
    'rejection', (
      select jsonb_build_object('reason', x.reason)
      from public.duel_run_rejections x
      where x.duel_id = d.id and x.player_id = p_player_id
    ),
    'ratings', coalesce((
      select jsonb_object_agg(o.player_id, jsonb_build_object(
        'rating', o.rating,
        'deviation', o.deviation,
        'volatility', o.volatility,
        'ratedDuels', o.rated_duels,
        'version', o.version
      ))
      from public.duel_ratings o
      where o.mode = d.mode and o.player_id in (d.first_player, d.second_player)
    ), '{}'::jsonb),
    'levels', coalesce((
      select jsonb_object_agg(l.exercise_type, l.level)
      from public.server_levels l where l.player_id = p_player_id
    ), '{}'::jsonb),
    'pairRatedToday', d.kind = 'challenge' and exists (
      select from public.duels x
      where x.kind = 'challenge' and x.rated and x.mode = d.mode and x.id <> d.id
        and least(x.first_player, x.second_player) = least(d.first_player, d.second_player)
        and greatest(x.first_player, x.second_player) = greatest(d.first_player, d.second_player)
        and (x.finished_at at time zone 'utc')::date = (now() at time zone 'utc')::date
    )
  )
  from public.duels d
  where d.id = p_duel_id
$$;

-- The flagged runs the owner reviews: an abandoned run is not one (it is a
-- forfeit, never in the pool).
create or replace view owner_dashboard.flagged_runs as
select r.id as run_id,
  r.created_at,
  r.mode,
  r.player_id,
  public.public_display_name(r.player_id) as player,
  r.flags,
  coalesce(r.review, 'awaiting review') as review,
  r.score,
  r.serves
from public.duel_runs r
where cardinality(array_remove(r.flags, 'abandoned')) > 0;

-- Who abandons duels (recorded as losses).
create or replace view owner_dashboard.abandoned_duels as
select r.player_id,
  public.public_display_name(r.player_id) as player,
  count(*) as abandoned,
  max(r.created_at) as last
from public.duel_runs r
where 'abandoned' = any(r.flags)
group by 1;

revoke all on function public.duel_save_progress(uuid, uuid, jsonb) from public, anon, authenticated;
revoke all on function public.duel_mark_opened(uuid, uuid) from public, anon, authenticated;
revoke all on function public.duel_abandoned(integer) from public, anon, authenticated;
grant execute on function public.duel_save_progress(uuid, uuid, jsonb) to service_role;
grant execute on function public.duel_mark_opened(uuid, uuid) to service_role;
grant execute on function public.duel_abandoned(integer) to service_role;
