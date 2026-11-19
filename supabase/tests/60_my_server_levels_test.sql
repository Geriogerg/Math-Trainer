-- A player reads their own server levels, nobody else's (Phase 3a commit 2).

insert into auth.users (id, is_anonymous) values
  ('00000000-0000-0000-0000-0000000000e1', true),
  ('00000000-0000-0000-0000-0000000000e2', false);

set role service_role;
do $$
declare
  r record;
begin
  select * into r from public.apply_validated_session(
    '60000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-0000000000e1',
    0, '2026-11-21T10:00:00Z', 'game', true, '{}',
    '{"addition": {"level": 1234, "sessionsPlayed": 4, "updatedAt": "2026-11-21T10:00:00Z"},
      "division": {"level": 567, "sessionsPlayed": 1, "updatedAt": "2026-11-21T10:00:00Z"}}',
    array[]::text[]);
  assert r.outcome = 'applied', 'setup: ' || r.outcome;
end;
$$;
reset role;

-- The owner of the levels.
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000e1', false);
do $$
declare
  levels jsonb := public.my_server_levels();
begin
  assert (levels #>> '{addition,level}')::int = 1234, 'own level: ' || levels::text;
  assert (levels #>> '{addition,sessionsPlayed}')::int = 4, 'own count';
  assert (levels #>> '{addition,updatedAt}')::timestamptz = '2026-11-21T10:00:00Z', 'own time';
  assert (levels #>> '{division,level}')::int = 567, 'second type';
  assert (select count(*) from jsonb_object_keys(levels)) = 2, 'only played types';
end;
$$;

-- Another player: their own (none), never the first one's.
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000e2', false);
do $$
begin
  assert public.my_server_levels() = '{}'::jsonb, 'saw another player''s levels';
end;
$$;
select set_config('request.jwt.claim.sub', '', false);
reset role;

-- No session: not callable.
set role anon;
do $$
begin
  perform public.my_server_levels();
  assert false, 'anon called my_server_levels';
exception when insufficient_privilege then
  null;
end;
$$;
reset role;
