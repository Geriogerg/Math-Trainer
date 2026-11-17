-- Table des profils publics (nom de joueur) — étape 6, tranche 2.
-- À exécuter dans l'éditeur SQL du projet Supabase. Idempotent : peut être
-- relancé sans erreur sur un projet où la table existe déjà.
--
-- Pas de trigger de création à l'inscription : la ligne est créée au premier
-- nom choisi (`upsert` dans SupabaseProfileRepository), et un profil absent
-- se lit comme « aucun nom choisi » (`maybeSingle`).

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text check (char_length(display_name) between 1 and 30),
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

-- Lecture publique : le classement (tranche 3) affichera le nom des autres
-- joueurs. `anon` inclus pour ne pas exiger de session pour un simple
-- affichage de classement.
drop policy if exists "profiles lisibles par tous" on public.profiles;
create policy "profiles lisibles par tous"
  on public.profiles for select
  to anon, authenticated
  using (true);

-- Écriture restreinte à son propre profil. `upsert` exige insert ET update.
drop policy if exists "profil créé par son propriétaire" on public.profiles;
create policy "profil créé par son propriétaire"
  on public.profiles for insert
  to authenticated
  with check ((select auth.uid()) = id);

drop policy if exists "profil modifié par son propriétaire" on public.profiles;
create policy "profil modifié par son propriétaire"
  on public.profiles for update
  to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);
