import 'dart:math';

import '../generation/composite_exercise_generator.dart';
import '../generation/fixed_type_sequence.dart';
import '../leveling/rules_version.dart';
import '../models/exercise.dart';
import '../models/session_kind.dart';
import '../persistence/persisted_session.dart';
import '../placement/placement.dart';
import '../placement/placement_exercise_source.dart';

/// A stored session that does not hold everything its replay needs.
class SessionNotReplayable implements Exception {
  const SessionNotReplayable(this.reason);

  final String reason;

  @override
  String toString() => 'SessionNotReplayable: $reason';
}

/// The questions of a stored [session], regenerated from what it stores
/// alone — seed, kind, frozen levels, type sequence — one per answer in
/// [answers] (an interrupted session replays its answered prefix). Rule 2,
/// and what the server checks an upload against (plan, Phase 2).
///
/// [answers] are `(isCorrect, elapsedMs)` in the order given: a placement's
/// next question depends on them. A game ignores their values. The caller
/// passes correctness it has **recomputed** from the submitted values,
/// never the client's claim.
///
/// Throws [SessionNotReplayable] if the session lacks its type sequence
/// (interrupted before schema v6) or a frozen level for an enabled type.
List<Exercise> replaySessionQuestions(
  PersistedSession session,
  List<PlacementAnswer> answers,
) {
  if (answers.length > session.exerciseCount) {
    throw SessionNotReplayable(
      '${answers.length} answers for ${session.exerciseCount} questions',
    );
  }
  switch (session.rulesVersion) {
    case RulesVersion.v1:
      break;
    case RulesVersion.v2:
      // Built through the Levels phase; playable from its commit 4.
      throw const SessionNotReplayable('rules v2 are not playable yet');
  }
  switch (session.kind) {
    case SessionKind.game:
    case SessionKind.training:
      // Training draws exactly like a game, at its frozen fixed levels.
      return _replayGame(session, answers.length);
    case SessionKind.placementV1:
    case SessionKind.placementV2:
      return _replayPlacement(session, answers);
    case SessionKind.typePlacementV3:
      return _replayTypePlacement(session, answers);
  }
}

/// A type placement (Phase 3a commit 7): its stored rotation must be the
/// one its operations imply — the staircases follow it question by
/// question.
List<Exercise> _replayTypePlacement(
  PersistedSession session,
  List<PlacementAnswer> answers,
) {
  final rules = placementRulesFor(session.kind);
  final sequence = session.typeSequence;
  if (sequence == null) {
    throw const SessionNotReplayable('no stored type sequence');
  }
  final expected = typePlacementSequence(session.enabledTypes, rules: rules);
  if (sequence.length != expected.length ||
      [
        for (var i = 0; i < expected.length; i++) sequence[i] == expected[i],
      ].contains(false)) {
    throw const SessionNotReplayable(
      'type sequence differs from the type placement rules',
    );
  }
  return replayPlacementQuestions(
    seed: session.seed,
    answers: answers,
    rules: rules,
    sequence: sequence,
  );
}

List<Exercise> _replayGame(PersistedSession session, int count) {
  final sequence = session.typeSequence;
  if (sequence == null) {
    throw const SessionNotReplayable('no stored type sequence');
  }
  for (final type in session.enabledTypes) {
    // The generator falls back to a default level for a missing type: a
    // replay must never guess.
    if (!session.levels.containsKey(type)) {
      throw SessionNotReplayable('no frozen level for ${type.name}');
    }
  }
  final generator = CompositeExerciseGenerator(
    enabledTypes: session.enabledTypes,
    levels: session.levels,
    strategy: FixedTypeSequence(sequence),
  );
  // Same stream as `LocalExerciseSource`: one `Random(seed)` shared by the
  // type draw (none here) and the value draws.
  final random = Random(session.seed);
  return [for (var i = 0; i < count; i++) generator.next(random)];
}

List<Exercise> _replayPlacement(
  PersistedSession session,
  List<PlacementAnswer> answers,
) {
  final rules = placementRulesFor(session.kind);
  final sequence = session.typeSequence;
  if (sequence != null) {
    final expected = placementTypeSequence(rules);
    for (var i = 0; i < expected.length; i++) {
      if (sequence.length != expected.length || sequence[i] != expected[i]) {
        throw const SessionNotReplayable(
          'type sequence differs from the placement rules',
        );
      }
    }
  }
  return replayPlacementQuestions(
    seed: session.seed,
    answers: answers,
    rules: rules,
  );
}
