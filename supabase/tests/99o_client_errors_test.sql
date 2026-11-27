-- Phase 6c commit 5: the app's error reports — stored by the server's role
-- only, cut, capped per day in all, kept 30 days, never readable by players.

delete from public.client_errors;

do $$
begin
  assert public.record_client_error('flutter', 'Null check operator used on a null value',
    repeat('#0 frame ', 600), 'e5c719e', 'Mozilla/5.0') = 'stored';
  assert (select count(*) from public.client_errors) = 1;
  assert (select length(stack) from public.client_errors) = 4000, 'cut to 4,000';
  assert public.record_client_error('surprise', 'x', null, null, null) = 'stored';
  assert (select kind from public.client_errors where message = 'x') = 'other',
    'an unknown kind is kept as other';
  assert public.record_client_error('zone', repeat('m', 5000), null, null, null) = 'stored';
  assert (select max(length(message)) from public.client_errors) = 1000, 'cut to 1,000';
end;
$$;

-- Older than 30 days: gone at the next report.
update public.client_errors set received_at = now() - interval '31 days'
where message = 'x';
do $$
begin
  assert public.record_client_error('start', 'again', null, null, null) = 'stored';
  assert not exists (select from public.client_errors where message = 'x');
end;
$$;

-- The day's cap, all players together.
insert into public.client_errors (kind, message)
select 'zone', 'flood ' || g from generate_series(1, public.client_errors_per_day()) g;
do $$
declare
  before bigint := (select count(*) from public.client_errors);
begin
  assert public.record_client_error('zone', 'one more', null, null, null) = 'capped';
  assert (select count(*) from public.client_errors) = before, 'nothing stored';
  assert exists (select from owner_dashboard.client_errors where reports >= 1);
end;
$$;

-- Players can neither call it nor read the table.
set role authenticated;
do $$
declare
  refused boolean := false;
begin
  begin
    perform public.record_client_error('zone', 'from a player', null, null, null);
  exception when insufficient_privilege then
    refused := true;
  end;
  assert refused, 'not callable by players';
  refused := false;
  begin
    perform count(*) from public.client_errors;
  exception when insufficient_privilege then
    refused := true;
  end;
  assert refused, 'not readable by players';
end;
$$;
reset role;

delete from public.client_errors;
