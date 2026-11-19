-- Phase 3a commit 2 (plan v2.3): the app reads its own server levels before
-- each game, so a second device starts from them and its games chain
-- instead of being refused (`levelsMismatch`).
--
-- Read straight from Supabase, like the leaderboard: the Dart server may be
-- asleep (Render free plan) and a game must not wait for it. Only the
-- caller's own rows, from `auth.uid()`; same JSON shape as the server's
-- `player_server_state` levels and the app's `levelCacheFromJson`:
-- {exerciseType: {level, sessionsPlayed, updatedAt}}.
-- Idempotent: re-applying replaces the function with the same definition.

create or replace function public.my_server_levels()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    jsonb_object_agg(l.exercise_type, jsonb_build_object(
      'level', l.level,
      'sessionsPlayed', l.sessions_played,
      'updatedAt', l.updated_at
    )),
    '{}'::jsonb
  )
  from public.server_levels l
  where l.player_id = auth.uid();
$$;

-- Signed-in players only (anonymous ones carry `authenticated` too); a
-- caller without a session has no levels to read.
revoke all on function public.my_server_levels() from public, anon;
grant execute on function public.my_server_levels() to authenticated;
