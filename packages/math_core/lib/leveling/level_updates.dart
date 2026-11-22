import '../models/answer_result.dart';
import '../models/exercise_type.dart';
import '../persistence/level_cache_entry.dart';
import 'answer_outcome.dart';
import 'confidence.dart';
import 'fluent_time.dart';
import 'level.dart';
import 'level_change.dart';
import 'level_updater.dart';
import 'rules_version.dart';

/// The level cache entries a **completed game** produces — pure: the app
/// (`LevelCacheOrchestrator`, prior levels from its cache) and the server
/// (prior levels from its own tables) compute them with this one function,
/// so an honest session lands on the same levels on both sides.
///
/// Under the game's [rulesVersion]:
/// - **v2** (`doc/levels.md`, section 3): one entry per operation
///   answered, moved by the quality of its answers ([levelAfterGame], the
///   fluent time of its operation and frozen level);
/// - **v1**: one entry per type that received at least `n_min` answers (the
///   others are a noise sample, their entry is left alone), moved by
///   [levelUpdater] with a confidence from [priorLevels].
///
/// [frozenLevels] is the level that generated the session; [priorLevels]
/// give the session counts; [now] is the session's own time — never the
/// time of computation, or a replay later would differ.
Map<ExerciseType, LevelCacheEntry> gameLevelUpdates({
  required List<AnswerResult> outcomes,
  required Map<ExerciseType, Level> frozenLevels,
  required Map<ExerciseType, LevelCacheEntry> priorLevels,
  required DateTime now,
  LevelUpdater? levelUpdater,
  RulesVersion rulesVersion = RulesVersion.v1,
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
  final v1 = levelUpdater ?? LevelUpdater();
  for (final MapEntry(key: type, value: answers) in outcomesByType.entries) {
    final prior = priorLevels[type];
    final Level newLevel;
    switch (rulesVersion) {
      case RulesVersion.v1:
        if (answers.length < v1.rules.nMin) continue;
        newLevel = v1.update(
          currentLevel: frozenLevels[type] ?? Level.floor,
          answers: answers,
          confidence: confidenceFor(entry: prior, now: now, rules: v1.rules),
        );
      case RulesVersion.v2:
        final current = frozenLevels[type] ?? Level.zero;
        newLevel = levelAfterGame(
          current: current,
          answers: answers,
          fluentMs: fluentTimeMs(type, current),
        );
    }
    updates[type] = LevelCacheEntry(
      level: newLevel,
      sessionsPlayed: (prior?.sessionsPlayed ?? 0) + 1,
      updatedAt: now,
    );
  }
  return updates;
}
