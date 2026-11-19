-- In-app feedback (Phase 3a commit 5, plan v2.3): stored server-side with
-- the app version (the build's commit), triaged for the owner in Phase 3b.
-- Players only reach `send_feedback`; the table is read by the owner
-- (dashboard script). Deleted with the account, as the privacy notice says.
-- Idempotent: CI applies every migration twice in its SQL tests.

create table if not exists public.feedback (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null references auth.users (id) on delete cascade,
  message text not null check (char_length(message) between 1 and 2000),
  app_version text not null check (char_length(app_version) between 1 and 40),
  created_at timestamptz not null default now()
);
create index if not exists feedback_player_time on public.feedback (player_id, created_at);

alter table public.feedback enable row level security;
revoke all on public.feedback from anon, authenticated;

-- 'sent', or 'tooMany' past 20 messages in 24 hours (a stuck button or a
-- script, not a tester). Empty or overlong messages are refused by the
-- table's check (the app checks first: `feedbackProblem`).
create or replace function public.send_feedback(p_message text, p_app_version text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller uuid := auth.uid();
begin
  if caller is null then
    raise exception 'not signed in' using errcode = '28000';
  end if;
  if (select count(*) from public.feedback
      where player_id = caller and created_at > now() - interval '24 hours') >= 20 then
    return 'tooMany';
  end if;
  insert into public.feedback (player_id, message, app_version)
  values (caller, btrim(p_message), p_app_version);
  return 'sent';
end;
$$;

revoke all on function public.send_feedback(text, text) from public, anon;
grant execute on function public.send_feedback(text, text) to authenticated;
