-- Levels phase commit 4: the transition to the level system of
-- doc/levels.md (section 4, approved by the owner).
--
-- 1. Levels span 0–100 (everyone starts at 0).
-- 2. Every level resets to 0, history kept: the server's level cache
--    empties (an absent level is 0, as in the app); uploaded sessions stay.
--    One shot: production applies a migration once. A late game of the old
--    rules is refused by the server (`rulesRetired`).
-- 3. The boards start fresh: the main board counts only games of the new
--    rules (rules_version, from the payload since commit 0) toward its
--    three completed games, and an unplayed basic counts as 0; the
--    per-operation boards count `sessions_played`, emptied with the cache.
-- 4. Phase 3b's calibration window restarts with this release: its games
--    measure the new rules. The owner can move it:
--      update owner_dashboard.calibration_window set starts_at = '…';

alter table public.server_levels
  drop constraint if exists server_levels_level_check;
alter table public.server_levels
  add constraint server_levels_level_check check (level between 0 and 10000);

delete from public.server_levels;

-- The main level: the mean of the four basics, an unplayed one at 0.
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

revoke all on function public.leaderboard_rows(text) from public, anon, authenticated;

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
      where s.player_id = me and s.completed and s.kind = 'game'
        and s.rules_version >= 2;
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

update owner_dashboard.calibration_window set starts_at = now();
