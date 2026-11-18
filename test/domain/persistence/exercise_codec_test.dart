import 'package:math_trainer/core/domain/models/exercise.dart';
import 'package:math_trainer/core/domain/models/operation_type.dart';
import 'package:math_trainer/core/domain/persistence/exercise_codec.dart';
import 'package:test/test.dart';

void main() {
  group('describeExerciseForStorage', () {
    test('describes an ArithmeticExercise with its operands', () {
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

    test('describes a PowerExercise with base and exponent', () {
      const exercise = PowerExercise(base: 3, exponent: 2);

      final described = describeExerciseForStorage(exercise);

      expect(described.exerciseType, 'power');
      expect(described.operationType, 'power');
      expect(described.operands, {'base': 3, 'exponent': 2});
    });

    test('describes a SquareRootExercise with the radicand', () {
      const exercise = SquareRootExercise(radicand: 16);

      final described = describeExerciseForStorage(exercise);

      expect(described.exerciseType, 'squareRoot');
      expect(described.operationType, 'squareRoot');
      expect(described.operands, {'radicand': 16});
    });

    test('describes a PercentageExercise with percent and base', () {
      const exercise = PercentageExercise(percent: 25, base: 80);

      final described = describeExerciseForStorage(exercise);

      expect(described.exerciseType, 'percentage');
      expect(described.operationType, 'percentage');
      expect(described.operands, {'percent': 25, 'base': 80});
    });
  });
}
