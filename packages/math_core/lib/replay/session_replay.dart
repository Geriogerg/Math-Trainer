import 'dart:math';

import '../generation/game_generator.dart';
import '../generation/question_plan.dart';
import '../leveling/rules_version.dart';
import '../models/exercise.dart';
import '../models/exercise_type.dart';
import '../models/session_kind.dart';
import '../persistence/persisted_session.dart';

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
List<Exercise> replaySessionQuestions(PersistedSession session, int count) {
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
  final generator = gameExerciseGenerator(
    rulesVersion: session.rulesVersion,
    enabledTypes: session.enabledTypes,
    levels: session.levels,
    typeSequence: sequence,
  );
  // Same stream as `LocalExerciseSource`: one `Random(seed)`.
  final random = Random(session.seed);
  return [for (var i = 0; i < count; i++) generator.next(random)];
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
