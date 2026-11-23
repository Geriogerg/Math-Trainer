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
  /// Throws if [operandC] is given to anything but an addition (rule 13).
  ArithmeticExercise({
    required this.operandA,
    required this.operandB,
    required this.operationType,
    this.operandC,
  }) {
    if (operandC != null && operationType != OperationType.addition) {
      throw ArgumentError.value(
        operandC,
        'operandC',
        'only an addition has a third term.',
      );
    }
  }

  final int operandA;
  final int operandB;
  final OperationType operationType;

  /// A third addend: "three terms, two of them complements" (27 + 46 + 73,
  /// `doc/levels.md` section 5b, rules v4). `null` for every other question.
  final int? operandC;

  @override
  ExerciseType get type => switch (operationType) {
    OperationType.addition => ExerciseType.addition,
    OperationType.subtraction => ExerciseType.subtraction,
    OperationType.multiplication => ExerciseType.multiplication,
    OperationType.division => ExerciseType.division,
  };

  @override
  int get correctAnswer => switch (operationType) {
    OperationType.addition => operandA + operandB + (operandC ?? 0),
    OperationType.subtraction => operandA - operandB,
    OperationType.multiplication => operandA * operandB,
    OperationType.division => operandA ~/ operandB,
  };

  @override
  bool operator ==(Object other) =>
      other is ArithmeticExercise &&
      other.operandA == operandA &&
      other.operandB == operandB &&
      other.operandC == operandC &&
      other.operationType == operationType;

  @override
  int get hashCode => Object.hash(operandA, operandB, operandC, operationType);
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

/// `√radicand` ([index] 2) or `∛radicand` ([index] 3, `doc/levels.md`
/// rules v2). The class keeps its name: `ExerciseType.squareRoot` is a
/// stored name, and a cube root is the same family on screen and on the
/// board ("Roots").
final class SquareRootExercise extends Exercise {
  /// Throws if [index] is not 2 or 3 (rule 13).
  SquareRootExercise({required this.radicand, this.index = 2}) {
    if (index != 2 && index != 3) {
      throw ArgumentError.value(index, 'index', 'must be 2 or 3.');
    }
  }

  /// Always a perfect square (or cube): guaranteed by the generator (rule
  /// 10), not rechecked here.
  final int radicand;

  /// 2: square root; 3: cube root.
  final int index;

  @override
  ExerciseType get type => ExerciseType.squareRoot;

  @override
  int get correctAnswer {
    // Incremental integer search: never a floating-point sqrt() (documented
    // pitfall — rounding errors on large values).
    var root = 0;
    while (_power(root + 1) <= radicand) {
      root++;
    }
    return root;
  }

  int _power(int x) => index == 2 ? x * x : x * x * x;

  @override
  bool operator ==(Object other) =>
      other is SquareRootExercise &&
      other.radicand == radicand &&
      other.index == index;

  @override
  int get hashCode => Object.hash(radicand, index);
}

/// `percent.tenths % of base`: [tenths] is the digit after the point, 0
/// except for eighths like 37.5 % (`doc/levels.md` rules v2, tier 7).
final class PercentageExercise extends Exercise {
  /// Throws if [tenths] is not a digit (rule 13).
  PercentageExercise({
    required this.percent,
    required this.base,
    this.tenths = 0,
  }) {
    if (tenths < 0 || tenths > 9) {
      throw ArgumentError.value(tenths, 'tenths', 'must be a digit.');
    }
  }

  final int percent;
  final int base;
  final int tenths;

  @override
  ExerciseType get type => ExerciseType.percentage;

  /// Exact by construction (the generator builds [base] for it): integers
  /// only, in thousandths of the base.
  @override
  int get correctAnswer => (percent * 10 + tenths) * base ~/ 1000;

  @override
  bool operator ==(Object other) =>
      other is PercentageExercise &&
      other.percent == percent &&
      other.base == base &&
      other.tenths == tenths;

  @override
  int get hashCode => Object.hash(percent, base, tenths);
}

/// The area under `p(x) = c0 + c1·x + c2·x² + c3·x³ + c4·x⁴` between
/// [lower] and [upper] (Redesign phase commit 4; `c4` and a negative term
/// since `doc/levels.md`): `∫ₐᵇ p(x) dx`. Built backwards (rule 10): every
/// `ck` is a multiple of `k + 1`, so p is the derivative of an
/// antiderivative F with whole coefficients and the answer F(b) − F(a) is a
/// whole number. p ≥ 0 on the interval, so the integral is an area: every
/// coefficient is non-negative, except at most one `cj < 0`, which a higher
/// `ck > 0` covers from the lower bound on (`ck · a^(k−j) ≥ |cj|`, so
/// `ck·x^k + cj·x^j = x^j · (ck·x^(k−j) − |cj|) ≥ 0` for every x ≥ a).
/// Checked here by `throw` (rule 13) — a stored or uploaded question is
/// rebuilt through this constructor too.
final class IntegralExercise extends Exercise {
  IntegralExercise({
    required this.lower,
    required this.upper,
    required this.c0,
    required this.c1,
    required this.c2,
    required this.c3,
    this.c4 = 0,
  }) {
    if (lower < 0 || upper <= lower) {
      throw ArgumentError.value(
        (lower, upper),
        'lower, upper',
        'must satisfy 0 <= lower < upper.',
      );
    }
    final cs = coefficients;
    for (var k = 0; k < cs.length; k++) {
      if (cs[k] % (k + 1) != 0) {
        throw ArgumentError.value(
          cs[k],
          'c$k',
          'must be a multiple of ${k + 1}.',
        );
      }
    }
    if (cs.every((c) => c == 0)) {
      throw ArgumentError.value(cs, 'coefficients', 'all zero.');
    }
    final negatives = [
      for (var k = 0; k < cs.length; k++)
        if (cs[k] < 0) k,
    ];
    if (negatives.length > 1) {
      throw ArgumentError.value(
        cs,
        'coefficients',
        'at most one may be negative.',
      );
    }
    if (negatives case [final j]) {
      var covered = false;
      for (var k = j + 1; k < cs.length; k++) {
        if (cs[k] > 0 && cs[k] * _power(lower, k - j) >= -cs[j]) {
          covered = true;
        }
      }
      if (!covered) {
        throw ArgumentError.value(
          cs,
          'coefficients',
          'c$j < 0 is not covered by a higher term from x = $lower on.',
        );
      }
    }
  }

  final int lower;
  final int upper;
  final int c0;
  final int c1;
  final int c2;
  final int c3;
  final int c4;

  /// p's coefficients, `x⁰` first.
  List<int> get coefficients => [c0, c1, c2, c3, c4];

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

  static int _power(int x, int n) {
    var result = 1;
    for (var i = 0; i < n; i++) {
      result *= x;
    }
    return result;
  }

  @override
  bool operator ==(Object other) =>
      other is IntegralExercise &&
      other.lower == lower &&
      other.upper == upper &&
      other.c0 == c0 &&
      other.c1 == c1 &&
      other.c2 == c2 &&
      other.c3 == c3 &&
      other.c4 == c4;

  @override
  int get hashCode => Object.hash(lower, upper, c0, c1, c2, c3, c4);
}
