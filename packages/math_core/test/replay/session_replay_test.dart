import 'dart:math';

import 'package:math_core/generation/composite_exercise_generator.dart';
import 'package:math_core/generation/debt_aware_type_selection_strategy.dart';
import 'package:math_core/generation/fixed_type_sequence.dart';
import 'package:math_core/leveling/level.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/models/session_kind.dart';
import 'package:math_core/persistence/persisted_session.dart';
import 'package:math_core/placement/placement.dart';
import 'package:math_core/placement/placement_exercise_source.dart';
import 'package:math_core/replay/session_replay.dart';
import 'package:test/test.dart';

void main() {
  const allTypes = ExerciseType.values;
  final levels = {
    for (final t in allTypes) t: Level.fromHundredths(1000 + 731 * t.index),
  };

  PersistedSession game({
    List<ExerciseType>? typeSequence,
    Map<ExerciseType, Level>? frozen,
    int count = 24,
  }) => PersistedSession(
    id: 's',
    playerId: 'p',
    seed: 1763510400123,
    enabledTypes: allTypes.toSet(),
    exerciseCount: count,
    totalScore: 0,
    levels: frozen ?? levels,
    createdAt: DateTime.utc(2026, 11, 19),
    typeSequence: typeSequence,
  );

  List<({bool isCorrect, int elapsedMs})> answers(int n) => [
    for (var i = 0; i < n; i++) (isCorrect: i.isEven, elapsedMs: 1500 + i),
  ];

  test('a fixed sequence generates exactly what the debt strategy did', () {
    // 7 types, 24 questions: the order depends on the per-type counts.
    final strategy = DebtAwareTypeSelectionStrategy(
      exerciseCount: 24,
      nMin: 4,
      sessionsPlayedByType: {
        ExerciseType.addition: 9,
        ExerciseType.multiplication: 2,
        ExerciseType.percentage: 5,
      },
    );
    final sequence = strategy.sequenceFor(allTypes.toList());
    String run(CompositeExerciseGenerator g) {
      final random = Random(42);
      return [for (var i = 0; i < 24; i++) g.next(random)].join(';');
    }

    expect(
      run(
        CompositeExerciseGenerator(
          enabledTypes: allTypes.toSet(),
          levels: levels,
          strategy: FixedTypeSequence(sequence),
        ),
      ),
      run(
        CompositeExerciseGenerator(
          enabledTypes: allTypes.toSet(),
          levels: levels,
          strategy: strategy,
        ),
      ),
    );
  });

  test('a game replays from its stored fields alone, prefix included', () {
    final sequence = [
      for (var i = 0; i < 24; i++) allTypes[(i * 5) % allTypes.length],
    ];
    final session = game(typeSequence: sequence);
    final full = replaySessionQuestions(session, answers(24));
    expect(full.map((e) => e.type), sequence);
    // An interrupted session: its answered prefix, the same questions.
    expect(replaySessionQuestions(session, answers(7)), full.take(7));
    // Deterministic.
    expect(replaySessionQuestions(session, answers(24)), full);
  });

  test('a placement replays with its own rules version', () {
    for (final rules in [placementRulesV1, placementRulesV2]) {
      final session = PersistedSession(
        id: 'p',
        playerId: 'p',
        seed: 99,
        enabledTypes: placementTypes.toSet(),
        exerciseCount: rules.questionCount,
        totalScore: 0,
        levels: {for (final t in placementTypes) t: Level.whole(35)},
        createdAt: DateTime.utc(2026, 11, 19),
        kind: placementKindFor(rules),
        typeSequence: placementTypeSequence(rules),
      );
      final given = answers(rules.questionCount);
      expect(
        replaySessionQuestions(session, given),
        replayPlacementQuestions(seed: 99, answers: given, rules: rules),
      );
    }
  });

  group('not replayable', () {
    test('no stored type sequence (interrupted before schema v6)', () {
      expect(
        () => replaySessionQuestions(game(), answers(3)),
        throwsA(isA<SessionNotReplayable>()),
      );
    });

    test('a frozen level missing for an enabled type', () {
      final sequence = List.filled(24, ExerciseType.addition);
      expect(
        () => replaySessionQuestions(
          game(
            typeSequence: sequence,
            frozen: {ExerciseType.addition: Level.floor},
          ),
          answers(3),
        ),
        throwsA(isA<SessionNotReplayable>()),
      );
    });

    test('more answers than planned questions', () {
      final sequence = List.filled(4, ExerciseType.addition);
      expect(
        () => replaySessionQuestions(
          game(typeSequence: sequence, count: 4),
          answers(5),
        ),
        throwsA(isA<SessionNotReplayable>()),
      );
    });

    test('a placement whose type sequence contradicts its rules', () {
      final session = PersistedSession(
        id: 'p',
        playerId: 'p',
        seed: 1,
        enabledTypes: placementTypes.toSet(),
        exerciseCount: 20,
        totalScore: 0,
        levels: const {},
        createdAt: DateTime.utc(2026, 11, 19),
        kind: SessionKind.placementV2,
        typeSequence: List.filled(20, ExerciseType.addition),
      );
      expect(
        () => replaySessionQuestions(session, answers(2)),
        throwsA(isA<SessionNotReplayable>()),
      );
    });
  });

  group('FixedTypeSequence', () {
    test('refuses an empty sequence', () {
      expect(() => FixedTypeSequence(const []), throwsArgumentError);
    });

    test('refuses a type that is not enabled', () {
      expect(
        () => FixedTypeSequence(const [
          ExerciseType.power,
        ]).sequenceFor(const [ExerciseType.addition]),
        throwsArgumentError,
      );
    });
  });

  test('PersistedSession refuses a type sequence of the wrong length', () {
    expect(
      () => game(typeSequence: const [ExerciseType.addition]),
      throwsArgumentError,
    );
  });
}
