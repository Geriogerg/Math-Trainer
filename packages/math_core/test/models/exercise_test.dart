import 'package:math_core/models/exercise.dart';
import 'package:math_core/models/operation_type.dart';
import 'package:test/test.dart';

void main() {
  group('ArithmeticExercise', () {
    test('computes the right answer for each operation', () {
      expect(
        ArithmeticExercise(
          operandA: 4,
          operandB: 3,
          operationType: OperationType.addition,
        ).correctAnswer,
        7,
      );
      expect(
        ArithmeticExercise(
          operandA: 4,
          operandB: 3,
          operationType: OperationType.subtraction,
        ).correctAnswer,
        1,
      );
      expect(
        ArithmeticExercise(
          operandA: 4,
          operandB: 3,
          operationType: OperationType.multiplication,
        ).correctAnswer,
        12,
      );
      expect(
        ArithmeticExercise(
          operandA: 12,
          operandB: 3,
          operationType: OperationType.division,
        ).correctAnswer,
        4,
      );
    });

    test('isCorrectAnswer compares integers', () {
      final exercise = ArithmeticExercise(
        operandA: 12,
        operandB: 3,
        operationType: OperationType.division,
      );

      expect(exercise.isCorrectAnswer(4), isTrue);
      expect(exercise.isCorrectAnswer(5), isFalse);
    });

    test('two exercises with the same values are equal', () {
      final a = ArithmeticExercise(
        operandA: 4,
        operandB: 3,
        operationType: OperationType.addition,
      );
      final b = ArithmeticExercise(
        operandA: 4,
        operandB: 3,
        operationType: OperationType.addition,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('rejects a wrong answer for each operation', () {
      expect(
        ArithmeticExercise(
          operandA: 4,
          operandB: 3,
          operationType: OperationType.addition,
        ).isCorrectAnswer(6),
        isFalse,
      );
      expect(
        ArithmeticExercise(
          operandA: 4,
          operandB: 3,
          operationType: OperationType.subtraction,
        ).isCorrectAnswer(2),
        isFalse,
      );
      expect(
        ArithmeticExercise(
          operandA: 4,
          operandB: 3,
          operationType: OperationType.multiplication,
        ).isCorrectAnswer(11),
        isFalse,
      );
    });

    test('subtraction with equal operands has a correct answer of zero', () {
      final exercise = ArithmeticExercise(
        operandA: 5,
        operandB: 5,
        operationType: OperationType.subtraction,
      );

      expect(exercise.correctAnswer, 0);
      expect(exercise.isCorrectAnswer(0), isTrue);
    });

    test('a third addend (rules v4: 27 + 46 + 73): summed, compared; only an '
        'addition has one (rule 13)', () {
      final three = ArithmeticExercise(
        operandA: 27,
        operandB: 46,
        operandC: 73,
        operationType: OperationType.addition,
      );
      expect(three.correctAnswer, 146);
      expect(
        three,
        isNot(
          ArithmeticExercise(
            operandA: 27,
            operandB: 46,
            operationType: OperationType.addition,
          ),
        ),
      );
      expect(
        () => ArithmeticExercise(
          operandA: 27,
          operandB: 46,
          operandC: 1,
          operationType: OperationType.multiplication,
        ),
        throwsArgumentError,
      );
    });

    // No test for "no numeric tolerance": isCorrectAnswer(int) can no longer
    // receive a fractional value, the compiler carries the guarantee.
  });
}
