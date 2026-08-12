import 'package:math_trainer/core/domain/models/answer_result.dart';
import 'package:math_trainer/core/domain/models/exercise.dart';
import 'package:math_trainer/core/domain/models/operation_type.dart';
import 'package:math_trainer/core/domain/models/session_result.dart';
import 'package:math_trainer/core/domain/scoring/scorer.dart';
import 'package:test/test.dart';

void main() {
  const exercise = ArithmeticExercise(
    operandA: 4,
    operandB: 3,
    operationType: OperationType.addition,
  );

  group('SessionResult', () {
    test('calcule précision et temps moyen à partir des réponses', () {
      final result = SessionResult(
        totalScore: 150,
        outcomes: const [
          AnswerResult(
            exercise: exercise,
            submittedValue: 7,
            isCorrect: true,
            elapsedMs: 1000,
          ),
          AnswerResult(
            exercise: exercise,
            submittedValue: 8,
            isCorrect: false,
            elapsedMs: 2000,
          ),
        ],
      );

      expect(result.correctCount, 1);
      expect(result.accuracy, 0.5);
      expect(result.averageElapsedMs, 1500);
    });

    test('gère une session sans réponse sans division par zéro', () {
      const result = SessionResult(totalScore: 0, outcomes: []);

      expect(result.correctCount, 0);
      expect(result.accuracy, 0);
      expect(result.averageElapsedMs, 0);
    });

    AnswerResult correct({int elapsedMs = 1000}) =>
        AnswerResult(exercise: exercise, submittedValue: 7, isCorrect: true, elapsedMs: elapsedMs);
    AnswerResult wrong() =>
        const AnswerResult(exercise: exercise, submittedValue: 0, isCorrect: false, elapsedMs: 1000);
    AnswerResult timeout() => const AnswerResult(
      exercise: exercise,
      submittedValue: timeoutSubmittedValue,
      isCorrect: false,
      elapsedMs: 15000,
    );

    test('timeoutCount et wrongCount distinguent hors délai et simplement faux', () {
      final result = SessionResult(
        totalScore: 0,
        outcomes: [correct(), wrong(), timeout(), timeout()],
      );

      expect(result.correctCount, 1);
      expect(result.wrongCount, 1);
      expect(result.timeoutCount, 2);
    });

    test('bestStreak retient le maximum, pas la série finale', () {
      // juste, juste, juste, faux, juste : meilleure série 3, série finale 1.
      final result = SessionResult(
        totalScore: 0,
        outcomes: [correct(), correct(), correct(), wrong(), correct()],
      );

      expect(result.bestStreak, 3);
    });

    test('bestStreak vaut 0 si aucune réponse correcte', () {
      final result = SessionResult(totalScore: 0, outcomes: [wrong(), timeout()]);

      expect(result.bestStreak, 0);
    });

    test('scoreBreakdown reconstitue base/vitesse/série à partir du streak rejoué', () {
      const scorer = Scorer();
      final outcomes = [correct(elapsedMs: 0), correct(elapsedMs: 0), wrong()];
      // Rejoué : streak 1 puis 2 pour les deux réponses correctes.
      final raw1 = scorer.rawPointsFor(outcomes[0], currentStreak: 1);
      final raw2 = scorer.rawPointsFor(outcomes[1], currentStreak: 2);
      final expectedBase = raw1.base + raw2.base;
      final expectedSpeed = raw1.speedBonus + raw2.speedBonus;
      final expectedStreak = raw1.streakBonus + raw2.streakBonus;
      final totalScore = expectedBase + expectedSpeed + expectedStreak + 7; // +7 : bonus arbitraire

      final result = SessionResult(totalScore: totalScore, outcomes: outcomes, scorer: scorer);
      final breakdown = result.scoreBreakdown;

      expect(breakdown.base, expectedBase);
      expect(breakdown.speedBonus, expectedSpeed);
      expect(breakdown.streakBonus, expectedStreak);
      // Les quatre composantes doivent toujours sommer exactement au score total.
      expect(
        breakdown.base + breakdown.speedBonus + breakdown.streakBonus + breakdown.difficultyBonus,
        totalScore,
      );
    });
  });
}
