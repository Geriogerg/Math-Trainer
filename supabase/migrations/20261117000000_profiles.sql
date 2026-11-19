-- Public profiles table (player name) — step 6, slice 2.
-- First migration (Phase 2 commit 2): it was run by hand before migrations
-- existed, so it stays idempotent — applying it to the live project, where
-- the table already exists, changes nothing.
--
-- No creation trigger at sign-up: the row is created by the first chosen
-- name (`upsert` in SupabaseProfileRepository), and a missing profile reads
-- as "no name chosen" (`maybeSingle`).

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text check (char_length(display_name) between 1 and 30),
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

-- Policies were first created under French names (before 18 Nov 2026);
-- dropped here so a re-run leaves only the English ones.
drop policy if exists "profiles lisibles par tous" on public.profiles;
drop policy if exists "profil créé par son propriétaire" on public.profiles;
drop policy if exists "profil modifié par son propriétaire" on public.profiles;

-- Public read: the leaderboard (Phase 2) shows other players' names. `anon`
-- included so that simply viewing a leaderboard needs no session.
drop policy if exists "profiles readable by everyone" on public.profiles;
create policy "profiles readable by everyone"
  on public.profiles for select
  to anon, authenticated
  using (true);

-- Writes restricted to one's own profile. `upsert` needs insert AND update.
drop policy if exists "profile created by its owner" on public.profiles;
create policy "profile created by its owner"
  on public.profiles for insert
  to authenticated
  with check ((select auth.uid()) = id);

drop policy if exists "profile updated by its owner" on public.profiles;
create policy "profile updated by its owner"
  on public.profiles for update
  to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);
