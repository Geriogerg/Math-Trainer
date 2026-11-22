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
      other is PowerExercise &&
      other.base == base &&
      other.exponent == exponent;

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
  bool operator ==(Object other) =>
      other is SquareRootExercise && other.radicand == radicand;

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
      other is PercentageExercise &&
      other.percent == percent &&
      other.base == base;

  @override
  int get hashCode => Object.hash(percent, base);
}

/// The area under `p(x) = c0 + c1·x + c2·x² + c3·x³` between [lower] and
/// [upper] (Redesign phase commit 4): `∫ₐᵇ p(x) dx`. Built backwards
/// (rule 10): every `ck` is a multiple of `k + 1`, so p is the derivative of
/// an antiderivative F with whole coefficients and the answer F(b) − F(a)
/// is a whole number; every coefficient and [lower] are non-negative, so
/// p ≥ 0 on the interval and the integral is an area. Checked here by
/// `throw` (rule 13) — a stored or uploaded question is rebuilt through
/// this constructor too.
final class IntegralExercise extends Exercise {
  IntegralExercise({
    required this.lower,
    required this.upper,
    required this.c0,
    required this.c1,
    required this.c2,
    required this.c3,
  }) {
    if (lower < 0 || upper <= lower) {
      throw ArgumentError.value(
        (lower, upper),
        'lower, upper',
        'must satisfy 0 <= lower < upper.',
      );
    }
    final coefficients = [c0, c1, c2, c3];
    for (var k = 0; k < coefficients.length; k++) {
      if (coefficients[k] < 0 || coefficients[k] % (k + 1) != 0) {
        throw ArgumentError.value(
          coefficients[k],
          'c$k',
          'must be a non-negative multiple of ${k + 1}.',
        );
      }
    }
    if (coefficients.every((c) => c == 0)) {
      throw ArgumentError.value(coefficients, 'coefficients', 'all zero.');
    }
  }

  final int lower;
  final int upper;
  final int c0;
  final int c1;
  final int c2;
  final int c3;

  /// p's coefficients, `x⁰` first.
  List<int> get coefficients => [c0, c1, c2, c3];

  @override
  ExerciseType get type => ExerciseType.integral;

  /// F(upper) − F(lower), with F(x) = Σ ck / (k+1) · x^(k+1): integers
  /// only (rule 18), each `ck / (k+1)` exact by construction.
  @override
  int get correctAnswer => _antiderivative(upper) - _antiderivative(lower);

  int _antiderivative(int x) {
    var sum = 0;
    var power = x; // x^(k+1)
    final cs = coefficients;
    for (var k = 0; k < cs.length; k++) {
      sum += cs[k] ~/ (k + 1) * power;
      power *= x;
    }
    return sum;
  }

  @override
  bool operator ==(Object other) =>
      other is IntegralExercise &&
      other.lower == lower &&
      other.upper == upper &&
      other.c0 == c0 &&
      other.c1 == c1 &&
      other.c2 == c2 &&
      other.c3 == c3;

  @override
  int get hashCode => Object.hash(lower, upper, c0, c1, c2, c3);
}
