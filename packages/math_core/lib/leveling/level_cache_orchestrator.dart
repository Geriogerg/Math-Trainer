import '../models/answer_result.dart';
import '../models/exercise_type.dart';
import '../persistence/level_cache_entry.dart';
import '../persistence/session_repository.dart';
import 'level.dart';
import 'level_updater.dart';
import 'level_updates.dart';

/// How a finished session turns into level cache updates — a game
/// ([LevelCacheOrchestrator]) or a placement (`PlacementLevelOrchestrator`).
/// `SessionController` only knows this.
abstract interface class SessionLevelUpdates {
  Future<Map<ExerciseType, LevelCacheEntry>> computeUpdates({
    required List<AnswerResult> outcomes,
    required Map<ExerciseType, Level> frozenLevels,
    required SessionRepository repository,
    required String playerId,
    required DateTime now,
  });
}

/// A Training game's updates: none, ever (plan v2.9) — its fixed levels
/// must never reach the cache.
class NoLevelUpdates implements SessionLevelUpdates {
  const NoLevelUpdates();

  @override
  Future<Map<ExerciseType, LevelCacheEntry>> computeUpdates({
    required List<AnswerResult> outcomes,
    required Map<ExerciseType, Level> frozenLevels,
    required SessionRepository repository,
    required String playerId,
    required DateTime now,
  }) async => const {};
}

/// Computes the level cache updates at the end of a game. Taken out of
/// `SessionController` (step 4.1, commit D) to stay pure Dart, runnable
/// server-side (rule 1) — exactly what revalidating a duel will one day
/// have to redo.
class LevelCacheOrchestrator implements SessionLevelUpdates {
  LevelCacheOrchestrator({LevelUpdater? levelUpdater})
    : levelUpdater = levelUpdater ?? LevelUpdater();

  final LevelUpdater levelUpdater;

  /// One entry per enabled type that received at least `n_min` answers this
  /// session (the others are a noise sample, see `doc/decisions.md` — their
  /// cache is left untouched). [frozenLevels] is the level that actually
  /// generated the session, never re-read from the cache at this point.
  @override
  Future<Map<ExerciseType, LevelCacheEntry>> computeUpdates({
    required List<AnswerResult> outcomes,
    required Map<ExerciseType, Level> frozenLevels,
    required SessionRepository repository,
    required String playerId,
    required DateTime now,
  }) async => gameLevelUpdates(
    outcomes: outcomes,
    frozenLevels: frozenLevels,
    priorLevels: await repository.currentLevels(playerId),
    now: now,
    levelUpdater: levelUpdater,
  );
}
