import 'package:math_trainer/core/domain/models/exercise.dart';
import 'package:math_trainer/core/domain/models/exercise_type.dart';
import 'package:math_trainer/core/domain/models/operation_type.dart';
import 'package:test/test.dart';

/// Exhaustive `switch`: if an [ExerciseType] value is added without an
/// entry here, this file stops compiling — the intended guard, not an
/// oversight to fix by adding a `default`.
(Exercise, Exercise) _samplePair(ExerciseType type) {
  return switch (type) {
    ExerciseType.addition => (
      const ArithmeticExercise(operandA: 4, operandB: 3, operationType: OperationType.addition),
      const ArithmeticExercise(operandA: 4, operandB: 3, operationType: OperationType.addition),
    ),
    ExerciseType.subtraction => (
      const ArithmeticExercise(
        operandA: 4,
        operandB: 3,
        operationType: OperationType.subtraction,
      ),
      const ArithmeticExercise(
        operandA: 4,
        operandB: 3,
        operationType: OperationType.subtraction,
      ),
    ),
    ExerciseType.multiplication => (
      const ArithmeticExercise(
        operandA: 4,
        operandB: 3,
        operationType: OperationType.multiplication,
      ),
      const ArithmeticExercise(
        operandA: 4,
        operandB: 3,
        operationType: OperationType.multiplication,
      ),
    ),
    ExerciseType.division => (
      const ArithmeticExercise(operandA: 12, operandB: 3, operationType: OperationType.division),
      const ArithmeticExercise(operandA: 12, operandB: 3, operationType: OperationType.division),
    ),
    ExerciseType.power => (
      const PowerExercise(base: 3, exponent: 2),
      const PowerExercise(base: 3, exponent: 2),
    ),
    ExerciseType.squareRoot => (
      const SquareRootExercise(radicand: 16),
      const SquareRootExercise(radicand: 16),
    ),
    ExerciseType.percentage => (
      const PercentageExercise(percent: 10, base: 50),
      const PercentageExercise(percent: 10, base: 50),
    ),
  };
}

void main() {
  for (final type in ExerciseType.values) {
    test('${type.name}: two identical instances are == and have the same hashCode', () {
      final (a, b) = _samplePair(type);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a.type, type);
    });
  }

  test('only the arithmetic values carry an OperationType', () {
    expect(ExerciseType.addition.operationType, OperationType.addition);
    expect(ExerciseType.subtraction.operationType, OperationType.subtraction);
    expect(ExerciseType.multiplication.operationType, OperationType.multiplication);
    expect(ExerciseType.division.operationType, OperationType.division);
    expect(ExerciseType.power.operationType, isNull);
    expect(ExerciseType.squareRoot.operationType, isNull);
    expect(ExerciseType.percentage.operationType, isNull);
  });
}
