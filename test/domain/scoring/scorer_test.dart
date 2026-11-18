import 'package:math_trainer/core/domain/models/answer_result.dart';
import 'package:math_trainer/core/domain/models/exercise.dart';
import 'package:math_trainer/core/domain/models/operation_type.dart';
import 'package:math_trainer/core/domain/scoring/scorer.dart';
import 'package:test/test.dart';

void main() {
  const exercise = ArithmeticExercise(
    operandA: 4,
    operandB: 3,
    operationType: OperationType.addition,
  );
  const scorer = Scorer();

  AnswerResult answer({required bool isCorrect, required int elapsedMs}) {
    return AnswerResult(
      exercise: exercise,
      submittedValue: 7,
      isCorrect: isCorrect,
      elapsedMs: elapsedMs,
      answeredAt: DateTime.utc(2024),
    );
  }

  group('Scorer', () {
    test('a wrong answer earns no points, whatever the streak', () {
      final points = scorer.pointsFor(
        answer(isCorrect: false, elapsedMs: 0),
        currentStreak: 5,
        level: 1,
      );

      expect(points, 0);
    });

    test('an instant right answer gets the maximum speed bonus', () {
      final points = scorer.pointsFor(
        answer(isCorrect: true, elapsedMs: 0),
        currentStreak: 1,
        level: 1,
      );

      expect(points, 10 + 10 + 0);
    });

    test('a right answer outside the speed window gets no speed bonus', () {
      final points = scorer.pointsFor(
        answer(isCorrect: true, elapsedMs: 5000),
        currentStreak: 1,
        level: 1,
      );

      expect(points, 10 + 0 + 0);
    });

    test('the streak bonus grows with consecutive answers then caps', () {
      final rules = scorer.rules;

      final pointsAtStreak5 = scorer.pointsFor(
        answer(isCorrect: true, elapsedMs: 5000),
        currentStreak: 5,
        level: 1,
      );
      final pointsAtStreak50 = scorer.pointsFor(
        answer(isCorrect: true, elapsedMs: 5000),
        currentStreak: 50,
        level: 1,
      );

      expect(pointsAtStreak5, rules.basePoints + 4 * rules.streakBonusPerStep);
      expect(pointsAtStreak50, rules.basePoints + rules.maxStreakBonus);
    });

    test('a negative elapsed time (clock going back) does not exceed the max speed bonus', () {
      final rules = scorer.rules;

      final points = scorer.pointsFor(
        answer(isCorrect: true, elapsedMs: -1000),
        currentStreak: 1,
        level: 1,
      );

      expect(points, rules.basePoints + rules.maxSpeedBonus);
    });

    test('level 1 does not change the points (no difficulty bonus)', () {
      final rules = scorer.rules;

      final points = scorer.pointsFor(
        answer(isCorrect: true, elapsedMs: 5000),
        currentStreak: 1,
        level: 1,
      );

      expect(points, rules.basePoints);
    });

    test('level 100 doubles the points with the default difficultyBonusMax (1.0)', () {
      final rules = scorer.rules;

      final points = scorer.pointsFor(
        answer(isCorrect: true, elapsedMs: 5000),
        currentStreak: 1,
        level: 100,
      );

      expect(points, rules.basePoints * 2);
    });

    test('an intermediate level applies a proportional difficulty bonus', () {
      const rules = ScoringRules(difficultyBonusMax: 1.0);
      const scorerWithRules = Scorer(rules: rules);

      // Niveau 50 : multiplicateur = 1 + 49/99 * 1.0 ≈ 1.4949...
      final points = scorerWithRules.pointsFor(
        answer(isCorrect: true, elapsedMs: 5000),
        currentStreak: 1,
        level: 50,
      );

      expect(points, (rules.basePoints * (1 + 49 / 99)).round());
    });

    test('rawPointsFor breaks a wrong answer down into zeros', () {
      final raw = scorer.rawPointsFor(answer(isCorrect: false, elapsedMs: 0), currentStreak: 5);

      expect(raw, (base: 0, speedBonus: 0, streakBonus: 0));
    });

    test('rawPointsFor breaks a right answer down (base, speed, streak apart)', () {
      final rules = scorer.rules;

      final raw = scorer.rawPointsFor(answer(isCorrect: true, elapsedMs: 0), currentStreak: 5);

      expect(raw.base, rules.basePoints);
      expect(raw.speedBonus, rules.maxSpeedBonus);
      expect(raw.streakBonus, 4 * rules.streakBonusPerStep);
    });

    test('pointsFor applies the difficulty multiplier to the sum of rawPointsFor', () {
      const scorerWithRules = Scorer(rules: ScoringRules(difficultyBonusMax: 1.0));
      final theAnswer = answer(isCorrect: true, elapsedMs: 5000);

      final raw = scorerWithRules.rawPointsFor(theAnswer, currentStreak: 1);
      final points = scorerWithRules.pointsFor(theAnswer, currentStreak: 1, level: 50);

      // Niveau 50 : multiplicateur = 1 + 49/99 * 1.0.
      final expectedMultiplier = 1 + 49 / 99;
      expect(points, ((raw.base + raw.speedBonus + raw.streakBonus) * expectedMultiplier).round());
    });

    test('rejects a level outside [1, 100], even for a wrong answer', () {
      expect(
        () => scorer.pointsFor(
          answer(isCorrect: true, elapsedMs: 0),
          currentStreak: 1,
          level: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => scorer.pointsFor(
          answer(isCorrect: true, elapsedMs: 0),
          currentStreak: 1,
          level: 101,
        ),
        throwsArgumentError,
      );
      expect(
        () => scorer.pointsFor(
          answer(isCorrect: false, elapsedMs: 0),
          currentStreak: 1,
          level: 0,
        ),
        throwsArgumentError,
      );
    });
  });
}
