import 'dart:math';

import '../generation/exercise_generator.dart';
import '../generation/game_generator.dart';
import '../generation/question_plan.dart';
import '../leveling/rules_version.dart';
import '../models/exercise.dart';
import '../models/exercise_type.dart';
import '../models/session_config.dart';
import '../models/session_kind.dart';
import '../patterns/pattern_family.dart';
import '../persistence/persisted_session.dart';
import '../tiers/tier_content.dart';
import '../tiers/tiered_game_generator.dart';

/// A stored session that does not hold everything its replay needs, or
/// that nothing replays any more.
class SessionNotReplayable implements Exception {
  const SessionNotReplayable(this.reason);

  final String reason;

  @override
  String toString() => 'SessionNotReplayable: $reason';
}

/// The first [count] questions of a stored [session], regenerated from what
/// it stores alone — seed, frozen levels, type sequence, rules version
/// (rule 2). What the server checks an upload against (plan, Phase 2).
///
/// Throws [SessionNotReplayable] for a session of retired rules (v1, and
/// with them every placement: `doc/levels.md` section 4), one without its
/// type sequence or a frozen level for an enabled type, or one whose plan
/// is not the setup's (each operation the same number of questions, one of
/// 4, 5, 10, 20).
List<Exercise> replaySessionQuestions(PersistedSession session, int count) => [
  for (final q in _replay(session, count)) q.exercise,
];

/// [replaySessionQuestions] and [replaySessionPatterns] in one replay: each
/// question with its pattern family. Throws as they do.
List<TierQuestion> replaySession(PersistedSession session, int count) =>
    _replay(session, count);

List<TierQuestion> _replay(PersistedSession session, int count) {
  if (count > session.exerciseCount) {
    throw SessionNotReplayable(
      '$count answers for ${session.exerciseCount} questions',
    );
  }
  switch (session.rulesVersion) {
    case RulesVersion.v1:
      throw const SessionNotReplayable('rules v1 are retired');
    case RulesVersion.v2:
    case RulesVersion.v3:
    case RulesVersion.v4:
    case RulesVersion.v5:
    case RulesVersion.v6:
    case RulesVersion.v7:
      break;
  }
  switch (session.kind) {
    case SessionKind.game:
    case SessionKind.training:
      // Training draws exactly like a game, at its frozen fixed levels.
      break;
    case SessionKind.placementV1:
    case SessionKind.placementV2:
    case SessionKind.typePlacementV3:
      throw const SessionNotReplayable('no placement under rules v2');
  }
  final sequence = session.typeSequence;
  if (sequence == null) {
    throw const SessionNotReplayable('no stored type sequence');
  }
  for (final type in session.enabledTypes) {
    // A replay never guesses a level.
    if (!session.levels.containsKey(type)) {
      throw SessionNotReplayable('no frozen level for ${type.name}');
    }
  }
  _checkQuestionPlan(session.enabledTypes, sequence);
  if (session.weakSpots.isNotEmpty && session.kind != SessionKind.game) {
    throw const SessionNotReplayable('weak spots outside a Levelling game');
  }
  final ExerciseGenerator generator;
  try {
    generator = gameExerciseGenerator(
      rulesVersion: session.rulesVersion,
      enabledTypes: session.enabledTypes,
      levels: session.levels,
      typeSequence: sequence,
      weakSpots: session.weakSpots,
    );
  } on ArgumentError catch (e) {
    // Stored weak spots that break the rules (tier, caps, version).
    throw SessionNotReplayable('weak spots: ${e.message}');
  }
  // Same stream as `LocalExerciseSource`: one `Random(seed)`.
  final random = Random(session.seed);
  return [
    for (var i = 0; i < count; i++)
      (
        exercise: generator.next(random),
        family: generator is TieredGameGenerator ? generator.lastFamily : null,
      ),
  ];
}

/// The pattern family of each of [session]'s first [count] questions
/// (`doc/levels.md` section 5b), by the same replay as
/// [replaySessionQuestions]: `null` for a standard question, always under
/// rules v2 and v3. Families are never stored — this is how the Method
/// knows a pattern question (section 9). Throws as
/// [replaySessionQuestions] does.
List<PatternFamily?> replaySessionPatterns(
  PersistedSession session,
  int count,
) => [for (final q in _replay(session, count)) q.family];

/// The pattern family of each of a game's first [count] questions, from
/// its [config] — what the result screen's Method needs while the game is
/// still in memory (`doc/levels.md` section 9): the same replay as
/// [replaySessionPatterns], with the same stream as `LocalExerciseSource`.
/// All `null` for a game without a type sequence (Tables mode, a list of
/// questions) or of retired rules.
List<PatternFamily?> gamePatterns(SessionConfig config, int count) {
  final sequence = config.typeSequence;
  if (sequence == null || config.rulesVersion.retired) {
    return List.filled(count, null);
  }
  final generator = gameExerciseGenerator(
    rulesVersion: config.rulesVersion,
    enabledTypes: config.enabledTypes,
    levels: config.levels,
    typeSequence: sequence,
    weakSpots: config.weakSpots,
  );
  final random = Random(config.seed);
  return [
    for (var i = 0; i < count && i < sequence.length; i++)
      () {
        generator.next(random);
        return generator is TieredGameGenerator ? generator.lastFamily : null;
      }(),
  ];
}

/// Every enabled operation, and only those, the same number of times, one
/// of the setup's choices (plan v2.9): the level update's cap depends on
/// it.
void _checkQuestionPlan(
  Set<ExerciseType> enabled,
  List<ExerciseType> sequence,
) {
  final counts = <ExerciseType, int>{};
  for (final type in sequence) {
    counts[type] = (counts[type] ?? 0) + 1;
  }
  final perOperation = counts.values.toSet();
  if (counts.length != enabled.length ||
      !enabled.every(counts.containsKey) ||
      perOperation.length != 1 ||
      !questionsPerOperationChoices.contains(perOperation.single)) {
    throw SessionNotReplayable('not a question plan: $counts');
  }
}
