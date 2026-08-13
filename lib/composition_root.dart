import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' show getDatabasesPath;

import 'core/domain/generation/composite_exercise_generator.dart';
import 'core/domain/generation/debt_aware_type_selection_strategy.dart';
import 'core/domain/generation/local_exercise_source.dart';
import 'core/domain/generation/session_length.dart';
import 'core/domain/leveling/leveling_rules.dart';
import 'core/domain/models/exercise_type.dart';
import 'core/domain/models/session_config.dart';
import 'core/domain/persistence/in_memory_session_repository.dart';
import 'core/domain/persistence/local_player_id_provider.dart';
import 'core/domain/persistence/session_repository.dart';
import 'core/domain/persistence/theme_mode_store.dart';
import 'core/domain/persistence/type_selection_store.dart';
import 'core/state/session_controller.dart';
import 'infrastructure/persistence/database.dart';
import 'infrastructure/persistence/shared_preferences_player_id_provider.dart';
import 'infrastructure/persistence/shared_preferences_theme_mode_store.dart';
import 'infrastructure/persistence/shared_preferences_type_selection_store.dart';
import 'infrastructure/persistence/sqflite_session_repository.dart';

/// Cible de durée (~90 s à ~4 s/question, grossier — voir `doc/decisions.md`)
/// déguisée en plafond de questions : `sessionLengthFor` ne dépasse jamais
/// cette valeur, quel que soit le nombre de types actifs.
const _sessionLengthCap = 24;

final _levelingRules = LevelingRules();

/// Dépendances concrètes résolues une fois au démarrage de l'app (voir
/// `main.dart`), avant `runApp()` — jamais dans un widget UI. C'est le seul
/// fichier qui choisit *quelles* implémentations concrètes utiliser
/// (génération, persistance) ; `home_screen.dart` ne fait qu'observer le
/// `SessionController` qui en résulte.
class AppEnvironment {
  const AppEnvironment({
    required this.repository,
    required this.playerId,
    this.typeSelectionStore = const SharedPreferencesTypeSelectionStore(),
    this.themeModeStore = const SharedPreferencesThemeModeStore(),
  });

  final SessionRepository repository;
  final String playerId;

  /// Optionnel, défaut concret plutôt que requis : un champ requis casserait
  /// la construction dans les tests qui ne s'intéressent jamais à `PlayTab`
  /// (`ProgressScreen`, `ResultScreen`...), même raisonnement que
  /// `SessionResult.scorer` (étape 5, commit D).
  final TypeSelectionStore typeSelectionStore;

  /// Même raisonnement que `typeSelectionStore` : optionnel pour ne pas
  /// casser la construction dans les tests qui ne s'intéressent pas à la
  /// bascule de thème.
  final ThemeModeStore themeModeStore;
}

Future<AppEnvironment> buildAppEnvironment() async {
  final LocalPlayerIdProvider playerIdProvider = SharedPreferencesPlayerIdProvider();
  final playerId = await playerIdProvider.currentPlayerId();

  final SessionRepository repository;
  if (kIsWeb) {
    // sqflite n'a pas d'implémentation web ; le web n'est utilisé que pour
    // itérer (CLAUDE.md), donc un repository en mémoire suffit ici.
    repository = InMemorySessionRepository();
  } else {
    final databasePath = p.join(await getDatabasesPath(), 'math_trainer.db');
    repository = SqfliteSessionRepository(await openMathTrainerDatabase(databasePath));
  }

  return AppEnvironment(repository: repository, playerId: playerId);
}

/// Assemble un `SessionController` prêt à jouer : source d'exercices locale
/// (mélange de [enabledTypes], choisis par l'utilisateur sur `HomeScreen`)
/// + seed du moment + dépendances de [environment]. Asynchrone : lit le
/// cache de niveaux du joueur (règle 4, repositories toujours asynchrones)
/// pour figer les niveaux de cette session — niveau 1 pour toute opération
/// jamais jouée (aucune compétence estimée = on part du bas).
///
/// Le nombre de questions n'est plus fixe : `sessionLengthFor` vise assez de
/// questions pour que chaque type actif atteigne `n_min` (donc que son
/// cache de niveau puisse bouger), plafonné à `_sessionLengthCap`. Au-delà
/// du plafond, `DebtAwareTypeSelectionStrategy` priorise les types les
/// moins joués (`sessionsPlayed`, déjà lu ci-dessus pour les niveaux) —
/// aucun nouvel appel au repository (voir `doc/decisions.md`).
Future<SessionController> buildSessionController(
  AppEnvironment environment,
  Set<ExerciseType> enabledTypes,
) async {
  final priorLevels = await environment.repository.currentLevels(environment.playerId);
  final levels = {for (final type in enabledTypes) type: priorLevels[type]?.level ?? 1};

  final exerciseCount = sessionLengthFor(
    activeTypeCount: enabledTypes.length,
    nMin: _levelingRules.nMin,
    cap: _sessionLengthCap,
  );
  final strategy = DebtAwareTypeSelectionStrategy(
    exerciseCount: exerciseCount,
    nMin: _levelingRules.nMin,
    sessionsPlayedByType: {
      for (final entry in priorLevels.entries) entry.key: entry.value.sessionsPlayed,
    },
  );

  final seed = DateTime.now().millisecondsSinceEpoch;
  return SessionController(
    config: SessionConfig(
      seed: seed,
      enabledTypes: enabledTypes,
      exerciseCount: exerciseCount,
      levels: levels,
    ),
    exerciseSource: LocalExerciseSource(
      generator: CompositeExerciseGenerator(
        enabledTypes: enabledTypes,
        levels: levels,
        strategy: strategy,
      ),
      seed: seed,
    ),
    repository: environment.repository,
    playerId: environment.playerId,
  );
}
