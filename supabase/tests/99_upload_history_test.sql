-- Phase 4 close-out commit 3: a player's accepted payloads, oldest first,
-- for the server's weak-spot check; nobody else's; service role only.

delete from auth.users;
-- Duels outlive their players (Phase 6a: "Deleted player"): cleared here.
delete from public.duels;
insert into auth.users (id, is_anonymous) values
  ('00000000-0000-0000-0000-0000000000a1', true),
  ('00000000-0000-0000-0000-0000000000a2', true);
insert into public.uploaded_sessions (id, player_id, created_at, kind, payload, completed) values
  ('00000000-0000-0000-0000-00000000b002', '00000000-0000-0000-0000-0000000000a1',
   '2026-11-24 10:00+00', 'game', '{"n": 2}', true),
  ('00000000-0000-0000-0000-00000000b001', '00000000-0000-0000-0000-0000000000a1',
   '2026-11-23 10:00+00', 'game', '{"n": 1}', true),
  ('00000000-0000-0000-0000-00000000b003', '00000000-0000-0000-0000-0000000000a2',
   '2026-11-22 10:00+00', 'game', '{"n": 9}', true);

set role service_role;
do $$
begin
  assert public.player_upload_history('00000000-0000-0000-0000-0000000000a1')
    = '[{"n": 1}, {"n": 2}]'::jsonb, 'oldest first, the player''s only';
  assert public.player_upload_history('00000000-0000-0000-0000-0000000000ff')
    = '[]'::jsonb, 'none: empty';
end;
$$;
reset role;

do $$
begin
  assert not has_function_privilege('anon', 'public.player_upload_history(uuid)', 'execute'), 'anon';
  assert not has_function_privilege('authenticated', 'public.player_upload_history(uuid)', 'execute'),
    'authenticated';
  assert has_function_privilege('service_role', 'public.player_upload_history(uuid)', 'execute'),
    'service role';
end;
$$;
