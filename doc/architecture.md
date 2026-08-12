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

`SessionController.abandon()` (étape 5, commit A) délègue à `_interruptSession()`, déjà
existante depuis l'étape 4.2 pour l'abandon automatique par timeouts — pas de nouvelle notion,
juste un second déclencheur du même statut `interrupted`. `SessionFlowScreen` l'appelle depuis un
`PopScope` qui intercepte la tentative de sortie tant que `status == inProgress` (`canPop` réévalué
à chaque notification, donc placé à l'intérieur du `ListenableBuilder`) et demande confirmation
avant d'abandonner.

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
