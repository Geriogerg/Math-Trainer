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
  });
}
