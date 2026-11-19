-- Leaderboard (Phase 2 commit 7): rank and percentile from the server's own
-- levels. Players never touch the tables: everyone (signed out included)
-- reads through the two functions below, which return only rank, player
-- name and level. Only the server writes (commit 6).

-- Eligibility (plan 6.4; thresholds provisional, doc/decisions.md):
-- active = an accepted session within 30 days; per operation, at least 3
-- counted sessions on it; overall, at least 3 completed games.
create or replace function public.leaderboard_min_sessions()
returns integer language sql immutable set search_path = '' as $$ select 3 $$;

create or replace function public.leaderboard_check_board(p_board text)
returns void
language plpgsql
immutable
set search_path = ''
as $$
begin
  if p_board not in ('overall', 'addition', 'subtraction', 'multiplication',
      'division', 'power', 'squareRoot', 'percentage') then
    raise exception 'unknown board %', p_board using errcode = '22023';
  end if;
end;
$$;

-- Every eligible player of a board with their level (hundredths) and rank.
-- Overall level: the mean of the seven, an unplayed one counting as level 1
-- (the app's overallLevel), rounded to hundredths.
create or replace function public.leaderboard_rows(p_board text)
returns table (player_id uuid, level integer, rank bigint, total bigint)
language sql
stable
security definer
set search_path = ''
as $$
  with active as (
    select p.player_id from public.server_players p
    where p.last_session_at >= now() - interval '30 days'
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
      round((coalesce(sum(l.level), 0) + 100 * (7 - count(l.level))) / 7.0)::integer
    from active a
    left join public.server_levels l on l.player_id = a.player_id
    where p_board = 'overall'
      and (select count(*) from public.uploaded_sessions s
           where s.player_id = a.player_id and s.completed and s.kind = 'game')
          >= public.leaderboard_min_sessions()
    group by a.player_id
  )
  select b.player_id, b.level,
    rank() over (order by b.level desc),
    count(*) over ()
  from board b
$$;

-- An entry as the app reads it.
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
    'rank', p_rank,
    'name', (select pr.display_name from public.profiles pr where pr.id = p_player_id),
    'level', p_level,
    'isMe', p_player_id is not distinct from auth.uid()
  )
$$;

-- The top of a board: at most 100 entries, best first.
create or replace function public.leaderboard_top(p_board text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform public.leaderboard_check_board(p_board);
  return coalesce((
    select jsonb_agg(public.leaderboard_entry(r.player_id, r.rank, r.level)
      order by r.rank, r.player_id)
    from (
      select * from public.leaderboard_rows(p_board)
      order by rank, player_id
      limit 100
    ) r
  ), '[]'::jsonb);
end;
$$;

-- The caller on a board: rank, total, "top N %" and the five players above
-- and below; or why they are not on it, and how many sessions are missing.
create or replace function public.leaderboard_around_me(p_board text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
  my_position bigint;
  last_at timestamptz;
  counted integer;
begin
  perform public.leaderboard_check_board(p_board);
  if me is null then
    return jsonb_build_object('eligible', false, 'reason', 'signedOut');
  end if;

  -- The caller's position on the whole board (ties broken by id, so the
  -- neighbours window is stable).
  select x.position into my_position from (
    select r.player_id, row_number() over (order by r.rank, r.player_id) as position
    from public.leaderboard_rows(p_board) r
  ) x where x.player_id = me;

  if my_position is null then
    select p.last_session_at into last_at
    from public.server_players p where p.player_id = me;
    if p_board = 'overall' then
      select count(*) into counted from public.uploaded_sessions s
      where s.player_id = me and s.completed and s.kind = 'game';
    else
      select coalesce(max(l.sessions_played), 0) into counted
      from public.server_levels l
      where l.player_id = me and l.exercise_type = p_board;
    end if;
    return jsonb_build_object(
      'eligible', false,
      'reason', case
        when last_at is null then 'noSessions'
        when counted < public.leaderboard_min_sessions() then 'notEnoughSessions'
        else 'inactive'
      end,
      'sessionsNeeded', greatest(public.leaderboard_min_sessions() - counted, 0)
    );
  end if;

  return (
    select jsonb_build_object(
      'eligible', true,
      'rank', me_row.rank,
      'total', me_row.total,
      -- "Top N %": the share of the board at or above the caller's rank.
      'topPercent', ceil(100.0 * me_row.rank / me_row.total)::integer,
      'level', me_row.level,
      'neighbours', (
        select jsonb_agg(public.leaderboard_entry(n.player_id, n.rank, n.level)
          order by n.position)
        from (
          select r.*, row_number() over (order by r.rank, r.player_id) as position
          from public.leaderboard_rows(p_board) r
        ) n
        where n.position between my_position - 5 and my_position + 5
      )
    )
    from public.leaderboard_rows(p_board) me_row
    where me_row.player_id = me
  );
end;
$$;

-- Helpers are internal; the two readers are for everyone.
revoke all on function public.leaderboard_rows(text) from public, anon, authenticated;
revoke all on function public.leaderboard_entry(uuid, bigint, integer) from public, anon, authenticated;
revoke all on function public.leaderboard_top(text) from public;
revoke all on function public.leaderboard_around_me(text) from public;
grant execute on function public.leaderboard_top(text) to anon, authenticated, service_role;
grant execute on function public.leaderboard_around_me(text) to anon, authenticated, service_role;
