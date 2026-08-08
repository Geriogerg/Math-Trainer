import 'package:math_trainer/core/domain/models/exercise.dart';
import 'package:math_trainer/core/domain/models/operation_type.dart';
import 'package:math_trainer/core/domain/persistence/exercise_codec.dart';
import 'package:test/test.dart';

void main() {
  group('describeExerciseForStorage', () {
    test('décrit un ArithmeticExercise avec ses opérandes', () {
      const exercise = ArithmeticExercise(
        operandA: 4,
        operandB: 3,
        operationType: OperationType.addition,
      );

      final described = describeExerciseForStorage(exercise);

      expect(described.exerciseType, 'arithmetic');
      expect(described.operationType, 'addition');
      expect(described.operands, {'operandA': 4, 'operandB': 3});
    });

    test('décrit un PowerExercise avec base et exposant', () {
      const exercise = PowerExercise(base: 3, exponent: 2);

      final described = describeExerciseForStorage(exercise);

      expect(described.exerciseType, 'power');
      expect(described.operationType, 'power');
      expect(described.operands, {'base': 3, 'exponent': 2});
    });

    test('décrit un SquareRootExercise avec le radicande', () {
      const exercise = SquareRootExercise(radicand: 16);

      final described = describeExerciseForStorage(exercise);

      expect(described.exerciseType, 'squareRoot');
      expect(described.operationType, 'squareRoot');
      expect(described.operands, {'radicand': 16});
    });

    test('décrit un PercentageExercise avec percent et base', () {
      const exercise = PercentageExercise(percent: 25, base: 80);

      final described = describeExerciseForStorage(exercise);

      expect(described.exerciseType, 'percentage');
      expect(described.operationType, 'percentage');
      expect(described.operands, {'percent': 25, 'base': 80});
    });
  });
}
