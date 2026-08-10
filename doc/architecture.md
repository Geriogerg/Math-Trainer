# Architecture — Math Trainer

Document de référence, **non chargé automatiquement**. Les contraintes non négociables sont
dans `CLAUDE.md` ; ce fichier décrit l'état des lieux et peut prendre du retard sur le code.
En cas de divergence, le code fait foi.

## Arborescence

```
lib/
  main.dart                # runApp() — async, résout l'environnement avant
  app.dart                 # MaterialApp, thème, écran racine
  composition_root.dart    # seul fichier qui choisit les implémentations concrètes
  core/
    domain/                # Dart pur — zéro import Flutter (règle 1)
      models/              # Exercise (sealed) et 4 variantes, ExerciseType, OperationType,
                           # AnswerResult, SessionConfig, SessionResult
      generation/          # ExerciseGenerator, CompositeExerciseGenerator, générateurs
                           # par type, OperandRange, ExerciseSource, LocalExerciseSource
                           # sessionLengthFor, TypeSelectionStrategy (interface),
                           # DebtAwareTypeSelectionStrategy (solo, rotation par dette)
      scoring/             # Scorer, ScoringRules
      leveling/            # LevelUpdater, LevelingRules, ConfidenceMultiplier,
                           # AnswerOutcome — domaine pur, rejouable sur un historique
                           # confidenceFor — décision calibration/returning/normal
                           # LevelCacheOrchestrator — calcule les mises à jour du cache
                           # en fin de session (étape 4.1, commit D), Dart pur
      difficulty/          # interpolateLevel, LinearOperandRangeDifficulty (4 opérations
                           # arithmétiques), PowerDifficulty, SquareRootDifficulty,
                           # PercentageDifficulty — sept fonctions niveau → bornes
      persistence/         # SessionRepository, LocalPlayerIdProvider (interfaces),
                           # PersistedSession/PersistedAnswer, LevelCacheEntry,
                           # InMemorySessionRepository, uuid.dart, exercise_codec.dart
    state/                 # SessionController (ChangeNotifier), SessionState — seul point
                           # du cœur métier qui importe Flutter (foundation.dart seulement)
  infrastructure/
    persistence/           # SqfliteSessionRepository, database.dart (schéma + migrations),
                           # SharedPreferencesPlayerIdProvider — seul endroit qui importe
                           # sqflite / shared_preferences
  presentation/
    exercise_type_labels.dart  # exerciseTypeLabel(ExerciseType) — partagé HomeScreen/ProgressScreen
    screens/               # HomeScreen (phase + choix des types), SessionScreen
                           # (question/saisie/feedback), ResultScreen (stats + rejouer),
                           # ProgressScreen (niveau actuel par opération, depuis le cache)
test/
  domain/                  # miroir de core/domain — `dart test test/domain`
  state/                   # SessionController — `flutter test` (ChangeNotifier tire dart:ui)
  infrastructure/          # sqflite via sqflite_common_ffi, shared_preferences mocké
  widget_test.dart         # smoke test + parcours démarrage → session
```

## Gestion d'état

`ChangeNotifier` natif (`flutter/foundation.dart`), sans package tiers. `SessionController`
détient un `SessionState` immuable et notifie l'UI via `ListenableBuilder`. Depuis l'étape 2,
il déclenche aussi l'écriture en base en fin de session — asynchrone, non bloquante pour l'UI,
échec silencieux.

## Composition root

`lib/composition_root.dart` est le seul fichier qui choisit les implémentations concrètes
(générateur, repository sqflite ou en mémoire selon la plateforme). Les écrans ne construisent
plus aucun objet de domaine : ils observent le contrôleur qui en résulte.

## Modèle d'exercice

Deux enums, deux rôles distincts à ne pas confondre :

- **`ExerciseType`** — axe de sélection d'une session, couvre tous les types du jeu.
  Enhanced enum portant un `OperationType?` : les quatre valeurs arithmétiques référencent leur
  opération, les autres portent `null`. Évite une table de correspondance séparée.
- **`OperationType`** — strictement interne à `ArithmeticExercise`, décrit une opération
  binaire (+ − × ÷). N'est jamais étendu pour un nouveau type d'exercice (règle 12).

`Exercise` est une `sealed class` exposant `prompt`, `correctAnswer` (typé **`int`**),
`isCorrectAnswer(int)` et `ExerciseType get type`. Chaque variante porte ses opérandes sous
leur nom métier plutôt qu'une liste générique, et implémente `==` / `hashCode`.

| Variante | Opérandes | Forme présentée |
|---|---|---|
| `ArithmeticExercise` | `operandA`, `operandB`, `OperationType` | `a + b`, `a - b`, `a × b`, `a ÷ b` |
| `PowerExercise` | `base`, `exponent` | `a^n` |
| `SquareRootExercise` | `radicand` (carré parfait) | `√a` |
| `PercentageExercise` | `percent`, `base` | `p% de a` |

La réponse attendue est exposée par le domaine, jamais recalculée par l'UI ni par le `Scorer` :
l'écran de session ne connaît qu'une saisie `int` et un booléen.

Le stockage passe par `operands_json`, qui absorbe les variantes sans migration de schéma.
Le discriminant stocké est le nom de la valeur d'`ExerciseType`.

Dette connue : `prompt` contient de la copie d'interface en français (« 25% de 80 ») dans le
domaine pur. Sans conséquence aujourd'hui, à traiter à la première internationalisation.

## Composition et paramètres

`buildSessionController(environment, enabledTypes)` est asynchrone depuis l'étape 4 (commit D) :
il lit le cache de niveaux du joueur (`SessionRepository.currentLevels`) avant de construire le
générateur et la config. Toujours deux paramètres — les niveaux sont dérivés de la persistance en
interne, jamais transmis par l'appelant, donc pas de 3ᵉ paramètre à empiler ni à regrouper dans un
objet de configuration pour l'instant.

`HomeScreen._startSession` attend ce `Future` (garde `_isStarting` anti-double-tap, spinner sur
le bouton pendant l'attente — une seule requête indexée, donc bref).

`HomeScreen` porte la sélection des types (`_TypeSelectionView`). L'étape 4 n'y ajoute **pas** de
contrôle de difficulté — celle-ci est dérivée du niveau, pas choisie. Un bouton « Voir ma
progression » ouvre `ProgressScreen` (`Navigator.push` — première utilisation du `Navigator`
dans l'app, jusque-là `HomeScreen` gérait tout par état interne).

**Sélection par défaut : 2 types** (addition, soustraction — étape 4.1, commit A), pas 4. Les 5
autres restent affichés, juste décochés.

## Longueur de session et sélection des types (étape 4.1, commit A)

`exerciseCount` n'est plus une constante fixe : `sessionLengthFor(activeTypeCount, nMin, cap)`
vise `n_min × types actifs`, plafonné à `cap = 24` dans `composition_root.dart`. Avec les 2 types
par défaut, une session compte désormais **16 questions**, pas 10.

Au-delà du plafond, `CompositeExerciseGenerator` accepte une `TypeSelectionStrategy?` optionnelle
qui remplace le tirage uniforme par une séquence précalculée. Sans elle (`strategy: null`), le
comportement historique — flux infini, tirage uniforme par appel — reste strictement inchangé ;
c'est le seul mode utilisé par tous les tests antérieurs à l'étape 4.1. Avec elle, le générateur
construit sa séquence une fois à la construction et la consomme dans l'ordre ; un appel au-delà
lève `StateError`.

`DebtAwareTypeSelectionStrategy` (solo) priorise les types les moins joués (`sessionsPlayed` de
`player_levels`, déjà lu par `buildSessionController` pour les niveaux — aucun nouvel appel au
repository). L'historique entre ainsi dans la config de génération ; voir `doc/decisions.md` pour
ce que ça implique pour la règle 2 et pour le duel futur (`FixedQuotaTypeSelectionStrategy`, non
implémentée — le point d'extension existe, pas la stratégie).

## Cache de niveaux (`player_levels`)

Table séparée de `sessions`, clé composite `(player_id, exercise_type)` plutôt qu'UUID — écart
assumé à la règle 5, voir `doc/decisions.md`. `LevelCacheEntry` (le type domaine qui représente
une ligne de ce cache) vit dans `persistence/`, aux côtés de `PersistedSession`/`PersistedAnswer`
— même rôle, nom différent volontairement (voir `doc/decisions.md`).

Le calcul des mises à jour est fait par `LevelCacheOrchestrator` (`core/domain/leveling/`, Dart
pur — étape 4.1 commit D, sorti de `SessionController` pour rester réexécutable côté serveur,
règle 1) : groupe les réponses par type, filtre sous `n_min`, appelle `confidenceFor` puis
`LevelUpdater`. `SessionController` l'injecte (comme `scorer`) et se contente d'appeler
`computeUpdates(...)` dans `_persistCompletedSession`, en fin de session — dans la même
transaction que `recordSession`. Lu par `buildSessionController` au démarrage de la session
suivante — et par `ProgressScreen` pour l'affichage, sans transformation, sans niveau 1 par
défaut pour une opération jamais jouée (« Non joué », pour ne pas laisser croire qu'un niveau a
été mesuré). `sessions.levels_json` stocke séparément les niveaux qui ont *servi* à générer
chaque session — les deux peuvent diverger si le cache a évolué depuis (recalibration, autre
appareil).

## Score pondéré par la difficulté

`Scorer.pointsFor` prend un `level` (niveau figé de l'opération pour la session, jamais le
niveau courant du cache) et multiplie les points bruts (base + bonus vitesse + bonus streak,
inchangés) par `1 + (level - 1) / 99 * difficultyBonusMax`. `difficultyBonusMax` (défaut 1,0,
non calibré) vit dans `ScoringRules`, aux côtés des autres constantes de barème. Le score reste
un retour de session sans valeur de classement — c'est le niveau qui classe (voir
`doc/decisions.md`). Aucun nouveau champ de stockage : le score pondéré est déjà ce qui atterrit
dans `AnswerResult`/`totalScore`.

## Dépendances

| Dépendance | Justification |
|---|---|
| `flutter` (SDK) | obligatoire |
| `cupertino_icons ^1.0.8` | ajoutée par `flutter create` — **non utilisée**, supprimable |
| `flutter_test` (SDK, dev) | tests widgets |
| `flutter_lints ^6.0.0` (dev) | lints du projet |
| `test ^1.25.0` (dev) | permet `dart test` sur le cœur métier pur |
| `sqflite` | SQLite local (règle 3), schéma écrit à la main |
| `path` | jointure de chemin cross-platform pour localiser le `.db` |
| `shared_preferences` | stockage du scalaire `player_id` |
| `sqflite_common_ffi` (dev) | tests du repository sur la Dart VM, sans émulateur |

L'étape 3 n'introduit aucune dépendance : puissances, carrés parfaits et pourcentages entiers
se calculent en arithmétique entière avec `dart:core` seul.
