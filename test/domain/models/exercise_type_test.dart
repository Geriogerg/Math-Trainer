import 'package:math_trainer/core/domain/models/exercise.dart';
import 'package:math_trainer/core/domain/models/exercise_type.dart';
import 'package:math_trainer/core/domain/models/operation_type.dart';
import 'package:test/test.dart';

/// `switch` exhaustif : si une valeur d'[ExerciseType] est ajoutée sans
/// entrée ici, ce fichier cesse de compiler — c'est le garde-fou voulu,
/// pas une inadvertance à corriger en ajoutant un `default`.
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
    test('${type.name} : deux instances identiques sont == et ont le même hashCode', () {
      final (a, b) = _samplePair(type);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a.type, type);
    });
  }

  test('seules les valeurs arithmétiques portent un OperationType', () {
    expect(ExerciseType.addition.operationType, OperationType.addition);
    expect(ExerciseType.subtraction.operationType, OperationType.subtraction);
    expect(ExerciseType.multiplication.operationType, OperationType.multiplication);
    expect(ExerciseType.division.operationType, OperationType.division);
    expect(ExerciseType.power.operationType, isNull);
    expect(ExerciseType.squareRoot.operationType, isNull);
    expect(ExerciseType.percentage.operationType, isNull);
  });
}
