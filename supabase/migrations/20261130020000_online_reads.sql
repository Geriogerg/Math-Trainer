-- Phase 7 commit 6 (plan v3.7): what the app reads for the Online tab and
-- the three duel boards, straight from Supabase like the leaderboard (a
-- sleeping server never slows a screen). `security definer` functions on
-- `auth.uid()`: a player reads only their own duels; boards show rank, name
-- and rating only. The tables stay closed.

-- The caller's Online tab: whether they are linked (guests cannot play
-- online), their ratings per mode, the challenges waiting for them, and
-- their 20 latest duels — raced, or their run raced by someone — with the
-- result from their side.
create or replace function public.duel_overview()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
begin
  if me is null or not exists (
    select from auth.users u where u.id = me and not u.is_anonymous
  ) then
    return jsonb_build_object('linked', false);
  end if;
  return jsonb_build_object(
    'linked', true,
    'ratings', coalesce((
      select jsonb_object_agg(o.mode, jsonb_build_object(
        'rating', o.rating,
        'ratedDuels', o.rated_duels
      ))
      from public.duel_ratings o where o.player_id = me
    ), '{}'::jsonb),
    'waiting', coalesce((
      select jsonb_agg(jsonb_build_object(
        'duelId', d.id,
        'mode', d.mode,
        'fromId', d.first_player,
        'from', public.public_display_name(d.first_player),
        'expiresAt', d.expires_at
      ) order by d.expires_at)
      from public.duels d
      where d.kind = 'challenge' and d.second_player = me
        and d.state = 'awaitingSecond' and d.expires_at > now()
    ), '[]'::jsonb),
    'recent', coalesce((
      select jsonb_agg(r.entry order by r.at desc)
      from (
        select coalesce(d.finished_at, d.created_at) as at,
          jsonb_build_object(
            'duelId', d.id,
            'mode', d.mode,
            'kind', d.kind,
            'at', coalesce(d.finished_at, d.created_at),
            'state', d.state,
            -- The caller's run was the recorded one: someone raced it.
            'raced', d.first_player = me,
            'opponentId', case when d.first_player = me then d.second_player
              else d.first_player end,
            'opponent', public.public_display_name(
              case when d.first_player = me then d.second_player else d.first_player end
            ),
            'result', case when d.first_player = me then 1 - d.result else d.result end,
            'rated', d.rated
          ) as entry
        from public.duels d
        where (d.second_player = me and d.state in ('done', 'void'))
           or (d.first_player = me and d.state = 'done')
           or (d.first_player = me and d.kind = 'challenge' and d.state = 'awaitingSecond')
        order by coalesce(d.finished_at, d.created_at) desc
        limit 20
      ) r
    ), '[]'::jsonb)
  );
end;
$$;

revoke all on function public.duel_overview() from public, anon;
grant execute on function public.duel_overview() to authenticated, service_role;

-- A duel board's minimum (plan v3.7: provisional for the first 10 rated
-- duels) and activity window (30 days, as the level boards).
create or replace function public.duel_board_min_duels() returns integer
language sql immutable as $$ select 10 $$;

-- Every ranked player of a mode's board: linked, non-provisional, a rated
-- duel within 30 days; ordered on the rating, shown whole.
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
$$;

create or replace function public.duel_board_entry(
  p_player_id uuid, p_rank bigint, p_rating integer
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'rank', p_rank,
    'playerId', p_player_id,
    'name', public.public_display_name(p_player_id),
    'rating', p_rating,
    'isMe', p_player_id is not distinct from auth.uid()
  )
$$;

create or replace function public.duel_check_mode(p_mode text)
returns void
language plpgsql
immutable
as $$
begin
  if p_mode not in ('basics', 'advanced', 'count') then
    raise exception 'unknown duel board %', p_mode using errcode = '22023';
  end if;
end;
$$;

-- The 100 best of a mode's board.
create or replace function public.duel_board_top(p_mode text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform public.duel_check_mode(p_mode);
  return coalesce((
    select jsonb_agg(public.duel_board_entry(r.player_id, r.rank, r.rating)
      order by r.rank, r.player_id)
    from (
      select * from public.duel_board_rows(p_mode)
      order by rank, player_id limit 100
    ) r
  ), '[]'::jsonb);
end;
$$;

-- The caller's standing on a mode's board, as `leaderboard_around_me`
-- answers: ranked with five above and five below, or why not —
-- signedOut, notLinked, noDuels (no rated duel in this mode yet),
-- provisional (fewer than 10 rated duels: `sessionsNeeded` more), inactive.
create or replace function public.duel_board_around_me(p_mode text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
  my_position bigint;
  held public.duel_ratings;
begin
  perform public.duel_check_mode(p_mode);
  if me is null then
    return jsonb_build_object('eligible', false, 'reason', 'signedOut');
  end if;
  if exists (select from auth.users u where u.id = me and u.is_anonymous) then
    return jsonb_build_object('eligible', false, 'reason', 'notLinked');
  end if;

  select x.position into my_position from (
    select r.player_id, row_number() over (order by r.rank, r.player_id) as position
    from public.duel_board_rows(p_mode) r
  ) x where x.player_id = me;

  if my_position is null then
    select o.* into held from public.duel_ratings o
    where o.player_id = me and o.mode = p_mode;
    return jsonb_build_object(
      'eligible', false,
      'reason', case
        when held.player_id is null or held.rated_duels = 0 then 'noDuels'
        when held.rated_duels < public.duel_board_min_duels() then 'provisional'
        else 'inactive'
      end,
      'sessionsNeeded', greatest(
        public.duel_board_min_duels() - coalesce(held.rated_duels, 0), 0)
    );
  end if;

  return (
    select jsonb_build_object(
      'eligible', true,
      'rank', me_row.rank,
      'total', me_row.total,
      'topPercent', ceil(100.0 * me_row.rank / me_row.total)::integer,
      'rating', me_row.rating,
      'neighbours', (
        select jsonb_agg(public.duel_board_entry(n.player_id, n.rank, n.rating)
          order by n.position)
        from (
          select r.player_id, r.rank, r.rating,
            row_number() over (order by r.rank, r.player_id) as position
          from public.duel_board_rows(p_mode) r
        ) n
        where n.position between my_position - 5 and my_position + 5
      )
    )
    from public.duel_board_rows(p_mode) me_row
    where me_row.player_id = me
  );
end;
$$;

revoke all on function public.duel_board_rows(text) from public, anon, authenticated;
revoke all on function public.duel_board_entry(uuid, bigint, integer) from public, anon, authenticated;
revoke all on function public.duel_board_top(text) from public;
revoke all on function public.duel_board_around_me(text) from public;
grant execute on function public.duel_board_top(text) to anon, authenticated, service_role;
grant execute on function public.duel_board_around_me(text) to anon, authenticated, service_role;
