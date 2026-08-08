import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' show getDatabasesPath;

import 'core/domain/generation/arithmetic_generator.dart';
import 'core/domain/generation/local_exercise_source.dart';
import 'core/domain/models/operation_type.dart';
import 'core/domain/models/session_config.dart';
import 'core/domain/persistence/in_memory_session_repository.dart';
import 'core/domain/persistence/local_player_id_provider.dart';
import 'core/domain/persistence/session_repository.dart';
import 'core/state/session_controller.dart';
import 'infrastructure/persistence/database.dart';
import 'infrastructure/persistence/shared_preferences_player_id_provider.dart';
import 'infrastructure/persistence/sqflite_session_repository.dart';

const _exercisesPerSession = 10;

/// Dépendances concrètes résolues une fois au démarrage de l'app (voir
/// `main.dart`), avant `runApp()` — jamais dans un widget UI. C'est le seul
/// fichier qui choisit *quelles* implémentations concrètes utiliser
/// (génération, persistance) ; `home_screen.dart` ne fait qu'observer le
/// `SessionController` qui en résulte.
class AppEnvironment {
  const AppEnvironment({required this.repository, required this.playerId});

  final SessionRepository repository;
  final String playerId;
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
/// + seed du moment + dépendances de [environment].
SessionController buildSessionController(AppEnvironment environment) {
  final seed = DateTime.now().millisecondsSinceEpoch;
  return SessionController(
    config: SessionConfig(
      seed: seed,
      operationTypes: OperationType.values,
      exerciseCount: _exercisesPerSession,
    ),
    exerciseSource: LocalExerciseSource(
      generator: ArithmeticExerciseGenerator(operationTypes: OperationType.values),
      seed: seed,
    ),
    repository: environment.repository,
    playerId: environment.playerId,
  );
}
