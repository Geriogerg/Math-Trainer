-- Phase 6c commit 3 (plan v4.1; review B2): an unconfirmed account is a
-- guest for the boards, duels, friends and name reports.
--
-- "Saved" meant `not is_anonymous`. With email confirmation on, a guest who
-- links an email stays anonymous until the link is opened — already a
-- guest. What this adds: an account that is not anonymous but whose email
-- was never confirmed (an email sign-up, an account made by hand; with
-- confirmation off every linked email is confirmed at once) is a guest too.
-- Each function below is its latest definition, unchanged but for that test;
-- the signatures stay (the server deployed before this migration keeps
-- calling them).

-- friend_caller: from 20261130030000_friends.sql, a saved account now also has its email confirmed.
create or replace function public.friend_caller()
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
begin
  if me is null or not exists (
    select from auth.users u where u.id = me and (not u.is_anonymous and u.email_confirmed_at is not null)
  ) then
    raise exception 'a linked account is required' using errcode = '42501';
  end if;
  return me;
end;
$$;

-- friend_request: from 20261202050000_details.sql, a saved account now also has its email confirmed.
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
  perform pg_advisory_xact_lock(hashtext('friend_request' || me::text));
  if (select count(*) from public.friend_request_attempts a
      where a.player_id = me and a.at > now() - interval '24 hours')
     >= public.friend_daily_requests() then
    return 'tooMany';
  end if;
  insert into public.friend_request_attempts (player_id) values (me);
  select c.player_id into target
  from public.friend_codes c
  join auth.users u on u.id = c.player_id and (not u.is_anonymous and u.email_confirmed_at is not null)
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

-- report_player_name: from 20261202030000_names_privacy.sql, a saved account now also has its email confirmed.
create or replace function public.report_player_name(p_player_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
begin
  if me is null then
    raise exception 'not signed in' using errcode = '28000';
  end if;
  if not exists (select from auth.users u where u.id = me and (not u.is_anonymous and u.email_confirmed_at is not null)) then
    raise exception 'only a saved account can report a name' using errcode = '42501';
  end if;
  if me = p_player_id then
    return;
  end if;
  perform pg_advisory_xact_lock(hashtext('name_reports' || me::text));
  if (
    select count(*) from public.name_reports r
    where r.reporter_id = me and r.created_at > now() - interval '24 hours'
  ) >= public.name_reports_per_day() then
    raise exception 'too many reports today' using errcode = '54000';
  end if;
  insert into public.name_reports (reporter_id, reported_id, reported_name)
  select me, p_player_id, pr.display_name
  from public.profiles pr
  where pr.id = p_player_id and pr.display_name is not null
  on conflict (reporter_id, reported_id) do update set
    reported_name = excluded.reported_name,
    created_at = now()
  where public.name_reports.created_at
    <= coalesce(public.name_reviewed_at(p_player_id), '-infinity');
end;
$$;

-- duel_player: from 20261202020000_moderation.sql, a saved account now also has its email confirmed.
create or replace function public.duel_player(p_player_id uuid, p_mode text)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', u.id,
    'linked', (not u.is_anonymous and u.email_confirmed_at is not null),
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

-- duel_create_challenge: from 20261202020000_moderation.sql, a saved account now also has its email confirmed.
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
  if not exists (select from auth.users u where u.id = p_target and (not u.is_anonymous and u.email_confirmed_at is not null)) then
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

-- duel_take_run: from 20261202040000_capacity.sql, a saved account now also has its email confirmed.
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
  window_points double precision;
begin
  if not public.player_visible(p_player_id) then
    return null;
  end if;
  foreach window_points in array array[50, 150, 400, 'Infinity']::double precision[] loop
    select r.* into picked
    from public.duel_ratings o
    join public.duel_runs r on r.player_id = o.player_id and r.mode = o.mode and r.in_pool
    join auth.users u on u.id = r.player_id
    where o.mode = p_mode
      and (case when p_opponent is null
        then o.rating between p_rating - window_points and p_rating + window_points
        else o.player_id = p_opponent end)
      and (not u.is_anonymous and u.email_confirmed_at is not null)
      and r.player_id <> p_player_id
      -- The hidden players once, as an array: player_visible() per run cost
      -- 50 ms at 10,000 players, an anti-join the planner loops 145 ms.
      and o.player_id <> all (array(select m.player_id from public.player_moderation m))
      and r.config_hash not in (
        select d.config_hash from public.duels d where d.first_player = p_player_id
        union all
        select d.config_hash from public.duels d where d.second_player = p_player_id
      )
    order by
      case when p_opponent is null then abs(o.rating - p_rating)
        else abs((r.config ->> 'difficulty')::integer - coalesce(p_difficulty, 0)) end,
      r.created_at desc,
      r.id
    limit 1
    for update of r skip locked;
    exit when found or p_opponent is not null;
  end loop;
  if picked.id is null then
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

-- duel_overview: from 20261202030000_names_privacy.sql, a saved account now also has its email confirmed.
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
    select from auth.users u where u.id = me and (not u.is_anonymous and u.email_confirmed_at is not null)
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
        'from', public.duel_opponent_name(d.kind, d.first_player),
        'expiresAt', d.expires_at
      ) order by d.expires_at)
      from public.duels d
      where d.kind = 'challenge' and d.second_player = me
        and d.state = 'awaitingSecond'
        and (d.expires_at > now()
          or d.opened_at > now() - public.duel_abandon_after())
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
            'raced', d.first_player = me,
            'opponentId', case when d.first_player = me then d.second_player
              else d.first_player end,
            'opponent', public.duel_opponent_name(d.kind,
              case when d.first_player = me then d.second_player else d.first_player end),
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
    ), '[]'::jsonb),
    'friendRequests', (
      select count(*) from public.friend_requests r where r.to_player = me
    )
  );
end;
$$;

-- leaderboard_rows: from 20261202040000_capacity.sql, a saved account now also has its email confirmed.
create or replace function public.leaderboard_rows(p_board text)
returns table (player_id uuid, level integer, rank bigint, total bigint)
language sql
stable
security definer
set search_path = ''
as $$
  with active as (
    select p.player_id, p.completed_games
    from public.server_players p
    join auth.users u on u.id = p.player_id
    where p.last_session_at >= now() - interval '30 days'
      and (not u.is_anonymous and u.email_confirmed_at is not null)
      and p.player_id <> all (array(select m.player_id from public.player_moderation m))
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
      and a.completed_games >= public.leaderboard_min_sessions()
    group by a.player_id
  )
  select b.player_id, b.level,
    rank() over (order by b.level desc),
    count(*) over ()
  from board b
$$;

-- leaderboard_around_me: from 20261202040000_capacity.sql, a saved account now also has its email confirmed.
create or replace function public.leaderboard_around_me(p_board text)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
  mine public.board_rows;
  board_total integer;
  last_at timestamptz;
  counted integer;
begin
  perform public.leaderboard_check_board(p_board);
  if me is null then
    return jsonb_build_object('eligible', false, 'reason', 'signedOut');
  end if;
  if exists (select from auth.users u where u.id = me and (u.is_anonymous or u.email_confirmed_at is null)) then
    return jsonb_build_object('eligible', false, 'reason', 'notLinked');
  end if;
  perform public.board_refresh(p_board);
  select b.* into mine from public.board_rows b
  where b.board = p_board and b.player_id = me;
  if not found then
    select p.last_session_at, p.completed_games into last_at, counted
    from public.server_players p where p.player_id = me;
    if p_board <> 'overall' then
      select coalesce(max(l.sessions_played), 0) into counted
      from public.server_levels l
      where l.player_id = me and l.exercise_type = p_board;
    end if;
    counted := coalesce(counted, 0);
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
  select s.total into board_total from public.board_snapshots s where s.board = p_board;
  return jsonb_build_object(
    'eligible', true,
    'rank', mine.rank,
    'total', board_total,
    'topPercent', ceil(100.0 * mine.rank / board_total)::integer,
    'level', mine.value,
    'neighbours', (
      select jsonb_agg(public.leaderboard_entry(n.player_id, n.rank, n.value)
        order by n.position)
      from public.board_rows n
      where n.board = p_board
        and n.position between mine.position - 5 and mine.position + 5
    )
  );
end;
$$;

-- duel_board_rows: from 20261202040000_capacity.sql, a saved account now also has its email confirmed.
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
    and (not u.is_anonymous and u.email_confirmed_at is not null)
    and o.rated_duels >= public.duel_board_min_duels()
    and o.last_rated_at >= now() - interval '30 days'
    and o.player_id <> all (array(select m.player_id from public.player_moderation m))
$$;

-- duel_board_around_me: from 20261202040000_capacity.sql, a saved account now also has its email confirmed.
create or replace function public.duel_board_around_me(p_mode text)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
  mine public.board_rows;
  board_total integer;
  held public.duel_ratings;
begin
  perform public.duel_check_mode(p_mode);
  if me is null then
    return jsonb_build_object('eligible', false, 'reason', 'signedOut');
  end if;
  if exists (select from auth.users u where u.id = me and (u.is_anonymous or u.email_confirmed_at is null)) then
    return jsonb_build_object('eligible', false, 'reason', 'notLinked');
  end if;
  perform public.board_refresh('duel:' || p_mode);
  select b.* into mine from public.board_rows b
  where b.board = 'duel:' || p_mode and b.player_id = me;
  if not found then
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
  select s.total into board_total from public.board_snapshots s
  where s.board = 'duel:' || p_mode;
  return jsonb_build_object(
    'eligible', true,
    'rank', mine.rank,
    'total', board_total,
    'topPercent', ceil(100.0 * mine.rank / board_total)::integer,
    'rating', mine.value,
    'neighbours', (
      select jsonb_agg(public.duel_board_entry(n.player_id, n.rank, n.value)
        order by n.position)
      from public.board_rows n
      where n.board = 'duel:' || p_mode
        and n.position between mine.position - 5 and mine.position + 5
    )
  );
end;
$$;
