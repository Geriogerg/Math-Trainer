-- Server-side gate (Phase 5.1 commit 5): who may upload as an anonymous
-- player. The server's side is tested in server/test/session_endpoint_test.dart.

delete from auth.users;
delete from public.beta_codes;
insert into auth.users (id, is_anonymous) values
  ('00000000-0000-0000-0000-0000000000f1', true),  -- redeemed a code
  ('00000000-0000-0000-0000-0000000000f2', true),  -- played before the gate
  ('00000000-0000-0000-0000-0000000000f3', true);  -- neither
insert into public.beta_codes (code, label, max_uses) values ('GATE1', 'Tester', 5);
insert into public.beta_code_uses (player_id, code) values
  ('00000000-0000-0000-0000-0000000000f1', 'GATE1');
insert into public.uploaded_sessions (id, player_id, created_at, kind, payload, completed) values
  (gen_random_uuid(), '00000000-0000-0000-0000-0000000000f2', now() - interval '3 days', 'game', '{}', true);

set role service_role;
do $$
begin
  assert public.upload_allowed('00000000-0000-0000-0000-0000000000f1'), 'a code';
  assert public.upload_allowed('00000000-0000-0000-0000-0000000000f2'), 'already in';
  assert not public.upload_allowed('00000000-0000-0000-0000-0000000000f3'), 'neither';
  assert not public.upload_allowed('00000000-0000-0000-0000-0000000000ff'), 'unknown player';
end;
$$;
reset role;

-- Players cannot ask (nor learn who has a code).
do $$
begin
  assert not has_function_privilege('anon', 'public.upload_allowed(uuid)', 'execute'), 'anon';
  assert not has_function_privilege('authenticated', 'public.upload_allowed(uuid)', 'execute'),
    'authenticated';
  assert has_function_privilege('service_role', 'public.upload_allowed(uuid)', 'execute'),
    'service role';
end;
$$;
