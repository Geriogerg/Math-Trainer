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
    );
  }

  group('Scorer', () {
    test('une réponse incorrecte ne rapporte aucun point, quel que soit le streak', () {
      final points = scorer.pointsFor(
        answer(isCorrect: false, elapsedMs: 0),
        currentStreak: 5,
        level: 1,
      );

      expect(points, 0);
    });

    test('une réponse correcte instantanée obtient le bonus de vitesse maximal', () {
      final points = scorer.pointsFor(
        answer(isCorrect: true, elapsedMs: 0),
        currentStreak: 1,
        level: 1,
      );

      expect(points, 10 + 10 + 0);
    });

    test('une réponse correcte hors de la fenêtre de vitesse n\'a aucun bonus de vitesse', () {
      final points = scorer.pointsFor(
        answer(isCorrect: true, elapsedMs: 5000),
        currentStreak: 1,
        level: 1,
      );

      expect(points, 10 + 0 + 0);
    });

    test('le bonus de streak augmente avec les réponses consécutives puis plafonne', () {
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

    test('un temps écoulé négatif (horloge qui recule) ne dépasse pas le bonus de vitesse max', () {
      final rules = scorer.rules;

      final points = scorer.pointsFor(
        answer(isCorrect: true, elapsedMs: -1000),
        currentStreak: 1,
        level: 1,
      );

      expect(points, rules.basePoints + rules.maxSpeedBonus);
    });

    test('niveau 1 ne change pas les points (aucun bonus de difficulté)', () {
      final rules = scorer.rules;

      final points = scorer.pointsFor(
        answer(isCorrect: true, elapsedMs: 5000),
        currentStreak: 1,
        level: 1,
      );

      expect(points, rules.basePoints);
    });

    test('niveau 100 double les points avec difficultyBonusMax par défaut (1.0)', () {
      final rules = scorer.rules;

      final points = scorer.pointsFor(
        answer(isCorrect: true, elapsedMs: 5000),
        currentStreak: 1,
        level: 100,
      );

      expect(points, rules.basePoints * 2);
    });

    test('un niveau intermédiaire applique un bonus de difficulté proportionnel', () {
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

    test('refuse un niveau hors [1, 100], y compris pour une réponse fausse', () {
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
