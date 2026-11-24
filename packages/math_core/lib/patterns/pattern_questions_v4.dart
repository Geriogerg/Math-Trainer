import 'dart:math';

import '../models/exercise.dart';
import '../models/operation_type.dart';
import '../tiers/draw.dart';
import 'pattern_family.dart';
import 'pattern_parts.dart';

/// One question of [family] under **rules v4** (`doc/levels.md` v1.2
/// section 5b), built backwards (rule 10): the pattern first — its base,
/// offset or factor — then the numbers, then the answer. One size for every
/// tier: a family drew its largest numbers from its first tier on (2²⁰ at
/// T1), which v5 fixed (`patternQuestion`, sized by tier). **Frozen**: v4
/// games replay with it.
Exercise patternQuestionV4(PatternFamily family, Random r) => switch (family) {
  // ── Addition ──────────────────────────────────────────────────────────
  PatternFamily.doubles => () {
    final n = drawCoin(r) ? drawBetween(r, 6, 99) : 10 * drawBetween(r, 10, 50);
    return sumOf(n, n + drawBetween(r, 0, 1));
  }(),
  PatternFamily.complements =>
    drawCoin(r)
        ? () {
            // 37 + 63: units from 1 so the tens make 90 and the units 10.
            final a = 10 * drawBetween(r, 1, 8) + drawBetween(r, 1, 9);
            return sumOf(a, 100 - a);
          }()
        : () {
            final a = 100 * drawBetween(r, 1, 8) + drawBetween(r, 1, 99);
            return sumOf(a, 1000 - a);
          }(),
  PatternFamily.addJustBelowRound => sumOf(
    drawBetween(r, 10, 999),
    100 * drawBetween(r, 1, 9) - drawBetween(r, 1, 3),
  ),
  PatternFamily.roundNumbers => () {
    final unit = drawOne(r, const [100, 1000, 10000]);
    return sumOf(unit * drawBetween(r, 11, 99), unit * drawBetween(r, 11, 99));
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
    return sumOf(
      drawBetween(r, power, 10 * power - 1),
      power - drawBetween(r, 1, 3),
    );
  }(),

  // ── Subtraction ───────────────────────────────────────────────────────
  PatternFamily.subtractJustBelowRound => () {
    final k = drawBetween(r, 1, 4);
    if (drawCoin(r)) {
      final round = 100 * drawBetween(r, 1, 9);
      return differenceOf(drawBetween(r, round, 999), round - k);
    }
    return differenceOf(drawBetween(r, 1000, 9999), 1000 - k);
  }(),
  PatternFamily.fromRound => () {
    final round = drawOne(r, const [1000, 10000]);
    // Never a multiple of 10: the borrow runs all the way.
    final b = 10 * drawBetween(r, 10, round ~/ 10 - 1) + drawBetween(r, 1, 9);
    return differenceOf(round, b);
  }(),
  PatternFamily.acrossRound => () {
    final round = 100 * drawBetween(r, 1, 99);
    return differenceOf(
      round + drawBetween(r, 1, 9),
      round - drawBetween(r, 1, 9),
    );
  }(),
  PatternFamily.sameGapShift => () {
    final round = 100 * drawBetween(r, 2, 9);
    return differenceOf(
      drawBetween(r, round + 1, 999),
      round - drawBetween(r, 1, 9),
    );
  }(),
  PatternFamily.subtractJustBelowPowerOf10 => () {
    final power = drawOne<int>(r, const [1000, 10000, 100000]);
    return differenceOf(
      drawBetween(r, power, 10 * power - 1),
      power - drawBetween(r, 1, 3),
    );
  }(),

  // ── Multiplication ────────────────────────────────────────────────────
  PatternFamily.times5 =>
    drawCoin(r)
        ? productOf(drawBetween(r, 11, 9999), 5)
        : productOf(drawBetween(r, 11, 999), 50),
  PatternFamily.times11 => productOf(
    drawCoin(r) ? drawBetween(r, 12, 99) : drawBetween(r, 100, 999),
    11,
  ),
  PatternFamily.nearBase => productOf(
    100 + drawSigned(r, 5),
    drawBetween(r, 2, 9),
  ),
  PatternFamily.times25 => productOf(
    drawBetween(r, 12, 99),
    drawOne(r, const [25, 125]),
  ),
  PatternFamily.differenceOfSquares => () {
    final middle = 10 * drawBetween(r, 2, 9);
    final gap = drawBetween(r, 1, 9);
    return productOf(middle - gap, middle + gap);
  }(),
  PatternFamily.doublingHalving => productOf(
    2 * drawBetween(r, 6, 24),
    5 * (2 * drawBetween(r, 1, 9) + 1),
  ),
  PatternFamily.times9s => productOf(
    drawBetween(r, 12, 999),
    drawOne(r, const [9, 99, 999]),
  ),
  PatternFamily.sameTensUnitsTo10 => () {
    final tens = drawBetween(r, 1, 9);
    final units = drawBetween(r, 1, 9);
    return productOf(10 * tens + units, 10 * tens + 10 - units);
  }(),
  PatternFamily.times101 => productOf(drawBetween(r, 11, 99), 101),
  PatternFamily.powersOf2Product => productOf(
    powerOf2(drawBetween(r, 3, 9)),
    powerOf2(drawBetween(r, 3, 9)),
  ),
  PatternFamily.bothNear100 => productOf(
    100 + drawSigned(r, 9),
    100 + drawSigned(r, 9),
  ),
  PatternFamily.differenceOfSquaresHundreds => () {
    final middle = 100 * drawBetween(r, 1, 5);
    final gap = drawBetween(r, 1, 9);
    return productOf(middle - gap, middle + gap);
  }(),

  // ── Division: the divisor and the quotient first ──────────────────────
  PatternFamily.halveBig => quotientOf(2, drawBetween(r, 500, 4999)),
  PatternFamily.roundDivision => () {
    final divisor = drawBetween(r, 2, 9) * drawOne<int>(r, const [10, 100]);
    final quotient = drawBetween(r, 2, 12) * drawOne<int>(r, const [1, 10]);
    return quotientOf(divisor, quotient);
  }(),
  PatternFamily.bigBy3To5 => () {
    final divisor = drawBetween(r, 3, 5);
    return quotientOf(divisor, quotientWithDigits(r, divisor, 6));
  }(),
  PatternFamily.by25 =>
    drawCoin(r)
        ? quotientOf(25, drawBetween(r, 40, 399))
        : quotientOf(125, drawBetween(r, 8, 79)),
  PatternFamily.by11 => quotientOf(11, drawBetween(r, 12, 99)),
  PatternFamily.halvingChain => () {
    final divisor = drawOne(r, const [8, 16]);
    return quotientOf(divisor, quotientWithDigits(r, divisor, 4));
  }(),
  PatternFamily.bigBy6To9 => () {
    final divisor = drawBetween(r, 6, 9);
    return quotientOf(
      divisor,
      quotientWithDigits(r, divisor, drawBetween(r, 4, 7)),
    );
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
    base: drawOne<int>(r, const [50, 100]) + drawSigned(r, 5),
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
    base: 1000 + drawSigned(r, 9),
    exponent: 2,
  ),

  // ── Roots: the root first ─────────────────────────────────────────────
  PatternFamily.rootsOfPowersOf2 => squareRootOf(
    powerOf2(drawBetween(r, 4, 10)),
  ),
  PatternFamily.rootsEndingIn25 => squareRootOf(10 * drawBetween(r, 1, 19) + 5),
  PatternFamily.rootsNear100 => squareRootOf(100 + drawSigned(r, 9)),
  PatternFamily.cubeRootsRepunitAndRound => () {
    final root = drawOne(r, const [11, 20, 30, 40, 50, 60, 70, 80, 90]);
    return SquareRootExercise(radicand: root * root * root, index: 3);
  }(),
  PatternFamily.rootsNear1000 => squareRootOf(1000 + drawSigned(r, 9)),

  // ── Percentages: the percentage first, a base that makes it whole ─────
  PatternFamily.halfAndQuarterOfBig =>
    drawCoin(r)
        ? PercentageExercise(percent: 50, base: 2 * drawBetween(r, 500, 4999))
        : PercentageExercise(percent: 25, base: 4 * drawBetween(r, 250, 2499)),
  PatternFamily.swap =>
    drawCoin(r)
        ? PercentageExercise(percent: drawOne(r, swapWith25), base: 25)
        : PercentageExercise(percent: drawOne(r, swapWith50), base: 50),
  PatternFamily.percentOfBigRound => PercentageExercise(
    percent: drawOne(r, multiplesOf5),
    base: drawBetween(r, 11, 99) * drawOne<int>(r, const [1000, 10000, 100000]),
  ),
  PatternFamily.nearHundredPercent => switch (drawBetween(r, 0, 3)) {
    0 => PercentageExercise(percent: 99, base: 100 * drawBetween(r, 1, 9)),
    1 => PercentageExercise(percent: 101, base: 100 * drawBetween(r, 1, 9)),
    2 => PercentageExercise(percent: 125, base: 4 * drawBetween(r, 3, 50)),
    _ => PercentageExercise(percent: 200, base: drawBetween(r, 11, 999)),
  },

  // ── Integrals ─────────────────────────────────────────────────────────
  PatternFamily.twoXFromZero => integralOf(0, drawBetween(r, 5, 20), c1: 2),
  PatternFamily.threeXSquaredFromZero => integralOf(
    0,
    drawBetween(r, 2, 10),
    c2: 3,
  ),
  PatternFamily.twoXDifferenceOfSquares => () {
    final middle = 10 * drawBetween(r, 1, 9);
    final gap = drawBetween(r, 1, 9);
    return integralOf(middle - gap, middle + gap, c1: 2);
  }(),
  PatternFamily.fourXCubedFromZero => integralOf(
    0,
    drawBetween(r, 2, 9),
    c3: 4,
  ),
};
