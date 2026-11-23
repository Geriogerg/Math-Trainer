import 'dart:math';

import 'package:math_core/generation/game_generator.dart';
import 'package:math_core/generation/question_plan.dart';
import 'package:math_core/leveling/level.dart';
import 'package:math_core/leveling/rules_version.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/models/session_kind.dart';
import 'package:math_core/persistence/persisted_session.dart';
import 'package:math_core/replay/session_replay.dart';
import 'package:test/test.dart';

void main() {
  const types = {ExerciseType.addition, ExerciseType.integral};
  final levels = {
    ExerciseType.addition: Level.fromHundredths(4231),
    ExerciseType.integral: Level.fromHundredths(870),
  };
  const seed = 1763510400123;
  final plan = shuffledTypeSequence(types: types, perOperation: 5, seed: seed);

  PersistedSession session({
    List<ExerciseType>? typeSequence,
    Map<ExerciseType, Level>? frozen,
    Set<ExerciseType> enabled = types,
    SessionKind kind = SessionKind.game,
    RulesVersion rules = RulesVersion.v2,
    int? count,
  }) => PersistedSession(
    id: 's',
    playerId: 'p',
    seed: seed,
    enabledTypes: enabled,
    exerciseCount: count ?? typeSequence?.length ?? plan.length,
    totalScore: 0,
    levels: frozen ?? levels,
    createdAt: DateTime.utc(2026, 11, 23),
    typeSequence: typeSequence,
    kind: kind,
    rulesVersion: rules,
  );

  test('a game replays from its stored fields alone, prefix included — '
      'the questions the app drew', () {
    final generator = gameExerciseGenerator(
      rulesVersion: RulesVersion.v2,
      enabledTypes: types,
      levels: levels,
      typeSequence: plan,
    );
    final random = Random(seed);
    final live = [for (final _ in plan) generator.next(random)];
    final stored = session(typeSequence: plan);
    expect(replaySessionQuestions(stored, plan.length), live);
    expect(replaySessionQuestions(stored, 3), live.take(3).toList());
  });

  test('a Training game replays like a game, at its frozen levels', () {
    final training = session(typeSequence: plan, kind: SessionKind.training);
    expect(
      replaySessionQuestions(training, plan.length),
      replaySessionQuestions(session(typeSequence: plan), plan.length),
    );
  });

  group('not replayable', () {
    void refused(PersistedSession s, [int count = 3]) => expect(
      () => replaySessionQuestions(s, count),
      throwsA(isA<SessionNotReplayable>()),
    );

    test('rules v1, retired', () {
      refused(session(typeSequence: plan, rules: RulesVersion.v1));
    });

    test('a placement, of any version', () {
      for (final kind in [
        SessionKind.placementV1,
        SessionKind.placementV2,
        SessionKind.typePlacementV3,
      ]) {
        refused(session(typeSequence: plan, kind: kind));
      }
    });

    test('no stored type sequence', () {
      refused(session(count: 10));
    });

    test('a frozen level missing for an enabled type', () {
      refused(
        session(
          typeSequence: plan,
          frozen: {ExerciseType.addition: Level.zero},
        ),
      );
    });

    test('more answers than planned questions', () {
      refused(session(typeSequence: plan), plan.length + 1);
    });

    test("a plan other than the setup's", () {
      // Unequal counts.
      refused(
        session(
          typeSequence: [
            ...List.filled(4, ExerciseType.addition),
            ...List.filled(5, ExerciseType.integral),
          ],
        ),
      );
      // Equal, but 3 each.
      refused(
        session(
          typeSequence: [
            ...List.filled(3, ExerciseType.addition),
            ...List.filled(3, ExerciseType.integral),
          ],
        ),
      );
      // An enabled operation never asked.
      refused(session(typeSequence: List.filled(4, ExerciseType.addition)));
    });
  });

  test('PersistedSession refuses a type sequence of the wrong length', () {
    expect(
      () => session(typeSequence: plan, count: plan.length + 1),
      throwsArgumentError,
    );
  });
}
