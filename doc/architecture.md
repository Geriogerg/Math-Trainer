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
                           # par type, OperandRange, ExerciseSource, LocalExerciseSource,
                           # session_length.dart (longueur de session dynamique),
                           # TypeSelectionStrategy / DebtAwareTypeSelectionStrategy
      difficulty/          # dérivation des bornes de génération à partir d'un niveau
                           # (interpolation linéaire), un fichier par type d'exercice
      leveling/             # LevelingRules, LevelUpdater, confidenceFor, LevelCacheOrchestrator
                           # (orchestration pure de la mise à jour du cache de niveaux)
      scoring/             # Scorer, ScoringRules
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
    theme/
      app_theme.dart        # ThemeData clair/sombre (doc/design.md), AppPalette et AppMotion
                           # (extensions pour ce qui n'a pas de rôle Material 3 standard :
                           # texte discret, durées/courbes d'animation)
    exercise_type_labels.dart  # libellés français des ExerciseType, hors du domaine
    screens/               # HomeScreen (phase + choix des types), SessionScreen
                           # (question/saisie/feedback), ProgressScreen (niveaux par type),
                           # ResultScreen (stats + rejouer)
tool/
  recalibrate.dart         # CLI hors app — rejoue l'historique réel pour évaluer les ~20
                           # constantes de LevelingRules (convergence/oscillation/biais).
                           # `dart run`, pas `flutter run` : lit SQLite via sqflite_common_ffi
                           # directement, ne passe pas par SqfliteSessionRepository (qui tire
                           # dart:ui via le plugin sqflite, indisponible hors tooling Flutter).
  src/
    replay_metrics.dart    # logique pure du script (extraite pour être testable — les membres
                           # privés d'une lib Dart sont inaccessibles même en import relatif)
test/
  domain/                  # miroir de core/domain — `dart test test/domain`
  state/                   # SessionController — `flutter test` (ChangeNotifier tire dart:ui)
  infrastructure/          # sqflite via sqflite_common_ffi, shared_preferences mocké
  presentation/            # écrans (ProgressScreen, etc.)
  tool/                    # replay_metrics.dart — `dart test`, pas de dépendance Flutter
  widget_test.dart         # smoke test + parcours démarrage → session
```

## Gestion d'état

`ChangeNotifier` natif (`flutter/foundation.dart`), sans package tiers. `SessionController`
détient un `SessionState` immuable et notifie l'UI via `ListenableBuilder`. Depuis l'étape 2,
il déclenche aussi l'écriture en base en fin de session — asynchrone, non bloquante pour l'UI.
Depuis l'étape 4.1, `_persistCompletedSession` est scindé en deux blocs `try`/`catch`
indépendants : la persistance de la session (non reconstructible si perdue) ne doit pas
empêcher la mise à jour du cache de niveaux, et réciproquement. Les deux blocs catchent
`on Exception` (jamais `catch` nu) : une `Error` de programmation (`ArgumentError`,
`StateError` — violation d'invariant, règle 13) doit remonter et planter, pas être avalée
comme un échec d'I/O attendu.

## Composition root

`lib/composition_root.dart` est le seul fichier qui choisit les implémentations concrètes
(générateur, repository sqflite ou en mémoire selon la plateforme). Les écrans ne construisent
plus aucun objet de domaine : ils observent le contrôleur qui en résulte.

`buildSessionController(environment, enabledTypes)` est asynchrone : il lit d'abord le cache de
niveaux du joueur (`currentLevels`) pour figer les niveaux de la session (niveau 1 pour toute
opération jamais jouée), calcule une longueur de session dynamique via `sessionLengthFor`
(assez de questions pour que chaque type actif atteigne `nMin`, plafonné à 24), construit une
`DebtAwareTypeSelectionStrategy` à partir du même `sessionsPlayed` déjà lu (aucun appel
supplémentaire au repository), puis assemble le `CompositeExerciseGenerator` et le
`SessionController`. Le detail du calcul est documenté dans `doc/decisions.md`.

## Modèle d'exercice

Deux enums, deux rôles distincts à ne pas confondre :

- **`ExerciseType`** — axe de sélection d'une session, couvre tous les types du jeu.
  Enhanced enum portant un `OperationType?` : les quatre valeurs arithmétiques référencent leur
  opération, les autres portent `null`. Évite une table de correspondance séparée.
- **`OperationType`** — strictement interne à `ArithmeticExercise`, décrit une opération
  binaire (+ − × ÷). N'est jamais étendu pour un nouveau type d'exercice (règle 12).

`Exercise` est une `sealed class` exposant `correctAnswer` (typé **`int`**), `isCorrectAnswer(int)`
et `ExerciseType get type` — plus aucun texte d'affichage depuis l'étape 5 (commit B) : le domaine
ne connaît que les valeurs mathématiques, jamais leur mise en forme. Chaque variante porte ses
opérandes sous leur nom métier plutôt qu'une liste générique, et implémente `==` / `hashCode`.

| Variante | Opérandes |
|---|---|
| `ArithmeticExercise` | `operandA`, `operandB`, `OperationType` |
| `PowerExercise` | `base`, `exponent` |
| `SquareRootExercise` | `radicand` (carré parfait) |
| `PercentageExercise` | `percent`, `base` |

La réponse attendue est exposée par le domaine, jamais recalculée par l'UI ni par le `Scorer`.

Le stockage passe par `operands_json`, qui absorbe les variantes sans migration de schéma.
Le discriminant stocké est le nom de la valeur d'`ExerciseType`, sauf pour les quatre opérations
arithmétiques : `exercise_type` vaut `'arithmetic'` pour toutes, l'opération précise est dans la
colonne `operation_type` (piège pour tout code qui relit la table directement, cf.
`tool/recalibrate.dart`).

**Affichage : `presentation/exercise_prompt.dart`.** `ExercisePrompt`, un `switch` exhaustif sans
`default` (règle 11) sur `Exercise`, compose le rendu à partir des champs de chaque variante —
plus jamais un getter sur le domaine. Résout la dette documentée depuis l'étape 3 (copie
française en dur dans `core/domain/`).

Notation conforme à `doc/design.md` sur toutes les variantes : addition/soustraction/
multiplication/division et pourcentage en texte simple (vrais caractères `+ − × ÷`, U+2212 pour
la soustraction — jamais le trait d'union) ; puissance via `_PowerPrompt` (`Text.rich`, exposant
en `WidgetSpan` aligné en haut de ligne, ~55 % de la taille de la base) ; racine carrée via
`_SquareRootPrompt` (`Row` avec un `Container` à `Border(top:)` sur le radicande, le symbole `√`
n'étant pas lui-même sous la barre — simplification assumée par `doc/design.md`).

## Système de niveaux

Le niveau est un **cache recalculable**, pas une source de vérité (voir `CLAUDE.md`). Trois
familles de modules en `core/domain/`, toutes Dart pur :

- **`leveling/`** — `LevelingRules` (les ~10 constantes de la formule, non calibrées faute de
  données réelles ; validées au constructeur, ex. `tRapideMs < tLentMs`, `nMin > 0`),
  `LevelUpdater.update(...)` (la formule elle-même, rejouable sur une liste de réponses),
  `confidenceFor(...)` (multiplicateur `normal`/`calibration`/`returning` selon l'historique),
  et `LevelCacheOrchestrator` — regroupe les réponses d'une session par `ExerciseType`, filtre
  les groupes sous `nMin`, et appelle `confidenceFor` puis `LevelUpdater.update` pour produire
  les nouvelles entrées de cache. Extrait de `SessionController` (étape 4.1) pour être
  réexécutable côté serveur lors de la revalidation des duels (règle 1).
- **`difficulty/`** — dérive les bornes de génération (`OperandRange` ou équivalent par type) à
  partir d'un niveau entier, par interpolation linéaire entre les bornes du niveau 1 et du
  niveau maximal. Un fichier par type d'exercice arithmétique/puissance/racine/pourcentage.
- **`persistence/LevelCacheEntry`** — l'entrée de cache elle-même (niveau, `sessionsPlayed`,
  dernière date de réponse par `ExerciseType`). Rangée sous `persistence/` avec
  `PersistedSession`/`PersistedAnswer` par cohérence, mais sans UUID ni `syncedAt` : contrairement
  à elles, une entrée de cache est jetable et recalculable, jamais synchronisée telle quelle.

`tool/recalibrate.dart` est un script CLI hors app (pas un écran) qui rejoue l'historique réel
d'un joueur à travers `LevelingRules` en faisant varier une constante à la fois, et rapporte
convergence/oscillation/biais. Il n'a rien à traiter tant que peu de sessions réelles ont été
jouées — voir le point d'attente dans `CLAUDE.md`.

## Dépendances

| Dépendance | Justification |
|---|---|
| `flutter` (SDK) | obligatoire |
| `cupertino_icons ^1.0.8` | ajoutée par `flutter create` — **non utilisée**, supprimable |
| `flutter_test` (SDK, dev) | tests widgets |
| `flutter_lints ^6.0.0` (dev) | lints du projet |
| `test ^1.25.0` (dev) | permet `dart test` sur le cœur métier pur, et sur `tool/` |
| `sqflite` | SQLite local (règle 3), schéma écrit à la main |
| `path` | jointure de chemin cross-platform pour localiser le `.db` |
| `shared_preferences` | stockage du scalaire `player_id` |
| `sqflite_common_ffi` (dev) | tests du repository et `tool/recalibrate.dart` sur la Dart VM,
  sans émulateur ni `dart:ui` |

## Thème

`ThemeData` clair et sombre centralisés dans `presentation/theme/app_theme.dart`
(`buildLightTheme()` / `buildDarkTheme()`), branchés dans `app.dart` via
`themeMode: ThemeMode.system` — aucun sélecteur manuel, le mode clair n'étant pas une variante de
confort (`doc/design.md`). Palette posée sur les rôles `ColorScheme` Material 3 standard (voir
`doc/decisions.md` pour le mapping exact) ; seul le texte discret (aucun rôle M3 adapté) et les
durées/courbes d'animation vivent dans des `ThemeExtension` (`AppPalette`, `AppMotion`).

Police `Inter` bundlée en asset local (`assets/fonts/Inter.ttf`, police variable, un seul
fichier) — pas de dépendance ajoutée. `TextTheme` réécrit sur ce point : les 5 tailles de
`doc/design.md` posées sur 5 des 15 styles nommés Material 3, chiffres tabulaires et plafond de
graisse (400/500 max) appliqués à l'ensemble du `TextTheme`, pas qu'aux 5 tailles nommées.
