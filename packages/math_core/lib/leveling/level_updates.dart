import '../models/answer_result.dart';
import '../models/exercise_type.dart';
import '../persistence/level_cache_entry.dart';
import 'answer_outcome.dart';
import 'confidence.dart';
import 'level.dart';
import 'level_updater.dart';

/// The level cache entries a **completed game** produces — pure: the app
/// (`LevelCacheOrchestrator`, prior levels from its cache) and the server
/// (prior levels from its own tables) compute them with this one function,
/// so an honest session lands on the same levels on both sides.
///
/// One entry per type that received at least `n_min` answers (the others
/// are a noise sample, their entry is left alone). [frozenLevels] is the
/// level that generated the session; [priorLevels] decide the confidence
/// (calibration, return after absence) and the session counts; [now] is
/// the session's own time — never the time of computation, or a replay
/// later would differ.
Map<ExerciseType, LevelCacheEntry> gameLevelUpdates({
  required List<AnswerResult> outcomes,
  required Map<ExerciseType, Level> frozenLevels,
  required Map<ExerciseType, LevelCacheEntry> priorLevels,
  required DateTime now,
  required LevelUpdater levelUpdater,
}) {
  final outcomesByType = <ExerciseType, List<AnswerOutcome>>{};
  for (final outcome in outcomes) {
    outcomesByType
        .putIfAbsent(outcome.exercise.type, () => [])
        .add(
          AnswerOutcome(
            isCorrect: outcome.isCorrect,
            elapsedMs: outcome.elapsedMs,
          ),
        );
  }

  final updates = <ExerciseType, LevelCacheEntry>{};
  for (final MapEntry(key: type, value: answers) in outcomesByType.entries) {
    if (answers.length < levelUpdater.rules.nMin) continue;
    final prior = priorLevels[type];
    final newLevel = levelUpdater.update(
      currentLevel: frozenLevels[type] ?? Level.floor,
      answers: answers,
      confidence: confidenceFor(
        entry: prior,
        now: now,
        rules: levelUpdater.rules,
      ),
    );
    updates[type] = LevelCacheEntry(
      level: newLevel,
      sessionsPlayed: (prior?.sessionsPlayed ?? 0) + 1,
      updatedAt: now,
    );
  }
  return updates;
}
