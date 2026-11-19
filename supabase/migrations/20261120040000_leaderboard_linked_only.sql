-- Only linked players appear on the leaderboard (Phase 2 commit 10; plan
-- 6.3): a guest's levels are kept and validated like anyone's, but the
-- boards list players who saved their progress (an email). A guest who
-- links keeps the same id, so their place appears at once.

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

revoke all on function public.leaderboard_rows(text) from public, anon, authenticated;

-- A guest asking for their standing: 'notLinked' first — the one thing
-- that would put them on the board — then the usual reasons.
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
  if exists (select from auth.users u where u.id = me and u.is_anonymous) then
    return jsonb_build_object('eligible', false, 'reason', 'notLinked');
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

revoke all on function public.leaderboard_around_me(text) from public;
grant execute on function public.leaderboard_around_me(text) to anon, authenticated, service_role;
