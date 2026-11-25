-- Phase 7 commit 8: the owner's duel views and the review of a flagged run.

delete from auth.users;
insert into auth.users (id, is_anonymous) values
  ('00000000-0000-0000-0000-0000000005a1', false),
  ('00000000-0000-0000-0000-0000000005a2', false);
insert into public.profiles (id, display_name) values
  ('00000000-0000-0000-0000-0000000005a1', 'Léa');

insert into public.duels (id, mode, kind, config, first_player, second_player, state,
  result, rated, created_at) values
  -- Today: a rated pool duel, a void practice, a practice left unanswered
  -- two hours ago, a practice under way.
  ('00000000-0000-0000-0000-0000000006d1', 'basics', 'pool', '{}',
   '00000000-0000-0000-0000-0000000005a2', '00000000-0000-0000-0000-0000000005a1', 'done',
   1, true, now()),
  ('00000000-0000-0000-0000-0000000006d2', 'basics', 'practice', '{}',
   null, '00000000-0000-0000-0000-0000000005a1', 'void', null, false, now()),
  ('00000000-0000-0000-0000-0000000006d3', 'basics', 'practice', '{}',
   null, '00000000-0000-0000-0000-0000000005a1', 'awaitingSecond', null, false,
   now() - interval '2 hours'),
  ('00000000-0000-0000-0000-0000000006d4', 'basics', 'practice', '{}',
   null, '00000000-0000-0000-0000-0000000005a1', 'awaitingSecond', null, false,
   now() - interval '5 minutes');
insert into public.duel_runs (id, duel_id, player_id, mode, config, payload, lane, score,
  flags) values
  ('00000000-0000-0000-0000-0000000007e1', '00000000-0000-0000-0000-0000000006d1',
   '00000000-0000-0000-0000-0000000005a1', 'basics', '{}', '{}', '{}',
   '{"points": 8, "ms": 900}', '{implausiblyFast}');
insert into public.duel_ratings (player_id, mode, rating, deviation, volatility, rated_duels)
values
  ('00000000-0000-0000-0000-0000000005a1', 'basics', 1542, 80, 0.06, 12),
  ('00000000-0000-0000-0000-0000000005a2', 'basics', 1588, 300, 0.06, 2);
insert into public.friendships (player_a, player_b) values
  ('00000000-0000-0000-0000-0000000005a1', '00000000-0000-0000-0000-0000000005a2');

do $$
declare
  today record;
begin
  -- Summed over days: "two hours ago" may be yesterday in UTC.
  select sum(void) as void, sum(open) as open, sum(unanswered) as unanswered into today
  from owner_dashboard.duels_per_day
  where mode = 'basics' and kind = 'practice';
  assert (today.void, today.open, today.unanswered) = (1::numeric, 1::numeric, 1::numeric),
    'practice: one void, one under way, one unanswered';
  assert (select (decided, rated) from owner_dashboard.duels_per_day
          where mode = 'basics' and kind = 'pool') = (1::bigint, 1::bigint);
  assert (select (players, provisional) from owner_dashboard.duel_rating_distribution
          where mode = 'basics' and band = 1500) = (1::bigint, 1::bigint),
    'Léa ranked, the other provisional, both in 1500–1599';
  assert (select review from owner_dashboard.flagged_runs) = 'awaiting review';
  assert (select player from owner_dashboard.flagged_runs) = 'Léa';
  assert (select unanswered from owner_dashboard.unanswered_duels) = 1;
  assert (select (friendships, players_with_friends) from owner_dashboard.friend_counts)
    = (1::bigint, 2::bigint);

  assert owner_dashboard.review_run('00000000-0000-0000-0000-0000000007e1', 'ok');
  assert (select review from public.duel_runs
          where id = '00000000-0000-0000-0000-0000000007e1') = 'ok';
  assert not owner_dashboard.review_run('00000000-0000-0000-0000-0000000000ff', 'ok'),
    'no such run';
end;
$$;

do $$
begin
  perform owner_dashboard.review_run('00000000-0000-0000-0000-0000000007e1', 'maybe');
  assert false, 'a bad verdict must raise';
exception when invalid_parameter_value then
  null;
end;
$$;

do $$
begin
  assert not has_schema_privilege('authenticated', 'owner_dashboard', 'usage');
  assert not has_schema_privilege('anon', 'owner_dashboard', 'usage');
end;
$$;
