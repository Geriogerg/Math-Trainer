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
      operands: {'radicand': exercise.radicand},
    ),
    PercentageExercise() => (
      exerciseType: ExerciseType.percentage.name,
      operationType: ExerciseType.percentage.name,
      operands: {'percent': exercise.percent, 'base': exercise.base},
    ),
  };
}
