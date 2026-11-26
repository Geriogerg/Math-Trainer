-- Phase 6a commit 2 (plan v3.9; review B4): refusals stored as a digest and
-- capped per player per day; the daily counts the server reads.

delete from auth.users;
insert into auth.users (id, is_anonymous) values
  ('00000000-0000-0000-0000-000000000fa1', true),
  ('00000000-0000-0000-0000-000000000fa2', false);
delete from public.upload_rejections;

set role service_role;
do $$
declare
  p1 constant uuid := '00000000-0000-0000-0000-000000000fa1';
  p2 constant uuid := '00000000-0000-0000-0000-000000000fa2';
  -- About 250 KB that does not compress away: what a crafted upload sends.
  big constant jsonb := jsonb_build_object('session', jsonb_build_object('id', 'x'),
    'junk', (select string_agg(md5(i::text), '') from generate_series(1, 7800) i));
  digest jsonb;
  kept record;
begin
  assert octet_length(big::text) > 240000;

  -- The digest: the hash, the size, the first 1,000 characters; applied
  -- twice it changes nothing.
  digest := public.refusal_digest(big);
  assert digest ->> 'sha256' ~ '^[0-9a-f]{64}$', 'a SHA-256';
  assert (digest ->> 'bytes')::integer = octet_length(big::text);
  assert length(digest ->> 'head') = 1000;
  assert digest ->> 'head' = left(big::text, 1000);
  assert public.refusal_digest(digest) = digest, 'already a digest';
  assert public.refusal_digest('{"a": 1}') ->> 'head' = '{"a": 1}', 'a small payload whole';
  assert public.refusal_digest(big || '{"z": 1}') ->> 'sha256' <> digest ->> 'sha256';

  -- 60 crafted refusals from one player: 50 kept, each about 1 KB.
  for i in 1..60 loop
    perform public.record_rejected_upload(gen_random_uuid(), p1, 'badRequest',
      repeat('d', 5000), big);
  end loop;
  select count(*) as n, max(pg_column_size(r.payload)) as widest,
    max(length(r.detail)) as detail
  into kept from public.upload_rejections r where r.player_id = p1;
  assert kept.n = public.refusals_kept_per_day() and kept.n = 50, kept.n || ' kept';
  assert kept.widest < 1400, 'a digest, not the payload: ' || kept.widest || ' bytes';
  assert kept.detail = 500, 'the detail is cut too';
  -- Another player is not affected; the same id twice is stored once.
  perform public.record_rejected_upload('00000000-0000-0000-0000-00000000fb01', p2,
    'levelsMismatch', null, '{"session": {"id": "s"}}');
  perform public.record_rejected_upload('00000000-0000-0000-0000-00000000fb01', p2,
    'badRequest', null, '{}');
  assert (select reason from public.upload_rejections
    where session_id = '00000000-0000-0000-0000-00000000fb01') = 'levelsMismatch';
  assert (select state from public.upload_status('00000000-0000-0000-0000-00000000fb01'))
    = 'rejected', 'a kept refusal still answers a resend';
end;
$$;
reset role;

-- A rolling 24 hours: yesterday's refusals no longer count.
update public.upload_rejections set received_at = now() - interval '25 hours'
where player_id = '00000000-0000-0000-0000-000000000fa1';
set role service_role;
do $$
declare
  p1 constant uuid := '00000000-0000-0000-0000-000000000fa1';
begin
  perform public.record_rejected_upload(gen_random_uuid(), p1, 'badRequest', null, '{}');
  assert (select count(*) from public.upload_rejections where player_id = p1) = 51;
end;
$$;
reset role;

-- The whole table for all of the above: far from 60 × 250 KB.
do $$
begin
  assert pg_total_relation_size('public.upload_rejections') < 400000,
    pg_total_relation_size('public.upload_rejections') || ' bytes for 52 refusals';
end;
$$;

-- Refused duel runs: a digest as well.
insert into public.duels (id, mode, kind, config, first_player, second_player, state, expires_at)
values
  ('00000000-0000-0000-0000-00000000fc01', 'basics', 'challenge', '{}',
   '00000000-0000-0000-0000-000000000fa2', '00000000-0000-0000-0000-000000000fa1',
   'awaitingFirst', now() + interval '6 days'),
  ('00000000-0000-0000-0000-00000000fc02', 'basics', 'practice', '{}',
   null, '00000000-0000-0000-0000-000000000fa2', 'awaitingSecond', null);
set role service_role;
do $$
declare
  p1 constant uuid := '00000000-0000-0000-0000-000000000fa1';
  p2 constant uuid := '00000000-0000-0000-0000-000000000fa2';
  big constant jsonb := jsonb_build_object('answers',
    (select jsonb_agg(md5(i::text)) from generate_series(1, 1800) i));
  state jsonb;
begin
  perform public.record_duel_run_refused('00000000-0000-0000-0000-00000000fc01', p2,
    'badElapsed', repeat('d', 900), big);
  perform public.record_duel_run_forfeit('00000000-0000-0000-0000-00000000fc02', p2,
    'wrongShape', 'x', big);
  assert (select bool_and(x.payload ? 'sha256' and pg_column_size(x.payload) < 1400
      and length(x.detail) <= 500)
    from public.duel_run_rejections x where x.player_id = p2), 'digests';
  assert (select count(*) from public.duel_run_rejections where player_id = p2) = 2;
  assert (select d.state from public.duels d where d.id = '00000000-0000-0000-0000-00000000fc01')
    = 'void', 'a challenger''s refused run still voids the challenge';

  -- duelsToday: the practice duel handed to p2 and the challenge p2 sent;
  -- the challenge p1 received is not one p1 asked for.
  assert (public.duel_player(p2, 'basics') ->> 'duelsToday')::integer = 2;
  assert (public.duel_player(p1, 'basics') ->> 'duelsToday')::integer = 0;

  -- acceptedToday: sessions received over the last 24 hours.
  state := public.player_server_state(p1);
  assert (state ->> 'acceptedToday')::integer = 0;
  assert state ? 'version' and state ? 'levels', 'the rest of the state as before';
end;
$$;
reset role;

insert into public.uploaded_sessions (id, player_id, created_at, received_at, kind, payload)
select gen_random_uuid(), '00000000-0000-0000-0000-000000000fa1', now(),
  now() - (i || ' hours')::interval, 'game', '{}'
from generate_series(1, 30) i;
do $$
begin
  assert (public.player_server_state('00000000-0000-0000-0000-000000000fa1')
    ->> 'acceptedToday')::integer = 23, 'hours 1 to 23';
  assert not has_function_privilege('authenticated', 'public.refusal_digest(jsonb)', 'execute');
end;
$$;

-- The phase's exit test: 2,000 crafted refusals of about 250 KB each (fresh
-- ids, 40 accounts — one account alone keeps 50) store under 5 MB. Before
-- Phase 6a they stored about 500 MB (measured: doc/progress.md).
delete from public.upload_rejections;
insert into auth.users (id, is_anonymous)
select ('00000000-0000-0000-0000-0000000e' || lpad(i::text, 4, '0'))::uuid, true
from generate_series(1, 40) i;
set role service_role;
do $$
declare
  big constant jsonb := jsonb_build_object('junk',
    (select string_agg(md5(i::text), '') from generate_series(1, 7800) i));
begin
  for i in 0..1999 loop
    perform public.record_rejected_upload(gen_random_uuid(),
      ('00000000-0000-0000-0000-0000000e' || lpad((1 + i % 40)::text, 4, '0'))::uuid,
      'badRequest', 'crafted', big || jsonb_build_object('n', i));
  end loop;
end;
$$;
reset role;
do $$
declare
  stored bigint := pg_total_relation_size('public.upload_rejections');
begin
  assert (select count(*) from public.upload_rejections) = 2000;
  assert stored < 5 * 1024 * 1024, '2,000 crafted refusals store ' || stored || ' bytes';
  raise warning '2,000 crafted refusals of ~250 KB store % bytes', stored;
end;
$$;
delete from public.upload_rejections;
