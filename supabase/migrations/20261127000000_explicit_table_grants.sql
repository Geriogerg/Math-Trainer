-- Table privileges, granted explicitly (24 Nov 2026). Projects created
-- before late 2026 grant the API roles everything on new tables in
-- `public` by default; newer ones grant nothing. The staging project is
-- newer: the server's functions (plain `language sql`/`plpgsql`, run as
-- the caller, `service_role`) were denied on `uploaded_sessions`, so
-- every upload answered 503; the app's own reads of `profiles` would fail
-- the same way. Production already has these privileges: granting them
-- again changes nothing (idempotent, as CI applies every migration twice).
--
-- Row-level security still decides which rows a role sees; functions
-- declared `security definer` run as their owner and need nothing here.

-- The server (service role), through upload_status, player_server_state,
-- apply_validated_session and record_rejected_upload.
grant select, insert, update on table
  public.uploaded_sessions,
  public.server_players,
  public.server_levels,
  public.upload_rejections,
  public.upload_flags
to service_role;

-- The app: everyone reads names (the leaderboard), a player writes their own
-- (`upsert` = insert + update), under the policies of 20261117000000.
grant select on table public.profiles to anon, authenticated;
grant insert, update on table public.profiles to authenticated;
