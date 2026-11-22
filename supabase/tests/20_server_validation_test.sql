-- The server's write path (Phase 2 commit 6): state read, a validated
-- session applied atomically with its levels and flags, optimistic version,
-- idempotence, rejections — and none of it reachable by players.

insert into auth.users (id, is_anonymous) values
  ('00000000-0000-0000-0000-0000000000c1', true),
  ('00000000-0000-0000-0000-0000000000c2', true);

set role service_role;
do $$
declare
  state jsonb;
  r record;
  first_at timestamptz;
begin
  -- A new player: version 0, nothing else.
  state := public.player_server_state('00000000-0000-0000-0000-0000000000c1');
  assert (state ->> 'version')::int = 0, 'new player version: ' || state::text;
  assert state -> 'levels' = '{}'::jsonb, 'new player levels';
  assert (state ->> 'hasCompletedSession')::boolean = false, 'new player completed';

  select * into r from public.apply_validated_session(
    '10000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-0000000000c1',
    0, '2026-11-20T10:00:00Z', 'game', true, '{"a": 1}',
    '{"addition": {"level": 342, "sessionsPlayed": 1, "updatedAt": "2026-11-20T10:00:00Z"}}',
    array['flatTimes']);
  assert r.outcome = 'applied', 'first apply: ' || r.outcome;
  first_at := r.received_at;

  state := public.player_server_state('00000000-0000-0000-0000-0000000000c1');
  assert (state ->> 'version')::int = 1, 'version not bumped';
  assert (state #>> '{levels,addition,level}')::int = 342, 'level not written';
  assert (state #>> '{levels,addition,sessionsPlayed}')::int = 1, 'count not written';
  assert (state ->> 'hasCompletedSession')::boolean, 'completed not recorded';
  assert (state ->> 'lastSessionAt')::timestamptz = '2026-11-20T10:00:00Z', 'last session';
  assert exists (select from public.upload_flags
    where session_id = '10000000-0000-0000-0000-000000000001' and flag = 'flatTimes'),
    'flag not stored';

  -- Validated against version 0 while the player moved on: stale, nothing written.
  select * into r from public.apply_validated_session(
    '10000000-0000-0000-0000-000000000002',
    '00000000-0000-0000-0000-0000000000c1',
    0, '2026-11-20T10:05:00Z', 'game', true, '{}',
    '{"addition": {"level": 999, "sessionsPlayed": 2, "updatedAt": "2026-11-20T10:05:00Z"}}',
    array[]::text[]);
  assert r.outcome = 'stale', 'stale apply: ' || r.outcome;
  assert (select level from public.server_levels
    where player_id = '00000000-0000-0000-0000-0000000000c1') = 342, 'stale write leaked';

  -- The first one resent: a duplicate, same time; another player: conflict.
  select * into r from public.apply_validated_session(
    '10000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-0000000000c1',
    1, '2026-11-20T10:00:00Z', 'game', true, '{"a": 1}', '{}', array[]::text[]);
  assert r.outcome = 'duplicate' and r.received_at = first_at, 'resend: ' || r.outcome;
  select * into r from public.apply_validated_session(
    '10000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-0000000000c2',
    0, '2026-11-20T10:00:00Z', 'game', true, '{}', '{}', array[]::text[]);
  assert r.outcome = 'conflict', 'other player: ' || r.outcome;

  -- An interrupted session: stored, levels and "completed" untouched.
  select * into r from public.apply_validated_session(
    '10000000-0000-0000-0000-000000000003',
    '00000000-0000-0000-0000-0000000000c2',
    0, '2026-11-20T11:00:00Z', 'game', false, '{}', '{}', array[]::text[]);
  assert r.outcome = 'applied', 'interrupted: ' || r.outcome;
  state := public.player_server_state('00000000-0000-0000-0000-0000000000c2');
  assert not (state ->> 'hasCompletedSession')::boolean, 'interrupted counted as completed';

  -- A rejection, recorded once; upload_status tells both kinds apart.
  perform public.record_rejected_upload(
    '10000000-0000-0000-0000-000000000004',
    '00000000-0000-0000-0000-0000000000c1', 'levelsMismatch', 'x', '{}');
  perform public.record_rejected_upload(
    '10000000-0000-0000-0000-000000000004',
    '00000000-0000-0000-0000-0000000000c1', 'other', 'y', '{}');
  select * into r from public.upload_status('10000000-0000-0000-0000-000000000004');
  assert r.state = 'rejected' and r.reason = 'levelsMismatch', 'rejection status';
  select * into r from public.upload_status('10000000-0000-0000-0000-000000000001');
  assert r.state = 'accepted', 'accepted status';
  assert not exists (select from public.upload_status('10000000-0000-0000-0000-00000000ffff')),
    'unknown id has a status';
end;
$$;
reset role;

-- Players reach none of it.
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000c1', false);
do $$
begin
  begin
    perform public.player_server_state('00000000-0000-0000-0000-0000000000c1');
    raise exception 'a player read the server state';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.apply_validated_session(
      '10000000-0000-0000-0000-000000000009',
      '00000000-0000-0000-0000-0000000000c1',
      1, now(), 'game', true, '{}', '{}', array[]::text[]);
    raise exception 'a player applied a session';
  exception when insufficient_privilege then null;
  end;
  begin
    perform 1 from public.server_levels;
    raise exception 'a player read server_levels directly';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into public.server_levels values
      ('00000000-0000-0000-0000-0000000000c1', 'addition', 10000, 1, now());
    raise exception 'a player wrote a level';
  exception when insufficient_privilege then null;
  end;
end;
$$;
reset role;

-- Deleting the account deletes everything the server holds for it.
delete from auth.users where id = '00000000-0000-0000-0000-0000000000c1';
do $$
begin
  assert not exists (select from public.server_levels
    where player_id = '00000000-0000-0000-0000-0000000000c1'), 'levels survived';
  assert not exists (select from public.server_players
    where player_id = '00000000-0000-0000-0000-0000000000c1'), 'state survived';
  assert not exists (select from public.uploaded_sessions
    where player_id = '00000000-0000-0000-0000-0000000000c1'), 'uploads survived';
  assert not exists (select from public.upload_rejections
    where player_id = '00000000-0000-0000-0000-0000000000c1'), 'rejections survived';
end;
$$;

-- The rules version (Levels phase commit 0) is read from the payload:
-- absent = 1.
do $$
begin
  insert into public.uploaded_sessions (id, player_id, created_at, kind, payload, completed)
  values
    ('10000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000c2',
     '2026-11-25T10:00:00Z', 'game', '{"session": {"rulesVersion": 2}}', true),
    ('10000000-0000-0000-0000-0000000000f2', '00000000-0000-0000-0000-0000000000c2',
     '2026-11-25T10:00:00Z', 'game', '{"session": {}}', true);
  assert (select rules_version from public.uploaded_sessions
          where id = '10000000-0000-0000-0000-0000000000f1') = 2, 'rules v2';
  assert (select rules_version from public.uploaded_sessions
          where id = '10000000-0000-0000-0000-0000000000f2') = 1, 'absent = v1';
  delete from public.uploaded_sessions
  where id in ('10000000-0000-0000-0000-0000000000f1', '10000000-0000-0000-0000-0000000000f2');
end;
$$;
