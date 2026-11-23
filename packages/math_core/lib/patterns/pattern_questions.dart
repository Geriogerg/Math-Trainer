import 'dart:math';

import '../models/exercise.dart';
import '../models/operation_type.dart';
import '../strategies/strategy.dart';
import '../tiers/draw.dart';
import 'pattern_family.dart';

/// One question of [family] (`doc/levels.md` section 5b), built backwards
/// (rule 10): the pattern first — its base, offset or factor — then the
/// numbers, then the answer. Never a draw followed by a check. The ranges
/// keep every answer within the keypad's 10 digits.
Exercise patternQuestion(PatternFamily family, Random r) => switch (family) {
  // ── Addition ──────────────────────────────────────────────────────────
  PatternFamily.doubles => () {
    final n = drawCoin(r) ? drawBetween(r, 6, 99) : 10 * drawBetween(r, 10, 50);
    return _add(n, n + drawBetween(r, 0, 1));
  }(),
  PatternFamily.complements =>
    drawCoin(r)
        ? () {
            // 37 + 63: units from 1 so the tens make 90 and the units 10.
            final a = 10 * drawBetween(r, 1, 8) + drawBetween(r, 1, 9);
            return _add(a, 100 - a);
          }()
        : () {
            final a = 100 * drawBetween(r, 1, 8) + drawBetween(r, 1, 99);
            return _add(a, 1000 - a);
          }(),
  PatternFamily.addJustBelowRound => _add(
    drawBetween(r, 10, 999),
    100 * drawBetween(r, 1, 9) - drawBetween(r, 1, 3),
  ),
  PatternFamily.roundNumbers => () {
    final unit = drawOne(r, const [100, 1000, 10000]);
    return _add(unit * drawBetween(r, 11, 99), unit * drawBetween(r, 11, 99));
  }(),
  PatternFamily.threeTerms => () {
    final c = 10 * drawBetween(r, 1, 8) + drawBetween(r, 1, 9);
    return ArithmeticExercise(
      operandA: c,
      operandB: drawBetween(r, 11, 99),
      operandC: 100 - c,
      operationType: OperationType.addition,
    );
  }(),
  PatternFamily.addJustBelowPowerOf10 => () {
    final power = drawOne<int>(r, const [1000, 10000, 100000]);
    return _add(
      drawBetween(r, power, 10 * power - 1),
      power - drawBetween(r, 1, 3),
    );
  }(),

  // ── Subtraction ───────────────────────────────────────────────────────
  PatternFamily.subtractJustBelowRound => () {
    final k = drawBetween(r, 1, 4);
    if (drawCoin(r)) {
      final round = 100 * drawBetween(r, 1, 9);
      return _sub(drawBetween(r, round, 999), round - k);
    }
    return _sub(drawBetween(r, 1000, 9999), 1000 - k);
  }(),
  PatternFamily.fromRound => () {
    final round = drawOne(r, const [1000, 10000]);
    // Never a multiple of 10: the borrow runs all the way.
    final b = 10 * drawBetween(r, 10, round ~/ 10 - 1) + drawBetween(r, 1, 9);
    return _sub(round, b);
  }(),
  PatternFamily.acrossRound => () {
    final round = 100 * drawBetween(r, 1, 99);
    return _sub(round + drawBetween(r, 1, 9), round - drawBetween(r, 1, 9));
  }(),
  PatternFamily.sameGapShift => () {
    final round = 100 * drawBetween(r, 2, 9);
    return _sub(drawBetween(r, round + 1, 999), round - drawBetween(r, 1, 9));
  }(),
  PatternFamily.subtractJustBelowPowerOf10 => () {
    final power = drawOne<int>(r, const [1000, 10000, 100000]);
    return _sub(
      drawBetween(r, power, 10 * power - 1),
      power - drawBetween(r, 1, 3),
    );
  }(),

  // ── Multiplication ────────────────────────────────────────────────────
  PatternFamily.times5 =>
    drawCoin(r)
        ? _mul(drawBetween(r, 11, 9999), 5)
        : _mul(drawBetween(r, 11, 999), 50),
  PatternFamily.times11 => _mul(
    drawCoin(r) ? drawBetween(r, 12, 99) : drawBetween(r, 100, 999),
    11,
  ),
  PatternFamily.nearBase => _mul(100 + _signed(r, 5), drawBetween(r, 2, 9)),
  PatternFamily.times25 => _mul(
    drawBetween(r, 12, 99),
    drawOne(r, const [25, 125]),
  ),
  PatternFamily.differenceOfSquares => () {
    final middle = 10 * drawBetween(r, 2, 9);
    final gap = drawBetween(r, 1, 9);
    return _mul(middle - gap, middle + gap);
  }(),
  PatternFamily.doublingHalving => _mul(
    2 * drawBetween(r, 6, 24),
    5 * (2 * drawBetween(r, 1, 9) + 1),
  ),
  PatternFamily.times9s => _mul(
    drawBetween(r, 12, 999),
    drawOne(r, const [9, 99, 999]),
  ),
  PatternFamily.sameTensUnitsTo10 => () {
    final tens = drawBetween(r, 1, 9);
    final units = drawBetween(r, 1, 9);
    return _mul(10 * tens + units, 10 * tens + 10 - units);
  }(),
  PatternFamily.times101 => _mul(drawBetween(r, 11, 99), 101),
  PatternFamily.powersOf2Product => _mul(
    _powerOf2(drawBetween(r, 3, 9)),
    _powerOf2(drawBetween(r, 3, 9)),
  ),
  PatternFamily.bothNear100 => _mul(100 + _signed(r, 9), 100 + _signed(r, 9)),
  PatternFamily.differenceOfSquaresHundreds => () {
    final middle = 100 * drawBetween(r, 1, 5);
    final gap = drawBetween(r, 1, 9);
    return _mul(middle - gap, middle + gap);
  }(),

  // ── Division: the divisor and the quotient first ──────────────────────
  PatternFamily.halveBig => _div(2, drawBetween(r, 500, 4999)),
  PatternFamily.roundDivision => () {
    final divisor = drawBetween(r, 2, 9) * drawOne<int>(r, const [10, 100]);
    final quotient = drawBetween(r, 2, 12) * drawOne<int>(r, const [1, 10]);
    return _div(divisor, quotient);
  }(),
  PatternFamily.bigBy3To5 => () {
    final divisor = drawBetween(r, 3, 5);
    return _div(divisor, _quotientWithDigits(r, divisor, 6));
  }(),
  PatternFamily.by25 =>
    drawCoin(r)
        ? _div(25, drawBetween(r, 40, 399))
        : _div(125, drawBetween(r, 8, 79)),
  PatternFamily.by11 => _div(11, drawBetween(r, 12, 99)),
  PatternFamily.halvingChain => () {
    final divisor = drawOne(r, const [8, 16]);
    return _div(divisor, _quotientWithDigits(r, divisor, 4));
  }(),
  PatternFamily.bigBy6To9 => () {
    final divisor = drawBetween(r, 6, 9);
    return _div(divisor, _quotientWithDigits(r, divisor, drawBetween(r, 4, 7)));
  }(),

  // ── Powers ────────────────────────────────────────────────────────────
  PatternFamily.powersOf2 => PowerExercise(
    base: 2,
    exponent: drawBetween(r, 7, 20),
  ),
  PatternFamily.squaresEndingIn5 => PowerExercise(
    base: 10 * drawBetween(r, 1, 19) + 5,
    exponent: 2,
  ),
  PatternFamily.powersOf3To5 => switch (drawBetween(r, 3, 5)) {
    3 => PowerExercise(base: 3, exponent: drawBetween(r, 4, 9)),
    4 => PowerExercise(base: 4, exponent: drawBetween(r, 3, 7)),
    _ => PowerExercise(base: 5, exponent: drawBetween(r, 3, 6)),
  },
  PatternFamily.squaresNear50And100 => PowerExercise(
    base: drawOne<int>(r, const [50, 100]) + _signed(r, 5),
    exponent: 2,
  ),
  PatternFamily.repunits => () {
    final (base, exponent) = drawOne(r, const [
      (11, 2),
      (11, 3),
      (11, 4),
      (111, 2),
      (1111, 2),
    ]);
    return PowerExercise(base: base, exponent: exponent);
  }(),
  PatternFamily.squaresNear1000 => PowerExercise(
    base: 1000 + _signed(r, 9),
    exponent: 2,
  ),

  // ── Roots: the root first ─────────────────────────────────────────────
  PatternFamily.rootsOfPowersOf2 => _squareRoot(
    _powerOf2(drawBetween(r, 4, 10)),
  ),
  PatternFamily.rootsEndingIn25 => _squareRoot(10 * drawBetween(r, 1, 19) + 5),
  PatternFamily.rootsNear100 => _squareRoot(100 + _signed(r, 9)),
  PatternFamily.cubeRootsRepunitAndRound => () {
    final root = drawOne(r, const [11, 20, 30, 40, 50, 60, 70, 80, 90]);
    return SquareRootExercise(radicand: root * root * root, index: 3);
  }(),
  PatternFamily.rootsNear1000 => _squareRoot(1000 + _signed(r, 9)),

  // ── Percentages: the percentage first, a base that makes it whole ─────
  PatternFamily.halfAndQuarterOfBig =>
    drawCoin(r)
        ? PercentageExercise(percent: 50, base: 2 * drawBetween(r, 500, 4999))
        : PercentageExercise(percent: 25, base: 4 * drawBetween(r, 250, 2499)),
  PatternFamily.swap =>
    drawCoin(r)
        ? PercentageExercise(percent: drawOne(r, _swapWith25), base: 25)
        : PercentageExercise(percent: drawOne(r, _swapWith50), base: 50),
  PatternFamily.percentOfBigRound => PercentageExercise(
    percent: drawOne(r, _multiplesOf5),
    base: drawBetween(r, 11, 99) * drawOne<int>(r, const [1000, 10000, 100000]),
  ),
  PatternFamily.nearHundredPercent => switch (drawBetween(r, 0, 3)) {
    0 => PercentageExercise(percent: 99, base: 100 * drawBetween(r, 1, 9)),
    1 => PercentageExercise(percent: 101, base: 100 * drawBetween(r, 1, 9)),
    2 => PercentageExercise(percent: 125, base: 4 * drawBetween(r, 3, 50)),
    _ => PercentageExercise(percent: 200, base: drawBetween(r, 11, 999)),
  },

  // ── Integrals ─────────────────────────────────────────────────────────
  PatternFamily.twoXFromZero => _integral(0, drawBetween(r, 5, 20), c1: 2),
  PatternFamily.threeXSquaredFromZero => _integral(
    0,
    drawBetween(r, 2, 10),
    c2: 3,
  ),
  PatternFamily.twoXDifferenceOfSquares => () {
    final middle = 10 * drawBetween(r, 1, 9);
    final gap = drawBetween(r, 1, 9);
    return _integral(middle - gap, middle + gap, c1: 2);
  }(),
  PatternFamily.fourXCubedFromZero => _integral(0, drawBetween(r, 2, 9), c3: 4),
};

ArithmeticExercise _add(int a, int b) => ArithmeticExercise(
  operandA: a,
  operandB: b,
  operationType: OperationType.addition,
);

ArithmeticExercise _sub(int a, int b) => ArithmeticExercise(
  operandA: a,
  operandB: b,
  operationType: OperationType.subtraction,
);

ArithmeticExercise _mul(int a, int b) => ArithmeticExercise(
  operandA: a,
  operandB: b,
  operationType: OperationType.multiplication,
);

/// [divisor] × [quotient] ÷ [divisor]: exact by construction.
ArithmeticExercise _div(int divisor, int quotient) => ArithmeticExercise(
  operandA: divisor * quotient,
  operandB: divisor,
  operationType: OperationType.division,
);

SquareRootExercise _squareRoot(int root) =>
    SquareRootExercise(radicand: root * root);

IntegralExercise _integral(
  int lower,
  int upper, {
  int c1 = 0,
  int c2 = 0,
  int c3 = 0,
}) =>
    IntegralExercise(lower: lower, upper: upper, c0: 0, c1: c1, c2: c2, c3: c3);

/// 1 to [max] away from 0, either side.
int _signed(Random r, int max) =>
    drawCoin(r) ? drawBetween(r, 1, max) : -drawBetween(r, 1, max);

int _powerOf2(int exponent) {
  var p = 1;
  for (var i = 0; i < exponent; i++) {
    p *= 2;
  }
  return p;
}

/// A quotient that makes `divisor × quotient` exactly [digits] digits long.
int _quotientWithDigits(Random r, int divisor, int digits) {
  var low = 1;
  for (var i = 1; i < digits; i++) {
    low *= 10;
  }
  return drawBetween(
    r,
    (low + divisor - 1) ~/ divisor,
    (10 * low - 1) ~/ divisor,
  );
}

/// Percentages whose swap with 25 % or 50 % is whole and not already a
/// friendly one (8 % of 25 = 25 % of 8).
final _swapWith25 = [
  for (var p = 4; p <= 96; p += 4)
    if (!friendlyPercentages.contains(p)) p,
];
final _swapWith50 = [
  for (var p = 2; p <= 98; p += 2)
    if (!friendlyPercentages.contains(p)) p,
];

/// 5 %, 15 % … 95 %, but 50 % (a half is the T2 family's).
final _multiplesOf5 = [
  for (var p = 5; p <= 95; p += 5)
    if (p != 50) p,
];
