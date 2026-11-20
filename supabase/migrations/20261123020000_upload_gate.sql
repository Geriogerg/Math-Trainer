-- Server-side gate enforcement (Phase 5.1 commit 5, plan v2.6; a
-- prerequisite of Phase 6): the app's beta gate is a screen, and the
-- server's upload endpoint is reachable without it. The server asks this
-- before storing an anonymous player's session (linked accounts are never
-- asked): allowed when the player redeemed an invitation code, or already
-- has an accepted session — the testers already in, whatever their path
-- (before the gate existed, or a code redeemed on another device).
--
-- Service role only, like the server's other functions. Idempotent.

create or replace function public.upload_allowed(p_player_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select from public.beta_code_uses where player_id = p_player_id)
      or exists (select from public.uploaded_sessions where player_id = p_player_id);
$$;

revoke all on function public.upload_allowed(uuid) from public, anon, authenticated;
grant execute on function public.upload_allowed(uuid) to service_role;
