import 'package:math_core/models/answer_result.dart';
import 'package:math_core/models/exercise.dart';
import 'package:math_core/models/operation_type.dart';
import 'package:math_core/models/session_result.dart';
import 'package:math_core/scoring/scorer.dart';
import 'package:test/test.dart';

void main() {
  final exercise = ArithmeticExercise(
    operandA: 4,
    operandB: 3,
    operationType: OperationType.addition,
  );

  group('SessionResult', () {
    test('computes accuracy and average time from the answers', () {
      final result = SessionResult(
        totalScore: 150,
        outcomes: [
          AnswerResult(
            exercise: exercise,
            submittedValue: 7,
            isCorrect: true,
            elapsedMs: 1000,
            answeredAt: DateTime.utc(2024),
          ),
          AnswerResult(
            exercise: exercise,
            submittedValue: 8,
            isCorrect: false,
            elapsedMs: 2000,
            answeredAt: DateTime.utc(2024),
          ),
        ],
      );

      expect(result.correctCount, 1);
      expect(result.accuracy, 0.5);
      expect(result.averageElapsedMs, 1500);
    });

    test('handles a session without answers without dividing by zero', () {
      const result = SessionResult(totalScore: 0, outcomes: []);

      expect(result.correctCount, 0);
      expect(result.accuracy, 0);
      expect(result.averageElapsedMs, 0);
    });

    final answeredAt = DateTime.utc(2024);
    AnswerResult correct({int elapsedMs = 1000}) => AnswerResult(
      exercise: exercise,
      submittedValue: 7,
      isCorrect: true,
      elapsedMs: elapsedMs,
      answeredAt: answeredAt,
    );
    AnswerResult wrong() => AnswerResult(
      exercise: exercise,
      submittedValue: 0,
      isCorrect: false,
      elapsedMs: 1000,
      answeredAt: answeredAt,
    );
    AnswerResult timeout() => AnswerResult(
      exercise: exercise,
      submittedValue: timeoutSubmittedValue,
      isCorrect: false,
      elapsedMs: 15000,
      answeredAt: answeredAt,
    );

    test('timeoutCount and wrongCount tell timed out from simply wrong', () {
      final result = SessionResult(
        totalScore: 0,
        outcomes: [correct(), wrong(), timeout(), timeout()],
      );

      expect(result.correctCount, 1);
      expect(result.wrongCount, 1);
      expect(result.timeoutCount, 2);
    });

    test('bestStreak keeps the maximum, not the final streak', () {
      // right, right, right, wrong, right: best streak 3, final streak 1.
      final result = SessionResult(
        totalScore: 0,
        outcomes: [correct(), correct(), correct(), wrong(), correct()],
      );

      expect(result.bestStreak, 3);
    });

    test('bestStreak is 0 if no answer is right', () {
      final result = SessionResult(
        totalScore: 0,
        outcomes: [wrong(), timeout()],
      );

      expect(result.bestStreak, 0);
    });

    test(
      'scoreBreakdown rebuilds base/speed/streak from the replayed streak',
      () {
        const scorer = Scorer();
        final outcomes = [
          correct(elapsedMs: 0),
          correct(elapsedMs: 0),
          wrong(),
        ];
        // Replayed: streak 1 then 2 for the two right answers.
        final raw1 = scorer.rawPointsFor(outcomes[0], currentStreak: 1);
        final raw2 = scorer.rawPointsFor(outcomes[1], currentStreak: 2);
        final expectedBase = raw1.base + raw2.base;
        final expectedSpeed = raw1.speedBonus + raw2.speedBonus;
        final expectedStreak = raw1.streakBonus + raw2.streakBonus;
        final totalScore =
            expectedBase +
            expectedSpeed +
            expectedStreak +
            7; // +7 : bonus arbitraire

        final result = SessionResult(
          totalScore: totalScore,
          outcomes: outcomes,
          scorer: scorer,
        );
        final breakdown = result.scoreBreakdown;

        expect(breakdown.base, expectedBase);
        expect(breakdown.speedBonus, expectedSpeed);
        expect(breakdown.streakBonus, expectedStreak);
        // The four components must always sum exactly to the total score.
        expect(
          breakdown.base +
              breakdown.speedBonus +
              breakdown.streakBonus +
              breakdown.difficultyBonus,
          totalScore,
        );
      },
    );
  });
}
