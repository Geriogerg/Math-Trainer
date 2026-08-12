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
      scoring/             # Scorer, ScoringRules
      persistence/         # SessionRepository, LocalPlayerIdProvider (interfaces),
                           # PersistedSession/PersistedAnswer, InMemorySessionRepository,
                           # uuid.dart, exercise_codec.dart
    state/                 # SessionController (ChangeNotifier), SessionState — seul point
                           # du cœur métier qui importe Flutter (foundation.dart seulement)
  infrastructure/
    persistence/           # SqfliteSessionRepository, database.dart (schéma + migrations),
                           # SharedPreferencesPlayerIdProvider — seul endroit qui importe
                           # sqflite / shared_preferences
  presentation/
    screens/               # HomeScreen (phase + choix des types), SessionScreen
                           # (question/saisie/feedback), ResultScreen (stats + rejouer)
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

`buildSessionController(environment, enabledTypes)` — un troisième paramètre (niveaux du joueur)
arrive à l'étape 4. Deux paramètres nommés restent lisibles ; au troisième, préférer un petit
objet de configuration plutôt que d'empiler les paramètres.

`HomeScreen` porte la sélection des types (`_TypeSelectionView`). L'étape 4 n'y ajoute **pas** de
contrôle de difficulté — celle-ci est dérivée du niveau, pas choisie. En revanche un écran de
progression viendra s'ajouter ; si le fichier grossit, le scinder par vue.

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

## Formule de niveau (étape 4.2, commit A)

Le système de niveaux (`core/domain/leveling/`, non détaillé plus haut — voir le code et
`doc/decisions.md`) pondère désormais le déplacement de niveau par `√(n / n_min)` (`n` = nombre
de réponses de la session pour l'opération, `LevelUpdater.update`) : 1,0 pile à `n = n_min`,
croît en racine au-delà, pour qu'une session avec beaucoup de réponses ne pèse pas
proportionnellement plus qu'une session minimale. `n_min` passe de 8 à 4, `δ` (bande morte) de
0,05 à 0,07 pour compenser le bruit supplémentaire (raisonnement complet : `doc/decisions.md`).
Valeurs toujours non calibrées.

## Timeout et interruption (étape 4.2, commit B)

`SessionController` arme un `Timer` (15 s, `questionTimeout`, injectable via `createTimer` —
même esprit que `clock`/`idGenerator`, un vrai `Timer` planté dans un test ne s'annule jamais).
Un timeout suit le même chemin qu'une réponse fausse (`_recordOutcome`, factorisé avec
`submitAnswer`), avec `submittedValue: timeoutSubmittedValue` (`-1` — jamais une vraie réponse,
`AnswerResult.isTimeout`). `registerActivity()` (appelée par `SessionScreen` à chaque touche du
pavé, pas seulement Valider) distingue un timeout « essayé » d'un timeout « ignoré » ; trois
timeouts consécutifs sans la moindre activité passent le statut à `SessionStatus.interrupted`
plutôt que `finished`.

**Pas de migration de schéma.** Une session interrompue est persistée normalement (réponses déjà
données incluses), sans champ `status` : `PersistedSession.exerciseCount` reste le compte
*prévu*, donc `answers.length < exerciseCount` suffit à reconnaître une interruption après coup.
Le cache de niveaux, lui, n'est pas mis à jour pour une session interrompue
(`_persistCompletedSession(countsForLevels: false)`).

## Relance immédiate (étape 4.2, commit C)

`SessionFlowScreen` n'est plus un simple relais du contrôleur reçu : il en devient propriétaire
(`_controller` mutable) pour pouvoir le remplacer sans dépiler la route plein écran. `ResultScreen`
expose deux actions — « Rejouer » (mêmes types, relance immédiate) et « Nouvelle sélection »
(retour à `PlayTab`, pop de la route).

**Course évitée entre la relance et l'écriture du cache de niveaux.** `_persistCompletedSession`
tourne en tâche de fond (fin de session normale ou interruption) ; `SessionController` garde
désormais cette `Future` (`pendingPersistence`, remplace l'ancien `unawaited(...)`) plutôt que de
la laisser filer. « Rejouer » l'attend avant d'appeler `buildSessionController` — sinon les
niveaux relus seraient ceux d'*avant* la session qui vient de se terminer, à l'inverse de ce que
la relance promet (`doc/decisions.md`). La transition session → résultat, elle, reste instantanée :
seule la relance a besoin de la donnée fraîche, pas l'affichage du score.

Revient explicitement sur une décision de l'étape 3 (`ResultScreen` n'utilisait jusque-là jamais
`SessionController.restart()`, justement pour éviter de rejouer silencieusement les mêmes types) —
assumé, la relance sert maintenant un besoin réel (niveaux perceptibles d'une session à l'autre).
