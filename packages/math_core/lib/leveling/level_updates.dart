import '../models/answer_result.dart';
import '../models/exercise_type.dart';
import '../persistence/level_cache_entry.dart';
import '../tiers/fluent_time.dart';
import 'answer_outcome.dart';
import 'level.dart';
import 'level_change.dart';
import 'level_rules.dart';
import 'rules_version.dart';

/// The level cache entries a **completed Levelling game** produces under
/// its [rulesVersion] (`doc/levels.md` section 3, `LevelRules.of`) — pure: the app
/// (`LevelCacheOrchestrator`, prior levels from its cache) and the server
/// (prior levels from its own tables) compute them with this one function,
/// so an honest session lands on the same levels on both sides.
///
/// One entry per operation answered, moved by the quality of its answers
/// ([levelAfterGame]) against the fluent time of its operation at its
/// frozen level. [frozenLevels] is the level that generated the session (0
/// when missing); [priorLevels] give the session counts; [now] is the
/// session's own time — never the time of computation, or a replay later
/// would differ. Throws for rules v1, retired.
Map<ExerciseType, LevelCacheEntry> gameLevelUpdates({
  required List<AnswerResult> outcomes,
  required Map<ExerciseType, Level> frozenLevels,
  required Map<ExerciseType, LevelCacheEntry> priorLevels,
  required DateTime now,
  required RulesVersion rulesVersion,
}) {
  final rules = LevelRules.of(rulesVersion);
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
    final current = frozenLevels[type] ?? Level.zero;
    updates[type] = LevelCacheEntry(
      level: levelAfterGame(
        current: current,
        answers: answers,
        fluentMs: fluentTimeMs(type, current, rulesVersion),
        rules: rules,
      ),
      sessionsPlayed: (priorLevels[type]?.sessionsPlayed ?? 0) + 1,
      updatedAt: now,
    );
  }
  return updates;
}
