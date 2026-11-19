-- Stale guest cleanup (Phase 2 commit 11): only guests idle on every count.

insert into auth.users (id, is_anonymous, created_at) values
  -- Stale: old guest, nothing uploaded, no session renewed for 40 days.
  ('00000000-0000-0000-0000-0000000003a1', true, now() - interval '90 days'),
  -- Uploaded 5 days ago: kept.
  ('00000000-0000-0000-0000-0000000003a2', true, now() - interval '90 days'),
  -- Never uploaded (no server yet) but opened the app 2 days ago: kept.
  ('00000000-0000-0000-0000-0000000003a3', true, now() - interval '90 days'),
  -- A new guest (10 days old), idle: kept until 30 days.
  ('00000000-0000-0000-0000-0000000003a4', true, now() - interval '10 days'),
  -- A linked player, idle for months: never touched.
  ('00000000-0000-0000-0000-0000000003a5', false, now() - interval '200 days');

insert into auth.sessions (user_id, created_at, updated_at, refreshed_at) values
  ('00000000-0000-0000-0000-0000000003a1', now() - interval '90 days', now() - interval '40 days', (now() - interval '40 days') at time zone 'UTC'),
  ('00000000-0000-0000-0000-0000000003a3', now() - interval '90 days', now() - interval '60 days', (now() - interval '2 days') at time zone 'UTC'),
  ('00000000-0000-0000-0000-0000000003a5', now() - interval '200 days', now() - interval '200 days', null);

insert into public.uploaded_sessions (id, player_id, created_at, received_at, kind, payload)
values
  (gen_random_uuid(), '00000000-0000-0000-0000-0000000003a1', now() - interval '80 days', now() - interval '80 days', 'game', '{}'),
  (gen_random_uuid(), '00000000-0000-0000-0000-0000000003a2', now() - interval '5 days', now() - interval '5 days', 'game', '{}');

do $$
declare
  deleted integer := public.cleanup_stale_guests();
begin
  assert deleted = 1, 'deleted ' || deleted;
  assert not exists (select from auth.users where id = '00000000-0000-0000-0000-0000000003a1'),
    'stale guest kept';
  assert not exists (select from public.uploaded_sessions
    where player_id = '00000000-0000-0000-0000-0000000003a1'), 'its uploads kept';
  assert (select count(*) from auth.users where id in (
    '00000000-0000-0000-0000-0000000003a2', '00000000-0000-0000-0000-0000000003a3',
    '00000000-0000-0000-0000-0000000003a4', '00000000-0000-0000-0000-0000000003a5')) = 4,
    'an active guest or a linked player was deleted';
  assert public.cleanup_stale_guests() = 0, 'a second run deleted more';
end;
$$;

-- Players cannot run it.
set role authenticated;
do $$
begin
  begin
    perform public.cleanup_stale_guests();
    raise exception 'a player ran the cleanup';
  exception when insufficient_privilege then null;
  end;
end;
$$;
reset role;
