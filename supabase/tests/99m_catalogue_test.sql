-- Phase 6a commit 7 (plan v3.9; review m16): the whole catalogue, checked
-- at once. A new table without row-level security, a table the API roles
-- can touch, or a `security definer` function players can call fails here
-- unless it is added to the lists below on purpose.

do $$
declare
  found text;
  -- What the app calls on Supabase directly (everything else goes through
  -- the Dart server, as service_role).
  callable constant text[] := array[
    'beta_code_status', 'delete_my_account', 'duel_board_around_me', 'duel_board_top',
    'duel_overview', 'friend_history', 'friend_list', 'friend_remove', 'friend_request',
    'friend_requests_incoming', 'friend_respond', 'leaderboard_around_me',
    'leaderboard_top', 'my_account_under_review', 'my_friend_code', 'my_server_levels',
    'new_friend_code', 'redeem_beta_code', 'report_player_name', 'send_feedback'];
  -- Of those, what a visitor not signed in may call.
  callable_signed_out constant text[] := array[
    'beta_code_status', 'duel_board_around_me', 'duel_board_top',
    'leaderboard_around_me', 'leaderboard_top'];
begin
  select string_agg(c.relname, ', ' order by c.relname) into found
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind in ('r', 'p') and not c.relrowsecurity;
  assert found is null, 'tables without row-level security: ' || found;

  -- Only `profiles` (its own row, by policy) is reachable as a table.
  select string_agg(c.relname, ', ' order by c.relname) into found
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where n.nspname in ('public', 'owner_dashboard') and c.relkind in ('r', 'p', 'v', 'm')
    and c.relname <> 'profiles'
    and (has_table_privilege('authenticated', c.oid, 'select, insert, update, delete')
      or has_table_privilege('anon', c.oid, 'select, insert, update, delete'));
  assert found is null, 'tables the API roles can touch: ' || found;
  assert not has_table_privilege('anon', 'public.profiles', 'select'), 'profiles to anon';
  assert not has_table_privilege('authenticated', 'public.profiles', 'delete'),
    'profiles deleted by a player (deletion goes through delete_my_account)';

  select string_agg(p.proname, ', ' order by p.proname) into found
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname in ('public', 'owner_dashboard') and p.prosecdef
    and (has_function_privilege('authenticated', p.oid, 'execute')
      or has_function_privilege('anon', p.oid, 'execute'))
    and p.proname <> all (callable);
  assert found is null, 'security definer functions players can call: ' || found;

  select string_agg(p.proname, ', ' order by p.proname) into found
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname in ('public', 'owner_dashboard') and p.prosecdef
    and has_function_privilege('anon', p.oid, 'execute')
    and p.proname <> all (callable_signed_out);
  assert found is null, 'security definer functions callable signed out: ' || found;

  -- The owner's schema is closed to the API roles altogether.
  assert not has_schema_privilege('authenticated', 'owner_dashboard', 'usage')
    and not has_schema_privilege('anon', 'owner_dashboard', 'usage'),
    'owner_dashboard reachable by players';
end;
$$;
