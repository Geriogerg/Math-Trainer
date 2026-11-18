import 'package:math_trainer/core/domain/models/answer_result.dart';
import 'package:math_trainer/core/domain/models/exercise.dart';
import 'package:math_trainer/core/domain/models/operation_type.dart';
import 'package:test/test.dart';

void main() {
  const exercise = ArithmeticExercise(
    operandA: 4,
    operandB: 3,
    operationType: OperationType.addition,
  );

  AnswerResult answerAt(DateTime answeredAt) => AnswerResult(
    exercise: exercise,
    submittedValue: 7,
    isCorrect: true,
    elapsedMs: 1200,
    answeredAt: answeredAt,
  );

  group('AnswerResult', () {
    test('refuses a non-UTC answeredAt', () {
      expect(() => answerAt(DateTime(2024, 1, 1, 12)), throwsArgumentError);
    });

    test('accepts a UTC answeredAt', () {
      final answeredAt = DateTime.utc(2024, 1, 1, 12);
      expect(answerAt(answeredAt).answeredAt, answeredAt);
    });

    test('answers given at different times are not equal', () {
      final first = answerAt(DateTime.utc(2024, 1, 1, 12));
      final same = answerAt(DateTime.utc(2024, 1, 1, 12));
      final later = answerAt(DateTime.utc(2024, 1, 1, 12, 0, 3));

      expect(first, same);
      expect(first.hashCode, same.hashCode);
      expect(first, isNot(later));
    });
  });
}
