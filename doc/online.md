# Mode en ligne — Math Trainer

Comptes, classement général, duels et Elo. **Non chargé automatiquement** — lis-le avant tout
travail touchant aux comptes, au réseau, ou à `infrastructure/backend/` (à venir). Comme les
autres docs de ce dossier, le code fait foi en cas de divergence.

Ce fichier documente une **direction validée**, pas un état livré : rien de ce qui suit n'existe
encore dans le code tant que l'étape 6 n'a pas commencé.

## Phasage

- **Étape 6, tranche 1 (livrée)** — création de compte et connexion (email/mot de passe),
  sans classement ni synchronisation.
- **Étape 6, tranche 2 (courante)** — connexion obligatoire pour utiliser l'app, nom de joueur,
  onglet Progression renommé Profil.
- **Étape 6, tranche 3** — classement solo entre tous les joueurs de l'app, synchronisation des
  réponses, service Dart de validation serveur.
- **Étape 7** — matchs en ligne synchronisés (mêmes questions, en même temps) et Elo. S'appuie
  sur l'infrastructure posée à l'étape 6 sans la refondre.

### Connexion obligatoire (tranche 2) — révision du principe offline-first

Décision explicite de l'utilisateur, qui revient sur « local = source de vérité en solo,
utilisable sans compte » (`CLAUDE.md`, stratégie de données). Nuance importante, confirmée dans
la discussion : **la connexion obligatoire ne veut pas dire réseau obligatoire à chaque
lancement.** Supabase persiste la session localement (comme `TypeSelectionStore`/`ThemeModeStore`
le font déjà pour d'autres préférences) — un joueur déjà connecté au moins une fois retrouve sa
session sans réseau au lancement suivant, et continue de jouer hors ligne normalement. La porte
d'entrée ne bloque que deux cas : aucune session locale n'a jamais existé sur cet appareil, ou le
joueur s'est explicitement déconnecté. Dans ces deux cas seulement, une connexion réseau est
nécessaire pour (re)passer la porte.

### Nom de joueur (tranche 2)

Nouvelle table Postgres `profiles` (`id` référence `auth.users.id`, `display_name`) plutôt que
`user_metadata` sur l'utilisateur Auth : `user_metadata` n'est pas conçu pour être lisible par
les autres joueurs, alors qu'un nom de joueur doit l'être (RLS : lecture publique, écriture
restreinte à son propre profil) — et c'est exactement la table dont la tranche 3 (classement)
aura besoin pour afficher un nom à côté d'un niveau. Domaine : `ProfileRepository` (même schéma
que `AccountRepository`), dans `core/domain/account/`.

Schéma et RLS versionnés dans `supabase/profiles.sql` (idempotent, à exécuter dans l'éditeur
SQL du projet). Pas de trigger de création à l'inscription : la ligne naît au premier nom choisi
(`upsert`), et une ligne absente se lit comme « aucun nom choisi » (`maybeSingle`) — une pièce
mobile de moins côté serveur. Nom limité à 30 caractères (contrainte `check`, même borne dans
le dialogue de saisie).

Cohérent avec `CLAUDE.md` : « pas d'abstraction pour un seul cas d'usage » — l'étape 6 ne
construit pas de scaffolding de matchmaking par anticipation.

## Backend : Supabase

Postgres (agrégations natives pour un classement/ladder — `ORDER BY`, fenêtres, plus adapté
qu'un magasin document pour ce genre de requêtes) et Auth intégrée. Choix déjà pressenti dans
`CLAUDE.md` avant cette étape ; confirmé ici.

**Ne jamais importer le SDK Supabase en dehors de `infrastructure/`** (règle 3, même principe que
`sqflite`/`shared_preferences`) : le domaine ne connaît que des interfaces abstraites.

## Validation serveur : pourquoi pas les Edge Functions Supabase

Règle 1 de `CLAUDE.md` : le cœur métier doit rester « réexécutable côté serveur ». Ça ne concerne
pas que les duels — le classement solo aussi, puisque « les niveaux sont un cache... recalculés
à partir de l'historique des réponses » (stratégie de données, `CLAUDE.md`). Un classement public
qui fait confiance à un niveau envoyé tel quel par le client est trivialement trichable.

Les Edge Functions Supabase tournent en Deno/TypeScript — `core/domain` (Dart pur, zéro
dépendance Flutter, conçu explicitement pour tourner hors de l'app) ne peut pas s'y exécuter tel
quel. Dupliquer `LevelUpdater`/`Scorer` en TypeScript introduirait deux implémentations à
maintenir en synchronisation, exactement ce que la règle 1 cherche à éviter.

**Décision : un petit service Dart dédié** (probablement `package:shelf`, à trancher au moment du
plan concret), hébergé à part (Cloud Run, Fly.io ou équivalent — pas encore choisi), qui réutilise
`core/domain` sans modification pour recalculer niveau et score à partir des réponses soumises.
Supabase reste la source pour l'authentification et le stockage (Postgres), mais n'est jamais
celui qui calcule un niveau — seul le service Dart écrit une entrée de classement validée.

Conséquence structurelle : `core/domain` (ou `core/` entier) devra être extractible par un service
qui n'est pas l'app Flutter. La forme exacte (package Dart pur séparé importé par les deux côtés
via un chemin local, vs monorepo avec un dossier `server/` à côté de `lib/`) est un détail
d'implémentation à trancher dans le plan concret de l'étape 6, pas ici — mais c'est la contrainte
qui doit guider ce choix.

## Flux de données (étape 6)

1. Le joueur joue en solo, exactement comme aujourd'hui — rien ne change dans
   `SessionController`/`SessionRepository` local. Le local reste la source de vérité pour
   l'expérience solo (offline-first, `CLAUDE.md`).
2. En tâche de fond, l'app synchronise les `PersistedAnswer` dont `syncedAt` est encore `null`
   (champ déjà présent dans le modèle, prévu pour ça depuis la règle 6) vers le service de
   validation.
3. Le service Dart rejoue le calcul de niveau (`LevelUpdater`/`LevelCacheOrchestrator`, code
   inchangé) sur l'historique reçu, et écrit le niveau validé dans Postgres.
4. Le classement général lit exclusivement les niveaux validés côté serveur — jamais une valeur
   poussée directement par un client.

## Identité : compte vs `playerId` local

**Le `playerId` est l'id du compte Supabase** (décision du 17/11/2026, qui remplace l'approche
initiale). L'approche initiale gardait l'UUID local de l'appareil (`LocalPlayerIdProvider`) comme
`playerId` et associait le compte à cet id côté serveur — pensée pour un joueur qui jouerait des
semaines en solo avant de créer un compte. La connexion obligatoire (tranche 2) a retiré ce cas,
et l'approche avait un défaut réel : deux comptes sur le même navigateur partageaient niveaux et
historique.

- Dès la connexion, `AuthGate` remplace l'id de l'appareil par l'id du compte
  (`environmentForAccount`) : les écrans ne lisent et n'écrivent jamais que sous le compte.
- Les parties jouées sous l'id de l'appareil (avant ce changement) reviennent au premier compte
  qui s'y connecte (`SessionRepository.transferPlayerData`) : une seule transaction qui réécrit
  `player_id` dans `sessions` et `player_levels` — `answers` suit par `session_id`. Jamais de
  fusion : si le compte a déjà des données sur l'appareil, rien n'est repris.
- Pour la synchro (tranche 3), une ligne locale porte donc directement l'id que vérifiera la RLS
  (`auth.uid()`), sans table d'association.

## Étape 7 (anticipé, pas implémenté)

Direction retenue lors de la discussion :

- **Elo initial depuis le niveau solo** — sous-évalué volontairement, avec un rating provisoire
  (K-factor élevé) sur les premières parties en ligne, qui converge ensuite. Même principe que le
  rating provisoire des échecs (FIDE/chess.com).
- **Matchmaking par bande d'Elo**, élargie si aucun adversaire n'est trouvé rapidement. Le niveau
  des questions envoyées au générateur existant (`CompositeExerciseGenerator`) se dérive de
  l'Elo apparié, pas des niveaux individuels de chaque joueur.
- **Synchronisation en direct** — les deux joueurs reçoivent les mêmes questions en même temps.
  Demande un canal temps réel (écouteurs Postgres/Realtime de Supabase plutôt que des WebSockets
  maison) pour l'état de la partie (qui a répondu, score en cours). Risque principal : la
  synchronisation réseau ne doit jamais interférer avec le timing local de chaque question (le
  jeu se vend sur la vitesse, à la milliseconde) — chaque client chronomètre localement et
  rapporte un résultat, il n'y a pas d'horloge partagée en direct.
- **Résultat de match et Elo mis à jour côté serveur uniquement**, via le même service Dart de
  validation — jamais calculé ou décidé par un client.

Rien de tout ça n'est construit à l'étape 6. Ce paragraphe existe pour que les choix de l'étape 6
(comptes, service de validation, découpage Supabase) n'aient pas à être défaits quand l'étape 7
arrivera.

## Décisions actées

- Modèle d'inscription : email/mot de passe (tranche 1).
- Connexion obligatoire pour utiliser l'app, session persistée localement — pas de réseau requis
  à chaque lancement pour un joueur déjà connecté (tranche 2, voir plus haut).
- Nom de joueur via une table `profiles` dédiée, pas `user_metadata` (tranche 2, voir plus haut).
- `playerId` = id du compte ; parties de l'appareil reprises par le premier compte connecté (voir
  « Identité » plus haut).

## Points ouverts (à trancher dans le plan concret de la tranche 3)

- Forme exacte de l'extraction de `core/domain` pour le service Dart (package séparé vs dossier
  `server/` du même repo).
- Hébergement du service Dart (Cloud Run, Fly.io, autre).
- Schéma Postgres précis de la table de classement, fréquence de synchronisation des réponses.
