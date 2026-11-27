import '../models/answer_result.dart';
import '../models/exercise_type.dart';
import '../persistence/level_cache_entry.dart';
import '../tiers/fluent_time.dart';
import 'answer_outcome.dart';
import 'level.dart';
import 'level_change.dart';
import 'level_rules.dart';
import 'rules_version.dart';

/// The level cache entries a **Levelling game** produces under its
/// [rulesVersion] (`doc/levels.md` section 3, `LevelRules.of`) — pure: the app
/// (`LevelCacheOrchestrator`, prior levels from its cache) and the server
/// (prior levels from its own tables) compute them with this one function,
/// so an honest session lands on the same levels on both sides.
///
/// One entry per operation, moved by the quality of its answers
/// ([levelAfterGame]) against the fluent time of its operation at its
/// frozen level. [frozenLevels] is the level that generated the session (0
/// when missing); [priorLevels] give the session counts; [now] is the
/// session's own time — never the time of computation, or a replay later
/// would differ. Throws for rules v1, retired.
///
/// [typeSequence] is the game's planned order. Under rules that count a
/// quit ([RulesVersion.quitCounts], v9 on) every planned question counts:
/// one left unanswered is a timeout, credit 0, for its operation — an
/// operation with no answer at all included ("Quitting never pays"). Rules
/// v2–v8 count the answers only: they are given completed games alone.
/// Throws when [outcomes] hold more answers of an operation than
/// [typeSequence] plans (rule 13).
Map<ExerciseType, LevelCacheEntry> gameLevelUpdates({
  required List<AnswerResult> outcomes,
  required Map<ExerciseType, Level> frozenLevels,
  required Map<ExerciseType, LevelCacheEntry> priorLevels,
  required DateTime now,
  required RulesVersion rulesVersion,
  required List<ExerciseType> typeSequence,
}) {
  final rules = LevelRules.of(rulesVersion);
  final outcomesByType = _countedAnswers(outcomes, rulesVersion, typeSequence);

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

/// Where an operation's quality fell in a game: above the dead band (the
/// level goes up), inside it (kept), below it (down).
enum QualityZone { up, kept, down }

/// How one operation fared in a Levelling game — what the result screen
/// says about its level change (Phase 6b commit 4, review M16): the
/// questions counted (a quit's missing ones included from rules v9), how
/// many were left unanswered, the quality (mean credit, in percent, rounded
/// down), and its zone against [LevelRules]' dead band (in percent, for the
/// words).
typedef OperationQuality = ({
  int questions,
  int unanswered,
  int qualityPercent,
  QualityZone zone,
  int bandLowPercent,
  int bandHighPercent,
});

/// [OperationQuality] per operation, by exactly the arithmetic of
/// [gameLevelUpdates] (the same credits, fluent times and counted
/// questions). Throws for rules v1, retired.
Map<ExerciseType, OperationQuality> gameQualities({
  required List<AnswerResult> outcomes,
  required Map<ExerciseType, Level> frozenLevels,
  required RulesVersion rulesVersion,
  required List<ExerciseType> typeSequence,
}) {
  final rules = LevelRules.of(rulesVersion);
  final answered = <ExerciseType, int>{};
  for (final o in outcomes) {
    answered[o.exercise.type] = (answered[o.exercise.type] ?? 0) + 1;
  }
  return {
    for (final MapEntry(key: type, value: answers) in _countedAnswers(
      outcomes,
      rulesVersion,
      typeSequence,
    ).entries)
      type: () {
        final level = frozenLevels[type] ?? Level.zero;
        final fluentMs = fluentTimeMs(type, level, rulesVersion);
        var credit = 0;
        for (final a in answers) {
          credit += answerCreditPercent(
            answer: a,
            fluentMs: fluentMs,
            rules: rules,
          );
        }
        final n = answers.length;
        return (
          questions: n,
          unanswered: n - (answered[type] ?? 0),
          qualityPercent: credit ~/ n,
          zone: credit > rules.deadBandHighPercent * n
              ? QualityZone.up
              : credit < rules.deadBandLowPercent * n
              ? QualityZone.down
              : QualityZone.kept,
          bandLowPercent: rules.deadBandLowPercent,
          bandHighPercent: rules.deadBandHighPercent,
        );
      }(),
  };
}

/// [outcomes] by operation, as the level update counts them: under rules
/// that count a quit, every planned question — one left unanswered a
/// timeout.
Map<ExerciseType, List<AnswerOutcome>> _countedAnswers(
  List<AnswerResult> outcomes,
  RulesVersion rulesVersion,
  List<ExerciseType> typeSequence,
) {
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

  if (rulesVersion.quitCounts) {
    final planned = <ExerciseType, int>{};
    for (final type in typeSequence) {
      planned[type] = (planned[type] ?? 0) + 1;
    }
    for (final MapEntry(key: type, value: answers) in outcomesByType.entries) {
      if (answers.length > (planned[type] ?? 0)) {
        throw ArgumentError.value(
          answers.length,
          'outcomes',
          'more ${type.name} answers than the ${planned[type] ?? 0} planned.',
        );
      }
    }
    for (final MapEntry(key: type, value: count) in planned.entries) {
      final answers = outcomesByType.putIfAbsent(type, () => []);
      while (answers.length < count) {
        answers.add(const AnswerOutcome(isCorrect: false, elapsedMs: 30000));
      }
    }
  }
  return outcomesByType;
}
