import 'package:math_core/models/exercise.dart';
import 'package:math_core/models/operation_type.dart';
import 'package:test/test.dart';

void main() {
  group('ArithmeticExercise', () {
    test('computes the right answer for each operation', () {
      expect(
        const ArithmeticExercise(
          operandA: 4,
          operandB: 3,
          operationType: OperationType.addition,
        ).correctAnswer,
        7,
      );
      expect(
        const ArithmeticExercise(
          operandA: 4,
          operandB: 3,
          operationType: OperationType.subtraction,
        ).correctAnswer,
        1,
      );
      expect(
        const ArithmeticExercise(
          operandA: 4,
          operandB: 3,
          operationType: OperationType.multiplication,
        ).correctAnswer,
        12,
      );
      expect(
        const ArithmeticExercise(
          operandA: 12,
          operandB: 3,
          operationType: OperationType.division,
        ).correctAnswer,
        4,
      );
    });

    test('isCorrectAnswer compares integers', () {
      const exercise = ArithmeticExercise(
        operandA: 12,
        operandB: 3,
        operationType: OperationType.division,
      );

      expect(exercise.isCorrectAnswer(4), isTrue);
      expect(exercise.isCorrectAnswer(5), isFalse);
    });

    test('two exercises with the same values are equal', () {
      const a = ArithmeticExercise(
        operandA: 4,
        operandB: 3,
        operationType: OperationType.addition,
      );
      const b = ArithmeticExercise(
        operandA: 4,
        operandB: 3,
        operationType: OperationType.addition,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('rejects a wrong answer for each operation', () {
      expect(
        const ArithmeticExercise(
          operandA: 4,
          operandB: 3,
          operationType: OperationType.addition,
        ).isCorrectAnswer(6),
        isFalse,
      );
      expect(
        const ArithmeticExercise(
          operandA: 4,
          operandB: 3,
          operationType: OperationType.subtraction,
        ).isCorrectAnswer(2),
        isFalse,
      );
      expect(
        const ArithmeticExercise(
          operandA: 4,
          operandB: 3,
          operationType: OperationType.multiplication,
        ).isCorrectAnswer(11),
        isFalse,
      );
    });

    test('subtraction with equal operands has a correct answer of zero', () {
      const exercise = ArithmeticExercise(
        operandA: 5,
        operandB: 5,
        operationType: OperationType.subtraction,
      );

      expect(exercise.correctAnswer, 0);
      expect(exercise.isCorrectAnswer(0), isTrue);
    });

    // No test for "no numeric tolerance": isCorrectAnswer(int) can no longer
    // receive a fractional value, the compiler carries the guarantee.
  });
}
