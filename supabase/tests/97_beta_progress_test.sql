-- Beta progress (Phase 5.1 commit 4): the distance to Phase 3b's entry and
-- each tester's activity.

delete from auth.users;
delete from public.beta_codes;
insert into auth.users (id, is_anonymous) values
  ('00000000-0000-0000-0000-0000000000e1', true),
  ('00000000-0000-0000-0000-0000000000e2', true),
  ('00000000-0000-0000-0000-0000000000e3', true);
insert into public.beta_codes (code, label, max_uses) values ('PROGRESS1', 'Zoé', 2);
insert into public.beta_code_uses (player_id, code) values
  ('00000000-0000-0000-0000-0000000000e1', 'PROGRESS1');

-- e1: 4 completed games, the last 2 days ago, one interrupted, a placement.
-- e2: 2 completed games 10 days ago. e3: only a placement, no game.
insert into public.uploaded_sessions (id, player_id, created_at, kind, payload, completed)
select gen_random_uuid(), p, now() - d * interval '1 day', k, '{}', c
from (values
  ('00000000-0000-0000-0000-0000000000e1'::uuid, 2, 'game', true),
  ('00000000-0000-0000-0000-0000000000e1'::uuid, 3, 'game', true),
  ('00000000-0000-0000-0000-0000000000e1'::uuid, 5, 'game', true),
  ('00000000-0000-0000-0000-0000000000e1'::uuid, 9, 'game', true),
  ('00000000-0000-0000-0000-0000000000e1'::uuid, 9, 'game', false),
  ('00000000-0000-0000-0000-0000000000e1'::uuid, 12, 'placementV1', true),
  ('00000000-0000-0000-0000-0000000000e2'::uuid, 10, 'game', true),
  ('00000000-0000-0000-0000-0000000000e2'::uuid, 10, 'game', true),
  ('00000000-0000-0000-0000-0000000000e3'::uuid, 1, 'typePlacementV3', true)
) as t(p, d, k, c);

do $$
declare
  r record;
begin
  select * into r from owner_dashboard.beta_progress;
  assert r.completed_games = 6 and r.testers = 2, format('totals: %s', row_to_json(r));
  assert r.games_pct = 2 and r.testers_pct = 20 and not r.ready, format('pcts: %s', row_to_json(r));
  assert r.games_per_tester = 3.0 and r.median_games_per_tester = 2,
    format('per tester: %s', row_to_json(r));
  -- 3 games in the last 7 days: 294 to go at 3 a week → 686 days.
  assert r.games_last_7_days = 3 and r.days_to_300_at_this_pace = 686,
    format('pace: %s', row_to_json(r));
  assert r.days_since_first_game = 10, format('first game: %s', row_to_json(r));
end;
$$;

do $$
declare
  r record;
  n integer;
begin
  select count(*) into n from owner_dashboard.tester_activity;
  assert n = 3, format('every player who uploaded: %s', n);
  select * into r from owner_dashboard.tester_activity where invited_as = 'Zoé';
  assert r.games_completed = 4 and r.games_interrupted = 1 and r.placements = 1
      and r.days_since_last_game = 2,
    format('Zoé: %s', row_to_json(r));
  -- The most recently active first; a player without a game last.
  select * into r from owner_dashboard.tester_activity limit 1;
  assert r.invited_as = 'Zoé', format('first row: %s', row_to_json(r));
  select * into r from owner_dashboard.tester_activity offset 2;
  assert r.last_game_at is null and r.days_since_last_game is null and r.placements = 1,
    format('last row: %s', row_to_json(r));
end;
$$;

-- Nothing played yet: zeros, no pace, nothing divided by zero.
delete from public.uploaded_sessions;
do $$
declare
  r record;
begin
  select * into r from owner_dashboard.beta_progress;
  assert r.completed_games = 0 and r.testers = 0 and r.games_per_tester is null
      and r.days_to_300_at_this_pace is null and r.days_since_first_game is null,
    format('empty: %s', row_to_json(r));
end;
$$;

do $$
begin
  assert not has_table_privilege('anon', 'owner_dashboard.beta_progress', 'select'), 'anon';
  assert not has_table_privilege('authenticated', 'owner_dashboard.tester_activity', 'select'),
    'authenticated';
end;
$$;
