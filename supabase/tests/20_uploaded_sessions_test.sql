-- record_session_upload (Phase 2 commit 5): idempotent on the id, a
-- conflict for another player's id, callable by the service role only.

insert into auth.users (id, is_anonymous) values
  ('00000000-0000-0000-0000-0000000000c1', true),
  ('00000000-0000-0000-0000-0000000000c2', true);

set role service_role;
do $$
declare
  first_at timestamptz;
  r record;
begin
  select * into r from public.record_session_upload(
    '10000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-0000000000c1',
    '2026-11-20T10:00:00Z', 'game', '{"a": 1}');
  assert r.outcome = 'inserted', 'first upload: ' || r.outcome;
  first_at := r.received_at;

  -- Sent again (the app lost the first answer): same row, same time.
  select * into r from public.record_session_upload(
    '10000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-0000000000c1',
    '2026-11-20T10:00:00Z', 'game', '{"a": 1}');
  assert r.outcome = 'duplicate', 'resend: ' || r.outcome;
  assert r.received_at = first_at, 'resend changed received_at';

  -- The same id from another player: refused, nothing overwritten.
  select * into r from public.record_session_upload(
    '10000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-0000000000c2',
    '2026-11-20T10:00:00Z', 'game', '{"b": 2}');
  assert r.outcome = 'conflict', 'other player: ' || r.outcome;
  assert (select payload from public.uploaded_sessions
          where id = '10000000-0000-0000-0000-000000000001') = '{"a": 1}',
    'payload overwritten';
end;
$$;
reset role;

-- Players can neither call it nor read the table.
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000c1', false);
do $$
begin
  begin
    perform public.record_session_upload(
      '10000000-0000-0000-0000-000000000002',
      '00000000-0000-0000-0000-0000000000c1',
      now(), 'game', '{}');
    raise exception 'a player called record_session_upload';
  exception when insufficient_privilege then
    null;
  end;
  begin
    perform 1 from public.uploaded_sessions;
    raise exception 'a player read uploaded_sessions';
  exception when insufficient_privilege then
    null;
  end;
end;
$$;
reset role;

-- Deleting the account deletes its uploads (cascade).
delete from auth.users where id = '00000000-0000-0000-0000-0000000000c1';
do $$
begin
  assert not exists (select from public.uploaded_sessions
    where player_id = '00000000-0000-0000-0000-0000000000c1'),
    'uploads survived the account';
end;
$$;
