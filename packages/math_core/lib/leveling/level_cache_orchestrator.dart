import '../models/answer_result.dart';
import '../models/exercise_type.dart';
import '../persistence/level_cache_entry.dart';
import '../persistence/session_repository.dart';
import 'level.dart';
import 'level_updates.dart';

/// How a finished session turns into level cache updates — a Levelling
/// game ([LevelCacheOrchestrator]) or a Training game ([NoLevelUpdates]).
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

/// Computes the level cache updates at the end of a Levelling game. Taken
/// out of `SessionController` (step 4.1, commit D) to stay pure Dart,
/// runnable server-side (rule 1).
class LevelCacheOrchestrator implements SessionLevelUpdates {
  const LevelCacheOrchestrator();

  /// One entry per operation answered (`gameLevelUpdates`). [frozenLevels]
  /// is the level that actually generated the session, never re-read from
  /// the cache at this point.
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
  );
}
