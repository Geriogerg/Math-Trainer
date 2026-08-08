import 'package:math_trainer/core/domain/models/answer_result.dart';
import 'package:math_trainer/core/domain/models/exercise.dart';
import 'package:math_trainer/core/domain/models/operation_type.dart';
import 'package:math_trainer/core/domain/models/session_result.dart';
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
  });
}
