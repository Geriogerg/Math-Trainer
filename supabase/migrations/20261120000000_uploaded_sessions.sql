-- Uploaded sessions (Phase 2 commit 5): every session a player's app sends,
-- stored once, idempotent on the session id. Written only by the server
-- (service role, through record_session_upload); nobody reads it through
-- the API: row-level security on, no policy.

create table if not exists public.uploaded_sessions (
  id uuid primary key,
  player_id uuid not null references auth.users (id) on delete cascade,
  -- The session's own time (the player's clock), and when it arrived.
  created_at timestamptz not null,
  received_at timestamptz not null default now(),
  kind text not null,
  -- The whole upload as sent (session and answers), for replay and audit.
  payload jsonb not null
);

create index if not exists uploaded_sessions_player_created
  on public.uploaded_sessions (player_id, created_at);

alter table public.uploaded_sessions enable row level security;

-- Supabase grants the API roles everything on new tables by default:
-- take it back, the service role is the only writer and reader.
revoke all on table public.uploaded_sessions from anon, authenticated;

-- Stores the session unless its id is known. Answers one row:
--   outcome 'inserted' | 'duplicate' (same id, same player: already
--   stored — the app may resend after a lost answer) | 'conflict' (the id
--   belongs to another player's session), and the stored received_at.
create or replace function public.record_session_upload(
  p_session_id uuid,
  p_player_id uuid,
  p_created_at timestamptz,
  p_kind text,
  p_payload jsonb
)
returns table (outcome text, received_at timestamptz)
language plpgsql
security invoker
set search_path = ''
as $$
declare
  existing_player uuid;
  existing_received timestamptz;
begin
  insert into public.uploaded_sessions as s
    (id, player_id, created_at, kind, payload)
  values (p_session_id, p_player_id, p_created_at, p_kind, p_payload)
  on conflict (id) do nothing;

  if found then
    return query
      select 'inserted'::text, s.received_at
      from public.uploaded_sessions s where s.id = p_session_id;
    return;
  end if;

  select s.player_id, s.received_at into existing_player, existing_received
  from public.uploaded_sessions s where s.id = p_session_id;
  if existing_player = p_player_id then
    return query select 'duplicate'::text, existing_received;
  else
    return query select 'conflict'::text, existing_received;
  end if;
end;
$$;

revoke all on function public.record_session_upload(uuid, uuid, timestamptz, text, jsonb)
  from public, anon, authenticated;
grant execute on function public.record_session_upload(uuid, uuid, timestamptz, text, jsonb)
  to service_role;
