import 'exercise_type.dart';
import 'operation_type.dart';

/// Root of the exercise types. `sealed` makes the compiler flag every place
/// that does not handle a new subclass through a non-exhaustive `switch`
/// (rule 11: never a `default` to hide the gap). All subclasses live in this
/// file: Dart restricts the subtypes of a `sealed class` to the same
/// library.
sealed class Exercise {
  const Exercise();

  int get correctAnswer;
  ExerciseType get type;

  bool isCorrectAnswer(int submittedValue) => submittedValue == correctAnswer;
}

final class ArithmeticExercise extends Exercise {
  const ArithmeticExercise({
    required this.operandA,
    required this.operandB,
    required this.operationType,
  });

  final int operandA;
  final int operandB;
  final OperationType operationType;

  @override
  ExerciseType get type => switch (operationType) {
    OperationType.addition => ExerciseType.addition,
    OperationType.subtraction => ExerciseType.subtraction,
    OperationType.multiplication => ExerciseType.multiplication,
    OperationType.division => ExerciseType.division,
  };

  @override
  int get correctAnswer => switch (operationType) {
    OperationType.addition => operandA + operandB,
    OperationType.subtraction => operandA - operandB,
    OperationType.multiplication => operandA * operandB,
    OperationType.division => operandA ~/ operandB,
  };

  @override
  bool operator ==(Object other) =>
      other is ArithmeticExercise &&
      other.operandA == operandA &&
      other.operandB == operandB &&
      other.operationType == operationType;

  @override
  int get hashCode => Object.hash(operandA, operandB, operationType);
}

final class PowerExercise extends Exercise {
  const PowerExercise({required this.base, required this.exponent});

  final int base;
  final int exponent;

  @override
  ExerciseType get type => ExerciseType.power;

  @override
  int get correctAnswer {
    var result = 1;
    for (var i = 0; i < exponent; i++) {
      result *= base;
    }
    return result;
  }

  @override
  bool operator ==(Object other) =>
      other is PowerExercise && other.base == base && other.exponent == exponent;

  @override
  int get hashCode => Object.hash(base, exponent);
}

final class SquareRootExercise extends Exercise {
  const SquareRootExercise({required this.radicand});

  /// Always a perfect square: guaranteed by the generator (rule 10), not
  /// rechecked here.
  final int radicand;

  @override
  ExerciseType get type => ExerciseType.squareRoot;

  @override
  int get correctAnswer {
    // Incremental integer search: never a floating-point sqrt() (documented
    // pitfall — rounding errors on large values).
    var root = 0;
    while ((root + 1) * (root + 1) <= radicand) {
      root++;
    }
    return root;
  }

  @override
  bool operator ==(Object other) => other is SquareRootExercise && other.radicand == radicand;

  @override
  int get hashCode => radicand.hashCode;
}

final class PercentageExercise extends Exercise {
  const PercentageExercise({required this.percent, required this.base});

  final int percent;
  final int base;

  @override
  ExerciseType get type => ExerciseType.percentage;

  @override
  int get correctAnswer => percent * base ~/ 100;

  @override
  bool operator ==(Object other) =>
      other is PercentageExercise && other.percent == percent && other.base == base;

  @override
  int get hashCode => Object.hash(percent, base);
}
