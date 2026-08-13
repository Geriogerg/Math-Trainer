# Mode en ligne — Math Trainer

Comptes, classement général, duels et Elo. **Non chargé automatiquement** — lis-le avant tout
travail touchant aux comptes, au réseau, ou à `infrastructure/backend/` (à venir). Comme les
autres docs de ce dossier, le code fait foi en cas de divergence.

Ce fichier documente une **direction validée**, pas un état livré : rien de ce qui suit n'existe
encore dans le code tant que l'étape 6 n'a pas commencé.

## Phasage

- **Étape 6 (courante)** — création de compte, classement solo entre tous les joueurs de l'app.
  Pas de duels, pas d'Elo, pas de matchmaking.
- **Étape 7** — matchs en ligne synchronisés (mêmes questions, en même temps) et Elo. S'appuie
  sur l'infrastructure posée à l'étape 6 (comptes, service de validation serveur) sans la
  refondre.

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

`playerId` existe déjà (`LocalPlayerIdProvider`, UUID généré localement) et peut précéder tout
compte — un joueur peut avoir joué des semaines en solo avant de créer un compte. Approche
retenue par défaut, à confirmer dans le plan concret : **le `playerId` local ne change pas** à la
création du compte ; le compte s'associe au `playerId` existant côté serveur plutôt que de
réécrire l'historique local. Réécrire `playerId` à travers toutes les tables locales serait
risqué pour un bénéfice nul.

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

## Points ouverts (à trancher dans le plan concret de l'étape 6)

- Modèle d'inscription : email/mot de passe, OAuth, ou compte anonyme upgradable.
- Forme exacte de l'extraction de `core/domain` pour le service Dart (package séparé vs dossier
  `server/` du même repo).
- Hébergement du service Dart (Cloud Run, Fly.io, autre).
- Schéma Postgres précis (tables comptes/classement), fréquence de synchronisation des réponses.
