import 'package:math_core/leveling/leveling_rules.dart';
import 'package:math_core/models/answer_result.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/models/session_kind.dart';
import 'package:math_core/placement/placement.dart';
import 'package:math_core/placement/placement_exercise_source.dart';
import 'package:test/test.dart';

/// The type placement (plan v2.3, Phase 3a commit 7): the first game on
/// never-played operations is a short placement on them.
void main() {
  test('rotation: the operations by enum index, five each', () {
    final sequence = typePlacementSequence({
      ExerciseType.percentage,
      ExerciseType.power,
    });
    expect(sequence, [
      for (var i = 0; i < 5; i++) ...[
        ExerciseType.power,
        ExerciseType.percentage,
      ],
    ]);
    expect(() => typePlacementSequence(const {}), throwsArgumentError);
  });

  test('stored as its own kind, replayed with its own rules', () {
    expect(placementKindFor(typePlacementRules), SessionKind.typePlacementV3);
    expect(
      placementRulesFor(SessionKind.typePlacementV3),
      same(typePlacementRules),
    );
    expect(SessionKind.typePlacementV3.isPlacement, isTrue);
    expect(SessionKind.typePlacementV3.isTypePlacement, isTrue);
    expect(SessionKind.placementV2.isTypePlacement, isFalse);
  });

  test('same staircase as the placement test, pass time on every type', () {
    expect(typePlacementRules.startLevel, placementRulesV2.startLevel);
    expect(
      typePlacementRules.firstStepHundredths,
      placementRulesV2.firstStepHundredths,
    );
    expect(
      typePlacementRules.questionsPerType,
      placementRulesV2.questionsPerType,
    );
    final rules = LevelingRules();
    for (final type in ExerciseType.values) {
      expect(
        typePlacementRules.passMaxElapsedMsFor(type),
        (rules.tRapideMs * placementPassTimeOverTRapide).round(),
        reason: type.name,
      );
    }
  });

  test('each staircase moves with its own answers only', () {
    final sequence = typePlacementSequence({
      ExerciseType.squareRoot,
      ExerciseType.percentage,
    });
    // Right and fast on roots, wrong on percentages.
    final answers = [
      for (final type in sequence)
        (isCorrect: type == ExerciseType.squareRoot, elapsedMs: 1500),
    ];
    final levels = placementLevels(
      answers,
      typePlacementRules,
      sequence: sequence,
    );
    expect(levels.keys, {ExerciseType.squareRoot, ExerciseType.percentage});
    expect(levels[ExerciseType.squareRoot]!.whole, greaterThan(35));
    expect(levels[ExerciseType.percentage]!.whole, lessThan(35));
    expect(
      () => placementLevels(
        answers.sublist(1),
        typePlacementRules,
        sequence: sequence,
      ),
      throwsArgumentError,
    );
  });

  test('live questions = replayed questions, on the planned types', () {
    final sequence = typePlacementSequence({ExerciseType.power});
    final source = PlacementExerciseSource(
      seed: 77,
      rules: typePlacementRules,
      sequence: sequence,
    );
    final given = <({bool isCorrect, int elapsedMs})>[];
    final live = [];
    for (var i = 0; i < sequence.length; i++) {
      final q = source.next();
      expect(q.type, ExerciseType.power);
      live.add(q);
      final answer = (isCorrect: i.isEven, elapsedMs: 1800);
      given.add(answer);
      source.onAnswered(
        AnswerResult(
          exercise: q,
          submittedValue: answer.isCorrect ? q.correctAnswer : -1,
          isCorrect: answer.isCorrect,
          elapsedMs: answer.elapsedMs,
          answeredAt: DateTime.utc(2026, 11, 21),
        ),
      );
    }
    expect(
      replayPlacementQuestions(
        seed: 77,
        answers: given,
        rules: typePlacementRules,
        sequence: sequence,
      ),
      live,
    );
    expect(source.next, throwsStateError);
  });

  test('the placement test itself is unchanged by the generalization', () {
    final answers = [
      for (var i = 0; i < placementRulesV2.questionCount; i++)
        (isCorrect: i % 3 != 0, elapsedMs: 2000),
    ];
    expect(
      placementLevels(answers, placementRulesV2),
      placementLevels(
        answers,
        placementRulesV2,
        sequence: placementTypeSequence(placementRulesV2),
      ),
    );
  });
}
