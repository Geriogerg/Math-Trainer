import '../models/answer_result.dart';
import '../models/exercise_type.dart';
import '../persistence/level_cache_entry.dart';
import '../persistence/session_repository.dart';
import 'answer_outcome.dart';
import 'confidence.dart';
import 'level_updater.dart';

/// Computes the level cache updates at the end of a session. Taken out of
/// `SessionController` (step 4.1, commit D) to stay pure Dart, runnable
/// server-side (rule 1) — exactly what revalidating a duel will one day
/// have to redo.
class LevelCacheOrchestrator {
  LevelCacheOrchestrator({LevelUpdater? levelUpdater})
    : levelUpdater = levelUpdater ?? LevelUpdater();

  final LevelUpdater levelUpdater;

  /// One entry per enabled type that received at least `n_min` answers this
  /// session (the others are a noise sample, see `doc/decisions.md` — their
  /// cache is left untouched). [frozenLevels] is the level that actually
  /// generated the session, never re-read from the cache at this point.
  Future<Map<ExerciseType, LevelCacheEntry>> computeUpdates({
    required List<AnswerResult> outcomes,
    required Map<ExerciseType, int> frozenLevels,
    required SessionRepository repository,
    required String playerId,
    required DateTime now,
  }) async {
    final outcomesByType = <ExerciseType, List<AnswerOutcome>>{};
    for (final outcome in outcomes) {
      outcomesByType
          .putIfAbsent(outcome.exercise.type, () => [])
          .add(AnswerOutcome(isCorrect: outcome.isCorrect, elapsedMs: outcome.elapsedMs));
    }

    final priorLevels = await repository.currentLevels(playerId);
    final updates = <ExerciseType, LevelCacheEntry>{};

    for (final entry in outcomesByType.entries) {
      final type = entry.key;
      final answers = entry.value;
      if (answers.length < levelUpdater.rules.nMin) continue;

      final prior = priorLevels[type];
      final currentLevel = frozenLevels[type] ?? 1;
      final confidence = confidenceFor(entry: prior, now: now, rules: levelUpdater.rules);
      final newLevel = levelUpdater.update(
        currentLevel: currentLevel,
        answers: answers,
        confidence: confidence,
      );

      updates[type] = LevelCacheEntry(
        level: newLevel,
        sessionsPlayed: (prior?.sessionsPlayed ?? 0) + 1,
        updatedAt: now,
      );
    }

    return updates;
  }
}
