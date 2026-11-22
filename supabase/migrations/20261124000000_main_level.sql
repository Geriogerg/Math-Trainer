-- The main level (Redesign phase commit 1, plan v2.9): the main board —
-- still called 'overall', the name builds already in players' browsers ask
-- for — ranks the mean of the four basic operations, an unplayed one
-- counting as level 1 (the app's mainLevel). Advanced operations keep
-- their own boards and never count here. Nothing is stored: every row is
-- recomputed from server_levels on each read, so the new definition
-- applies to every player at once.

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
      round((coalesce(sum(l.level), 0) + 100 * (4 - count(l.level))) / 4.0)::integer
    from active a
    left join public.server_levels l
      on l.player_id = a.player_id
      and l.exercise_type in ('addition', 'subtraction', 'multiplication', 'division')
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
