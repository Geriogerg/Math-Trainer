import '../models/exercise.dart';
import '../models/operation_type.dart';

/// The mental-math strategies of the plan (section 6.1), one per row of its
/// table. Names may be stored once tips are shown (Phase 4): never rename.
enum Strategy {
  compensation,
  subtractViaRound,
  doublingHalving,
  splitFactor,
  squareNearBase,
  differenceOfSquares,
  swapPercentage,
}

/// The best move for one exercise (Phase 5.1 commit 2, Phase 4's detector
/// moved earlier): which strategy, and the numbers of its worked line —
/// what a one-line tip will show after an error or a slow answer (Phase 4).
/// Nothing in the app reads it yet.
///
/// Every move recomputes the answer its own way ([result]): the tests check
/// it equals the exercise's answer, so a move can never teach a wrong line.
sealed class StrategyMove {
  const StrategyMove();

  Strategy get strategy;

  /// The answer, reached through the move's own steps.
  int get result;
}

/// 47 + 68 = 47 + 70 − 2: an operand ending in 7, 8 or 9 goes up to the
/// next ten, and the difference comes back off.
final class CompensationMove extends StrategyMove {
  const CompensationMove({
    required this.kept,
    required this.rounded,
    required this.adjustment,
  });

  final int kept;
  final int rounded;

  /// What rounding added (1 to 3), taken off at the end.
  final int adjustment;

  @override
  Strategy get strategy => Strategy.compensation;

  @override
  int get result => kept + rounded - adjustment;

  @override
  bool operator ==(Object other) =>
      other is CompensationMove &&
      other.kept == kept &&
      other.rounded == rounded &&
      other.adjustment == adjustment;

  @override
  int get hashCode => Object.hash(kept, rounded, adjustment);
}

/// 603 − 298 = 603 − 300 + 2: subtract the round number next to the
/// subtrahend, then correct by the distance.
final class SubtractViaRoundMove extends StrategyMove {
  const SubtractViaRoundMove({
    required this.minuend,
    required this.rounded,
    required this.correction,
  });

  final int minuend;
  final int rounded;

  /// Added back when [rounded] took off too much (298 → 300: +2), taken off
  /// when it took off too little (302 → 300: −2).
  final int correction;

  @override
  Strategy get strategy => Strategy.subtractViaRound;

  @override
  int get result => minuend - rounded + correction;

  @override
  bool operator ==(Object other) =>
      other is SubtractViaRoundMove &&
      other.minuend == minuend &&
      other.rounded == rounded &&
      other.correction == correction;

  @override
  int get hashCode => Object.hash(minuend, rounded, correction);
}

/// 25 × 16 = 100 × 4: the factor 5, 25 or 50 becomes 10 or 100 while the
/// other factor is divided by the same amount.
final class DoublingHalvingMove extends StrategyMove {
  const DoublingHalvingMove({required this.round, required this.other});

  /// 10 or 100.
  final int round;
  final int other;

  @override
  Strategy get strategy => Strategy.doublingHalving;

  @override
  int get result => round * other;

  @override
  bool operator ==(Object other) =>
      other is DoublingHalvingMove &&
      other.round == round &&
      other.other == this.other;

  @override
  int get hashCode => Object.hash(round, other);
}

/// 7 × 46 = 280 + 42: the two-digit factor split into tens and units.
final class SplitFactorMove extends StrategyMove {
  const SplitFactorMove({
    required this.digit,
    required this.tens,
    required this.units,
  });

  final int digit;

  /// 40 for 46.
  final int tens;

  /// 6 for 46.
  final int units;

  @override
  Strategy get strategy => Strategy.splitFactor;

  @override
  int get result => digit * tens + digit * units;

  @override
  bool operator ==(Object other) =>
      other is SplitFactorMove &&
      other.digit == digit &&
      other.tens == tens &&
      other.units == units;

  @override
  int get hashCode => Object.hash(digit, tens, units);
}

/// 48² = 2500 − 200 + 4: (base + offset)² = base² + 2 × base × offset +
/// offset², with base 50 or 100.
final class SquareNearBaseMove extends StrategyMove {
  const SquareNearBaseMove({required this.base, required this.offset});

  final int base;

  /// Signed: −2 for 48 near 50.
  final int offset;

  @override
  Strategy get strategy => Strategy.squareNearBase;

  @override
  int get result => base * base + 2 * base * offset + offset * offset;

  @override
  bool operator ==(Object other) =>
      other is SquareNearBaseMove &&
      other.base == base &&
      other.offset == offset;

  @override
  int get hashCode => Object.hash(base, offset);
}

/// 47 × 53 = 50² − 3²: two factors evenly around a round number.
final class DifferenceOfSquaresMove extends StrategyMove {
  const DifferenceOfSquaresMove({required this.middle, required this.gap});

  final int middle;

  /// Half the distance between the factors.
  final int gap;

  @override
  Strategy get strategy => Strategy.differenceOfSquares;

  @override
  int get result => middle * middle - gap * gap;

  @override
  bool operator ==(Object other) =>
      other is DifferenceOfSquaresMove &&
      other.middle == middle &&
      other.gap == gap;

  @override
  int get hashCode => Object.hash(middle, gap);
}

/// 8% of 25 = 25% of 8: p% of n equals n% of p, and the swapped one is a
/// friendly percentage.
final class SwapPercentageMove extends StrategyMove {
  const SwapPercentageMove({required this.percent, required this.base});

  /// The swapped, friendly percentage (25 in the example).
  final int percent;

  /// The swapped base (8 in the example).
  final int base;

  @override
  Strategy get strategy => Strategy.swapPercentage;

  @override
  int get result => percent * base ~/ 100;

  @override
  bool operator ==(Object other) =>
      other is SwapPercentageMove &&
      other.percent == percent &&
      other.base == base;

  @override
  int get hashCode => Object.hash(percent, base);
}

/// Percentages computed at a glance: a tenth, a fifth, a quarter, a half,
/// three quarters.
const friendlyPercentages = {10, 20, 25, 50, 75};

/// The best strategy for [exercise], or `null` when none of the plan's
/// table fits (a single-digit sum, a division, a square root…). Where two
/// fit, the one with fewer steps wins: doubling and halving (one product)
/// before the difference of squares (two squares) before splitting a factor
/// (two products and a sum).
StrategyMove? bestStrategy(Exercise exercise) => switch (exercise) {
  ArithmeticExercise(:final operandA, :final operandB, :final operationType) =>
    switch (operationType) {
      OperationType.addition => _compensation(operandA, operandB),
      OperationType.subtraction => _subtractViaRound(operandA, operandB),
      OperationType.multiplication =>
        _doublingHalving(operandA, operandB) ??
            _differenceOfSquares(operandA, operandB) ??
            _splitFactor(operandA, operandB),
      OperationType.division => null,
    },
  PowerExercise(:final base, :final exponent) =>
    exponent == 2 ? _squareNearBase(base) : null,
  SquareRootExercise() => null,
  IntegralExercise() => null,
  PercentageExercise(:final percent, :final base) => _swapPercentage(
    percent,
    base,
  ),
};

/// Up to the next ten: the operand ending in 9 first (one to give back),
/// then 8, then 7; the second operand on a tie. Single digits too
/// (47 + 9 = 47 + 10 − 1).
CompensationMove? _compensation(int a, int b) {
  int? gap(int n) => switch (n % 10) {
    9 => 1,
    8 => 2,
    7 => 3,
    _ => null,
  };
  final gapA = a > 0 ? gap(a) : null;
  final gapB = b > 0 ? gap(b) : null;
  if (gapB != null && (gapA == null || gapB <= gapA)) {
    return CompensationMove(kept: a, rounded: b + gapB, adjustment: gapB);
  }
  if (gapA != null) {
    return CompensationMove(kept: b, rounded: a + gapA, adjustment: gapA);
  }
  return null;
}

/// The subtrahend within 3 of a round number, not on it: the coarsest
/// round number that close (298 → 300, not 290…); from 10 up.
SubtractViaRoundMove? _subtractViaRound(int minuend, int subtrahend) {
  if (subtrahend < 7) return null;
  for (final step in [1000, 100, 10]) {
    if (subtrahend < step) continue;
    final nearest = (subtrahend + step ~/ 2) ~/ step * step;
    final distance = nearest - subtrahend;
    if (distance != 0 && distance.abs() <= 3) {
      return SubtractViaRoundMove(
        minuend: minuend,
        rounded: nearest,
        correction: distance,
      );
    }
    if (distance == 0) return null;
  }
  // 7, 8, 9 → 10 (below the first step).
  if (subtrahend < 10) {
    return SubtractViaRoundMove(
      minuend: minuend,
      rounded: 10,
      correction: 10 - subtrahend,
    );
  }
  return null;
}

/// 5 → 10 (other even), 25 → 100 (other a multiple of 4), 50 → 100 (other
/// even). Either factor.
DoublingHalvingMove? _doublingHalving(int a, int b) {
  DoublingHalvingMove? tryWith(int factor, int other) => switch (factor) {
    5 when other.isEven && other > 0 => DoublingHalvingMove(
      round: 10,
      other: other ~/ 2,
    ),
    25 when other % 4 == 0 && other > 0 => DoublingHalvingMove(
      round: 100,
      other: other ~/ 4,
    ),
    50 when other.isEven && other > 0 => DoublingHalvingMove(
      round: 100,
      other: other ~/ 2,
    ),
    _ => null,
  };
  return tryWith(a, b) ?? tryWith(b, a);
}

/// Factors evenly around a multiple of ten, 1 to 9 away from it.
DifferenceOfSquaresMove? _differenceOfSquares(int a, int b) {
  if (a == b || (a + b).isOdd) return null;
  final middle = (a + b) ~/ 2;
  final gap = (a - b).abs() ~/ 2;
  if (middle % 10 != 0 || middle == 0 || gap > 9) return null;
  return DifferenceOfSquaresMove(middle: middle, gap: gap);
}

/// One-digit (2–9) × two-digit (not a multiple of ten: nothing to split).
SplitFactorMove? _splitFactor(int a, int b) {
  SplitFactorMove? tryWith(int digit, int other) {
    if (digit < 2 || digit > 9) return null;
    if (other < 11 || other > 99 || other % 10 == 0) return null;
    return SplitFactorMove(
      digit: digit,
      tens: other ~/ 10 * 10,
      units: other % 10,
    );
  }

  return tryWith(a, b) ?? tryWith(b, a);
}

/// 45–55 around 50, 95–105 around 100; the base itself has nothing to do.
SquareNearBaseMove? _squareNearBase(int n) {
  for (final base in [50, 100]) {
    final offset = n - base;
    if (offset != 0 && offset.abs() <= 5) {
      return SquareNearBaseMove(base: base, offset: offset);
    }
  }
  return null;
}

/// p% of n → n% of p, when n is friendly and p is not (8% of 25).
SwapPercentageMove? _swapPercentage(int percent, int base) {
  if (friendlyPercentages.contains(percent)) return null;
  if (!friendlyPercentages.contains(base)) return null;
  return SwapPercentageMove(percent: base, base: percent);
}
