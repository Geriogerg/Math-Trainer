-- Phase 6a commit 4 (plan v3.9; review M6, m8): unique names ignoring case
-- and look-alike letters, duplicates already stored resolved, and a
-- deleted player's duels kept as "Deleted player".

-- What a name reads as.
do $$
declare
  c record;
begin
  for c in select * from (values
    ('Ada', 'Ada'), ('ADA', 'Ada'), ('Adà', 'Ada'), ('A.D.A', 'Ada'), ('a-d a', 'Ada'),
    ('Lili', 'L1L1'), ('lili', 'IiIi'), ('Ilia', '1lia'),
    ('Bob0', 'BobO'), ('Moon', 'M00n'),
    ('Marn', 'Mam'), ('Vvictor', 'Wictor'),
    ('Zoé Martin', 'zoe.martin'), ('Łukasz', 'Lukasz'), ('Nguyễn', 'Nguyen'),
    ('Аda', 'Ada'), ('Рaul', 'Paul'), ('Οscar', 'Oscar')
  ) as t(a, b) loop
    assert public.fold_display_name(c.a) = public.fold_display_name(c.b),
      format('%s (%s) and %s (%s) should read the same', c.a,
        public.fold_display_name(c.a), c.b, public.fold_display_name(c.b));
  end loop;
  for c in select * from (values
    ('Ada', 'Adam'), ('Lea', 'Leo'), ('Max 2', 'Max 3'), ('Anna', 'Ana')
  ) as t(a, b) loop
    assert public.fold_display_name(c.a) <> public.fold_display_name(c.b),
      format('%s and %s are different names', c.a, c.b);
  end loop;
  assert public.fold_display_name(null) is null;
end;
$$;

delete from auth.users;
-- Duels outlive their players (Phase 6a: "Deleted player"): cleared here.
delete from public.duels;
insert into auth.users (id, is_anonymous) values
  ('00000000-0000-0000-0000-000000000ee1', false),
  ('00000000-0000-0000-0000-000000000ee2', false),
  ('00000000-0000-0000-0000-000000000ee3', true),
  ('00000000-0000-0000-0000-000000000ee4', false);

-- Unique, whoever saves it, guests included.
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000ee1', false);
insert into public.profiles (id, display_name) values ('00000000-0000-0000-0000-000000000ee1', 'Lili Rose');
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000ee2', false);
do $$
declare
  taken text;
begin
  foreach taken in array array['Lili Rose', 'lili rose', 'L1l1.R0se', 'Lilí Rosé', 'IiIi Rose'] loop
    begin
      insert into public.profiles (id, display_name)
        values ('00000000-0000-0000-0000-000000000ee2', taken);
      raise exception '% was saved beside Lili Rose', taken;
    exception when unique_violation then null;
    end;
  end loop;
  insert into public.profiles (id, display_name)
    values ('00000000-0000-0000-0000-000000000ee2', 'Lili Roses');
end;
$$;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000ee3', false);
do $$
begin
  insert into public.profiles (id, display_name)
    values ('00000000-0000-0000-0000-000000000ee3', 'LILI ROSE');
  raise exception 'a guest took a held name';
exception when unique_violation then null;
end;
$$;
-- Keeping one's own name (another spelling of it) is fine.
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000ee1', false);
update public.profiles set display_name = 'lili rose' where id = '00000000-0000-0000-0000-000000000ee1';
reset role;
select set_config('request.jwt.claim.sub', '', false);

-- Duplicates stored before the index: the earliest keeps the name, the
-- others get the next free number. Checked without the index, rolled back.
begin;
drop index public.profiles_display_name_folded;
insert into auth.users (id, is_anonymous)
select ('00000000-0000-0000-0000-0000000004' || lpad(i::text, 2, '0'))::uuid, false
from generate_series(1, 5) i;
insert into public.profiles (id, display_name, created_at) values
  ('00000000-0000-0000-0000-000000000401', 'Max', now() - interval '3 days'),
  ('00000000-0000-0000-0000-000000000402', 'MAX', now() - interval '2 days'),
  ('00000000-0000-0000-0000-000000000403', 'Max 2', now() - interval '1 day'),
  ('00000000-0000-0000-0000-000000000404', 'm.a.x', now()),
  ('00000000-0000-0000-0000-000000000405', 'Abcdefghijklmnopqrstuvwxyzabcd', now());
insert into public.profiles (id, display_name, created_at)
select '00000000-0000-0000-0000-000000000ee4', 'abcdefghijklmnopqrstuvwxyzabcd', now() + interval '1 second';
do $$
begin
  assert public.resolve_duplicate_display_names() = 3;
  assert (select display_name from public.profiles
    where id = '00000000-0000-0000-0000-000000000401') = 'Max', 'the first keeps it';
  assert (select display_name from public.profiles
    where id = '00000000-0000-0000-0000-000000000402') = 'MAX 3', 'Max 2 is held';
  assert (select display_name from public.profiles
    where id = '00000000-0000-0000-0000-000000000403') = 'Max 2', 'not a duplicate';
  assert (select display_name from public.profiles
    where id = '00000000-0000-0000-0000-000000000404') = 'm.a.x 4';
  assert (select display_name from public.profiles
    where id = '00000000-0000-0000-0000-000000000ee4') = 'abcdefghijklmnopqrstuvwxyzab 2',
    'cut to 30 characters';
  assert public.resolve_duplicate_display_names() = 0, 'nothing left to do';
  create unique index profiles_display_name_folded
    on public.profiles (public.fold_display_name(display_name))
    where display_name is not null;
end;
$$;
rollback;

-- A deleted player's duels stay in the opponent's history.
insert into public.profiles (id, display_name) values
  ('00000000-0000-0000-0000-000000000ee4', 'Gone Soon');
insert into public.duels (id, mode, kind, config, first_player, second_player, state, result,
  rated, finished_at, expires_at, opened_at, created_at) values
  ('00000000-0000-0000-0000-00000000ef01', 'basics', 'pool', '{"seed": 1}',
   '00000000-0000-0000-0000-000000000ee4', '00000000-0000-0000-0000-000000000ee1',
   'done', 1, true, now() - interval '1 hour', null, null, now() - interval '2 hours'),
  ('00000000-0000-0000-0000-00000000ef02', 'basics', 'pool', '{"seed": 2}',
   '00000000-0000-0000-0000-000000000ee1', '00000000-0000-0000-0000-000000000ee4',
   'awaitingSecond', null, false, null, null, null, now() - interval '1 hour'),
  ('00000000-0000-0000-0000-00000000ef03', 'advanced', 'challenge', '{"seed": 3}',
   '00000000-0000-0000-0000-000000000ee4', '00000000-0000-0000-0000-000000000ee1',
   'awaitingFirst', null, false, null, now() + interval '6 days', null, now()),
  -- Opened three days before its opening date passed, 10 hours ago: still
  -- waiting for its 24 hours to play.
  ('00000000-0000-0000-0000-00000000ef04', 'count', 'challenge', '{"seed": 4}',
   '00000000-0000-0000-0000-000000000ee2', '00000000-0000-0000-0000-000000000ee1',
   'awaitingSecond', null, false, null, now() - interval '1 hour',
   now() - interval '10 hours', now() - interval '7 days');
insert into public.duel_runs (duel_id, player_id, mode, config, payload, lane, score) values
  ('00000000-0000-0000-0000-00000000ef01', '00000000-0000-0000-0000-000000000ee4', 'basics',
   '{"seed": 1}', '{"answers": []}', '{"answers": []}', '{"points": 2, "ms": 1}');
insert into public.duel_ratings (player_id, mode, rating, deviation, volatility) values
  ('00000000-0000-0000-0000-000000000ee4', 'basics', 1500, 200, 0.06);

delete from auth.users where id = '00000000-0000-0000-0000-000000000ee4';
do $$
begin
  assert (select (first_player, second_player, state, result) is not distinct from
      (null::uuid, '00000000-0000-0000-0000-000000000ee1'::uuid, 'done', 1::double precision)
    from public.duels where id = '00000000-0000-0000-0000-00000000ef01'), 'the duel stays';
  assert not exists (select from public.duel_runs
    where player_id = '00000000-0000-0000-0000-000000000ee4'), 'their runs go';
  assert not exists (select from public.duel_ratings
    where player_id = '00000000-0000-0000-0000-000000000ee4'), 'their ratings go';
  assert not exists (select from public.profiles
    where id = '00000000-0000-0000-0000-000000000ee4'), 'their profile goes';
end;
$$;

-- Open duels left with nobody to play them are voided by the next sweep.
set role service_role;
do $$
begin
  assert public.duel_abandoned(10) = '[]'::jsonb, 'never listed';
end;
$$;
reset role;
do $$
begin
  assert (select state from public.duels where id = '00000000-0000-0000-0000-00000000ef02') = 'void';
  assert (select state from public.duels where id = '00000000-0000-0000-0000-00000000ef03') = 'void';
end;
$$;

-- The opponent sees "Deleted player"; the challenge opened in time waits.
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000ee1', false);
do $$
declare
  overview jsonb := public.duel_overview();
  entry jsonb;
begin
  select e into entry from jsonb_array_elements(overview -> 'recent') e
  where e ->> 'duelId' = '00000000-0000-0000-0000-00000000ef01';
  assert entry ->> 'opponent' = 'Deleted player', 'recent: ' || entry;
  assert entry -> 'opponentId' = 'null'::jsonb;
  assert (overview -> 'waiting' -> 0 ->> 'duelId') = '00000000-0000-0000-0000-00000000ef04',
    'an opened challenge past its opening date still waits: ' || (overview -> 'waiting');
  assert (overview -> 'waiting' -> 0 ->> 'from') = 'Lili Roses';
end;
$$;
reset role;
select set_config('request.jwt.claim.sub', '', false);

-- A practice duel still has no first player.
do $$
begin
  insert into public.duels (id, mode, kind, config, first_player, second_player, state)
  values ('00000000-0000-0000-0000-00000000ef09', 'basics', 'practice', '{}',
    '00000000-0000-0000-0000-000000000ee2', '00000000-0000-0000-0000-000000000ee1',
    'awaitingSecond');
  raise exception 'a practice duel with a first player';
exception when check_violation then null;
end;
$$;
