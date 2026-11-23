import '../models/exercise.dart';
import '../models/exercise_type.dart';

/// Generic representation of an [Exercise] for storage: the schema needs
/// no migration when a new family appears, only this mapping changes.
typedef ExerciseStorageDescription = ({
  String exerciseType,
  String operationType,
  Map<String, Object?> operands,
});

/// Exhaustive `switch` on the sealed class [Exercise]: the compiler flags
/// this place as soon as a new subclass is added.
///
/// The [ArithmeticExercise] case is unchanged since step 2 (real rows
/// already stored): `exerciseType` stays `'arithmetic'` and `operationType`
/// carries the operation's name. The three newer variants have no
/// sub-operation: `exerciseType` and `operationType` both carry their
/// [ExerciseType]'s name.
ExerciseStorageDescription describeExerciseForStorage(Exercise exercise) {
  return switch (exercise) {
    ArithmeticExercise() => (
      exerciseType: 'arithmetic',
      operationType: exercise.operationType.name,
      operands: {'operandA': exercise.operandA, 'operandB': exercise.operandB},
    ),
    PowerExercise() => (
      exerciseType: ExerciseType.power.name,
      operationType: ExerciseType.power.name,
      operands: {'base': exercise.base, 'exponent': exercise.exponent},
    ),
    SquareRootExercise() => (
      exerciseType: ExerciseType.squareRoot.name,
      operationType: ExerciseType.squareRoot.name,
      // The index only for a cube root: square roots keep their shape.
      operands: {
        'radicand': exercise.radicand,
        if (exercise.index != 2) 'index': exercise.index,
      },
    ),
    PercentageExercise() => (
      exerciseType: ExerciseType.percentage.name,
      operationType: ExerciseType.percentage.name,
      // Tenths only when present (37.5 %): whole percentages keep their
      // shape.
      operands: {
        'percent': exercise.percent,
        'base': exercise.base,
        if (exercise.tenths != 0) 'tenths': exercise.tenths,
      },
    ),
    // Every coefficient to x³, zeros included; x⁴ only when present
    // (`doc/levels.md`, tier 9), so earlier integrals keep their shape.
    IntegralExercise() => (
      exerciseType: ExerciseType.integral.name,
      operationType: ExerciseType.integral.name,
      operands: {
        'lower': exercise.lower,
        'upper': exercise.upper,
        'c0': exercise.c0,
        'c1': exercise.c1,
        'c2': exercise.c2,
        'c3': exercise.c3,
        if (exercise.c4 != 0) 'c4': exercise.c4,
      },
    ),
  };
}
