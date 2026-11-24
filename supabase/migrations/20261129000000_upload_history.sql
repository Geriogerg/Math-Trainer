-- Phase 4 close-out commit 3 (plan v3.6): the server checks that a
-- Levelling game's weak spots were due, by rebuilding the player's
-- weak-spot schedule from their accepted sessions (math_core's
-- scheduleFromHistory). This hands it those sessions: every accepted
-- upload's payload, oldest first (ties by id, as the app orders them).
-- Read only, service role only; called only for a game holding weak spots.
create or replace function public.player_upload_history(p_player_id uuid)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select coalesce(jsonb_agg(s.payload order by s.created_at, s.id), '[]'::jsonb)
  from public.uploaded_sessions s
  where s.player_id = p_player_id
$$;

revoke all on function public.player_upload_history(uuid) from public, anon, authenticated;
grant execute on function public.player_upload_history(uuid) to service_role;
