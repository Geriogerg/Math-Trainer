import 'dart:math';

import '../models/exercise.dart';
import '../tiers/draw.dart';
import '../tiers/tier.dart';
import 'pattern_family.dart';
import 'pattern_parts.dart';

/// One question of [family] drawn at [tier] under **rules v5**
/// (`doc/levels.md` v1.4 section 5b), built backwards (rule 10): the pattern
/// first — its base, offset or factor — then the numbers, then the answer.
///
/// **Sized by tier**: a family starts with small numbers at its first tier
/// and grows with the tier, never drawing a lower tier's size. Two limits:
///
/// - the families of the spec's size table (× 5, ÷ 2, powers of 2 …) follow
///   it band by band — a row's entry holds from its tier up to the next
///   entry;
/// - every other family, at T0–T8, never uses more significant digits
///   (trailing zeros not counted) in any number it shows or in its answer
///   than the standard questions of its tier or the next one. T9 has no
///   tier above: the keypad's 10 digits bound it.
///
/// Both are checked on thousands of draws per family and tier
/// (`test/spec/levels_spec_conformance_test.dart`). Throws for a tier below
/// the family's first (rule 13). Rules v4's one-size version is
/// `patternQuestionV4`, kept so v4 games replay.
Exercise patternQuestion(PatternFamily family, Tier tier, Random r) {
  if (tier.index < family.from.index) {
    throw ArgumentError.value(
      tier,
      'tier',
      'is below ${family.name}\'s first tier (${family.from.label}).',
    );
  }
  final t = tier.index;
  return switch (family) {
    // ── Addition: operands of the tier's standard size D ─────────────────
    PatternFamily.doubles => () {
      // 48 + 49, 250 + 251; from 6 + 6 at T1 (crossing 10).
      final d = _sumDigits[t];
      final n = drawCoin(r)
          ? drawBetween(r, t == 1 ? 6 : pow10(d - 1), pow10(d) - 1)
          : 10 * _withDigits(r, d - 1);
      return sumOf(n, n + drawBetween(r, 0, 1));
    }(),
    PatternFamily.complements => () {
      // 37 + 63, 418 + 582: both D digits, the units never 0.
      final k = _sumDigits[t];
      final a =
          10 * drawBetween(r, pow10(k - 2), 9 * pow10(k - 2) - 1) +
          drawBetween(r, 1, 9);
      return sumOf(a, pow10(k) - a);
    }(),
    PatternFamily.addJustBelowRound => () {
      // 65 + 98, 347 + 199.
      final d = _sumDigits[t];
      return sumOf(
        _withDigits(r, d),
        drawBetween(r, 2, 10) * pow10(d - 1) - drawBetween(r, 1, 3),
      );
    }(),
    PatternFamily.roundNumbers => () {
      // 350 + 450 at T3, 3 500 + 4 500 at T4, 250 000 + 750 000 at T7.
      final unit = pow10(_sumDigits[t] - 2);
      return sumOf(
        unit * drawBetween(r, 11, 99),
        unit * drawBetween(r, 11, 99),
      );
    }(),
    PatternFamily.threeTerms => () {
      // 27 + 46 + 73 at T4–T5; 3-digit terms at T6 …
      final k = _sumDigits[t] - 2;
      final c =
          10 * drawBetween(r, pow10(k - 2), 9 * pow10(k - 2) - 1) +
          drawBetween(r, 1, 9);
      return threeTermsOf(c, _withDigits(r, k), pow10(k) - c);
    }(),
    PatternFamily.addJustBelowPowerOf10 => () {
      // 4 562 + 998 at T5, 73 845 + 9 999 at T6.
      final d = _sumDigits[t];
      return sumOf(_withDigits(r, d), pow10(d - 1) - drawBetween(r, 1, 3));
    }(),

    // ── Subtraction: the first operand of the tier's standard size D ─────
    PatternFamily.subtractJustBelowRound => () {
      // 742 − 198 at T3, 9 856 − 996 at T4.
      final d = _sumDigits[t];
      final round = drawBetween(r, 1, 9) * pow10(d - 1);
      return differenceOf(
        drawBetween(r, round, pow10(d) - 1),
        round - drawBetween(r, 1, 4),
      );
    }(),
    PatternFamily.fromRound => () {
      // 1 000 − 357, 10 000 − 2 486 at T4: e digits under 10^e, never a
      // multiple of 10 (the borrow runs all the way).
      final d = _sumDigits[t];
      final e = drawBetween(r, d - 1, d);
      final b =
          10 * drawBetween(r, pow10(e - 2), pow10(e - 1) - 1) +
          drawBetween(r, 1, 9);
      return differenceOf(pow10(e), b);
    }(),
    PatternFamily.acrossRound => () {
      // 5 003 − 4 997 at T4.
      final d = _sumDigits[t];
      final round = 100 * drawBetween(r, pow10(d - 3), pow10(d - 2) - 1);
      return differenceOf(
        round + drawBetween(r, 1, 9),
        round - drawBetween(r, 1, 9),
      );
    }(),
    PatternFamily.sameGapShift => () {
      // 803 − 497 at T5: one digit under the tier's standard size, the
      // shift is the point.
      final d = _sumDigits[t] - 1;
      final round = drawBetween(r, 2, 9) * pow10(d - 1);
      return differenceOf(
        drawBetween(r, round + 1, pow10(d) - 1),
        round - drawBetween(r, 1, 9),
      );
    }(),
    PatternFamily.subtractJustBelowPowerOf10 => () {
      // 84 312 − 9 998 at T6.
      final d = _sumDigits[t];
      return differenceOf(
        _withDigits(r, d),
        pow10(d - 1) - drawBetween(r, 1, 3),
      );
    }(),

    // ── Multiplication ───────────────────────────────────────────────────
    // Size table: T2 2-digit × 5 · T4 3-digit · T6 4-digit.
    PatternFamily.times5 => switch (t) {
      < 4 => productOf(drawBetween(r, 11, 99), 5),
      < 6 => productOf(_withDigits(r, 3), drawOne(r, const [5, 50])),
      _ => productOf(_withDigits(r, 4), drawOne(r, const [5, 50])),
    },
    PatternFamily.times11 => productOf(switch (t) {
      < 5 => drawBetween(r, 12, 99), // 43 × 11
      < 8 => drawBetween(r, 100, 909), // 352 × 11, at most 9 999
      _ => _withDigits(r, 3),
    }, 11),
    PatternFamily.nearBase =>
      t < 6
          // 98 × 7, 103 × 8.
          ? productOf(100 + drawSigned(r, 5), drawBetween(r, 2, 9))
          : productOf(
              1000 + drawSigned(r, 9),
              t < 8 ? drawBetween(r, 2, 9) : drawBetween(r, 11, 19),
            ),
    PatternFamily.times25 =>
      drawCoin(r)
          // 36 × 25.
          ? productOf(t < 8 ? drawBetween(r, 12, 99) : _withDigits(r, 3), 25)
          // 88 × 125 from T8; at most 79 × 125 below.
          : productOf(drawBetween(r, 12, t < 8 ? 79 : 99), 125),
    PatternFamily.differenceOfSquares => () {
      // 17 × 23, 47 × 53; around 100–300 from T8.
      final middle =
          10 * (t < 8 ? drawBetween(r, 2, 9) : drawBetween(r, 10, 30));
      final gap = drawBetween(r, 1, 9);
      return productOf(middle - gap, middle + gap);
    }(),
    PatternFamily.doublingHalving => productOf(
      // 16 × 35 (= 8 × 70).
      2 * (t < 8 ? drawBetween(r, 6, 24) : drawBetween(r, 25, 49)),
      5 * (2 * drawBetween(r, 1, 9) + 1),
    ),
    PatternFamily.times9s => switch (t) {
      // 47 × 99, 236 × 999 (T9).
      < 8 =>
        drawCoin(r)
            ? productOf(_withDigits(r, 3), 9)
            : productOf(drawBetween(r, 12, 99), 99),
      8 =>
        drawCoin(r)
            ? productOf(_withDigits(r, 3), 99)
            : productOf(drawBetween(r, 12, 99), 999),
      _ => productOf(_withDigits(r, 3), 999),
    },
    PatternFamily.sameTensUnitsTo10 => () {
      // 43 × 47; 113 × 117 from T8.
      final tens = t < 8 ? drawBetween(r, 1, 9) : drawBetween(r, 10, 31);
      final units = drawBetween(r, 1, 9);
      return productOf(10 * tens + units, 10 * tens + 10 - units);
    }(),
    PatternFamily.times101 => productOf(switch (t) {
      < 8 => drawBetween(r, 11, 99), // 47 × 101
      8 => drawBetween(r, 100, 990),
      _ => _withDigits(r, 3),
    }, 101),
    PatternFamily.powersOf2Product => () {
      // 64 × 32: the product 2^(a + b), at most 2¹³ at T6–T7, 2¹⁶ at T8.
      final sum = switch (t) {
        < 8 => 13,
        8 => 16,
        _ => 18,
      };
      final a = drawBetween(r, 3, min(9, sum - 3));
      return productOf(
        powerOf2(a),
        powerOf2(drawBetween(r, 3, min(9, sum - a))),
      );
    }(),
    PatternFamily.bothNear100 => () {
      if (t >= 8) {
        return productOf(100 + drawSigned(r, 9), 100 + drawSigned(r, 9));
      }
      // T7: 97 × 96, or 98 × 102 with the one above no further than the
      // one below — the product stays under 10 000.
      final below = drawBetween(r, 1, 9);
      return drawCoin(r)
          ? productOf(100 - below, 100 - drawBetween(r, 1, 9))
          : productOf(100 - below, 100 + drawBetween(r, 1, below));
    }(),
    PatternFamily.differenceOfSquaresHundreds => () {
      // 195 × 205 (T9).
      final middle = 100 * drawBetween(r, 1, 5);
      final gap = drawBetween(r, 1, 9);
      return productOf(middle - gap, middle + gap);
    }(),

    // ── Division: the divisor and the quotient first ─────────────────────
    // Size table: T2 up to 3 digits · T4 4 digits · T6 6 digits.
    PatternFamily.halveBig => quotientOf(
      2,
      quotientWithDigits(r, 2, switch (t) {
        < 4 => drawBetween(r, 2, 3), // 86 ÷ 2
        < 6 => 4,
        _ => drawBetween(r, 5, 6), // 486 242 ÷ 2
      }),
    ),
    PatternFamily.roundDivision => () {
      // 36 000 ÷ 400; a power of ten more from T6.
      final units = t < 6 ? const [10, 100] : const [10, 100, 1000];
      final divisor = drawBetween(r, 2, 9) * drawOne<int>(r, units);
      final quotient = drawBetween(r, 2, 12) * drawOne<int>(r, const [1, 10]);
      return quotientOf(divisor, quotient);
    }(),
    // Size table: T5 up to 4 digits · T7 6 digits.
    PatternFamily.bigBy3To5 => () {
      final divisor = drawBetween(r, 3, 5);
      final digits = t < 7 ? drawBetween(r, 3, 4) : drawBetween(r, 5, 6);
      return quotientOf(divisor, quotientWithDigits(r, divisor, digits));
    }(),
    PatternFamily.by25 =>
      // 4 875 ÷ 25: 4-digit dividends, 5-digit at T9.
      drawCoin(r)
          ? quotientOf(
              25,
              t < 9 ? drawBetween(r, 40, 399) : drawBetween(r, 400, 3999),
            )
          : quotientOf(
              125,
              t < 9 ? drawBetween(r, 8, 79) : drawBetween(r, 80, 799),
            ),
    PatternFamily.by11 => quotientOf(11, switch (t) {
      < 8 => drawBetween(r, 12, 99), // 473 ÷ 11
      8 => drawBetween(r, 100, 909),
      _ => _withDigits(r, 3),
    }),
    PatternFamily.halvingChain => () {
      // 7 344 ÷ 8: 4-digit dividends, 5-digit at T9.
      final divisor = drawOne(r, const [8, 16]);
      return quotientOf(divisor, quotientWithDigits(r, divisor, t < 9 ? 4 : 5));
    }(),
    // Size table: T7 up to 5 digits · T9 7 digits.
    PatternFamily.bigBy6To9 => () {
      final divisor = drawBetween(r, 6, 9);
      final digits = t < 9 ? drawBetween(r, 4, 5) : drawBetween(r, 6, 7);
      return quotientOf(divisor, quotientWithDigits(r, divisor, digits));
    }(),

    // ── Powers ────────────────────────────────────────────────────────────
    // Size table: T1 up to 2⁶ · T3 2⁸ · T5 2¹⁰ · T7 2¹⁶ · T9 2²⁰.
    PatternFamily.powersOf2 => PowerExercise(
      base: 2,
      exponent: drawBetween(r, _powersOf2Bands[t]!.$1, _powersOf2Bands[t]!.$2),
    ),
    // Size table: T3 up to 95² · T6 up to 205². From 25², T3's own
    // (15² is T1 content).
    PatternFamily.squaresEndingIn5 => PowerExercise(
      base: 10 * (t < 6 ? drawBetween(r, 2, 9) : drawBetween(r, 10, 20)) + 5,
      exponent: 2,
    ),
    // Size table: T4 up to 3⁴, 4³, 5³ · T6 3⁶, 4⁵, 5⁴ · T8 3⁸.
    PatternFamily.powersOf3To5 => () {
      final base = drawBetween(r, 3, 5);
      final (low, high) = _powersOf3To5Bands(t, base);
      return PowerExercise(base: base, exponent: drawBetween(r, low, high));
    }(),
    PatternFamily.squaresNear50And100 => PowerExercise(
      // 48², 97² at T5–T6; 103² from T7 (5 digits).
      base: t < 7
          ? (drawCoin(r) ? 50 + drawSigned(r, 5) : 100 - drawBetween(r, 1, 5))
          : 100 + drawSigned(r, 9),
      exponent: 2,
    ),
    PatternFamily.repunits => () {
      final (base, exponent) = drawOne(r, switch (t) {
        < 7 => const [(11, 2), (11, 3)], // 11³ = 1 331
        < 9 => const [(11, 3), (11, 4), (111, 2)], // 111² = 12 321
        _ => const [(11, 4), (111, 2), (1111, 2)],
      });
      return PowerExercise(base: base, exponent: exponent);
    }(),
    PatternFamily.squaresNear1000 => PowerExercise(
      base: 1000 + drawSigned(r, 9),
      exponent: 2,
    ),

    // ── Roots: the root first ─────────────────────────────────────────────
    // Size table: the mirror of powers of 2, two tiers later — the even
    // exponents of that band (√64 at T3 … √65 536 at T9).
    PatternFamily.rootsOfPowersOf2 => () {
      final (low, high) = _powersOf2Bands[t - 2]!;
      final half = drawBetween(r, (low + 1) ~/ 2, high ~/ 2);
      return squareRootOf(powerOf2(half));
    }(),
    PatternFamily.rootsEndingIn25 => squareRootOf(
      // √625 … √9 025 (T3's squares, the mirror of squares ending in 5);
      // √11 025 … √42 025 from T7.
      10 * (t < 7 ? drawBetween(r, 2, 9) : drawBetween(r, 10, 20)) + 5,
    ),
    PatternFamily.rootsNear100 => squareRootOf(
      // √9 409 at T5–T6; √10 201 from T7.
      t < 7 ? 100 - drawBetween(r, 1, 9) : 100 + drawSigned(r, 9),
    ),
    PatternFamily.cubeRootsRepunitAndRound => () {
      final root = drawOne(r, const [11, 20, 30, 40, 50, 60, 70, 80, 90]);
      return SquareRootExercise(radicand: root * root * root, index: 3);
    }(),
    PatternFamily.rootsNear1000 => squareRootOf(1000 + drawSigned(r, 9)),

    // ── Percentages: the percentage first, a base that makes it whole ─────
    // Size table: T2 up to 3 digits · T4 4 digits · T6 6 digits.
    PatternFamily.halfAndQuarterOfBig => () {
      final digits = switch (t) {
        < 4 => drawBetween(r, 2, 3), // 25 % of 480
        < 6 => 4,
        _ => drawBetween(r, 5, 6), // 25 % of 486 400
      };
      final percent = drawOne(r, const [50, 25]);
      final share = percent == 50 ? 2 : 4;
      return PercentageExercise(
        percent: percent,
        base: share * quotientWithDigits(r, share, digits),
      );
    }(),
    PatternFamily.swap =>
      drawCoin(r)
          ? PercentageExercise(percent: drawOne(r, swapWith25), base: 25)
          : PercentageExercise(percent: drawOne(r, swapWith50), base: 50),
    PatternFamily.percentOfBigRound => () {
      // 15 % of 2 400 000: an even 2-digit lead keeps the answer at three
      // significant digits (5q × 2h = 10 qh, qh ≤ 931).
      final (low, high) = switch (t) {
        < 7 => (2, 3),
        < 9 => (4, 5),
        _ => (5, 6),
      };
      return PercentageExercise(
        percent: drawOne(r, multiplesOf5),
        base: 2 * drawBetween(r, 6, 49) * pow10(drawBetween(r, low, high)),
      );
    }(),
    PatternFamily.nearHundredPercent => switch (drawBetween(r, 0, 3)) {
      0 => PercentageExercise(percent: 99, base: 100 * drawBetween(r, 1, 9)),
      1 => PercentageExercise(percent: 101, base: 100 * drawBetween(r, 1, 9)),
      2 => PercentageExercise(percent: 125, base: 4 * drawBetween(r, 3, 50)),
      _ => PercentageExercise(
        percent: 200,
        base: drawBetween(r, 11, t < 9 ? 499 : 999),
      ),
    },

    // ── Integrals ─────────────────────────────────────────────────────────
    // Size table: T1 b ≤ 6 · T3 b ≤ 12 · T5 b ≤ 25.
    PatternFamily.twoXFromZero => integralOf(0, switch (t) {
      < 3 => drawBetween(r, 3, 6),
      < 5 => drawBetween(r, 7, 12),
      _ => drawBetween(r, 13, 25),
    }, c1: 2),
    // Size table: T4 b ≤ 4 · T6 b ≤ 8.
    PatternFamily.threeXSquaredFromZero => integralOf(
      0,
      t < 6 ? drawBetween(r, 2, 4) : drawBetween(r, 5, 8),
      c2: 3,
    ),
    PatternFamily.twoXDifferenceOfSquares => () {
      // ∫₁₉²¹ 2x dx = 2 × 40: the answer 40 × gap × tens keeps three
      // significant digits; bounds around 100–300 from T8.
      final middle =
          10 * (t < 8 ? drawBetween(r, 1, 9) : drawBetween(r, 10, 30));
      final gap = drawBetween(r, 1, 9);
      return integralOf(middle - gap, middle + gap, c1: 2);
    }(),
    // Size table: T7 b ≤ 4 · T9 b ≤ 6.
    PatternFamily.fourXCubedFromZero => integralOf(
      0,
      t < 9 ? drawBetween(r, 2, 4) : drawBetween(r, 5, 6),
      c3: 4,
    ),
  };
}

/// The standard operand size of addition and subtraction per tier
/// (`doc/levels.md` section 5, the larger operand): T0 1 digit … T9 9.
const _sumDigits = [1, 2, 2, 3, 4, 4, 5, 6, 8, 9];

/// Powers of 2 per tier, as the size table's bands (each entry holds up to
/// the next): exponents above the band below, up to the band's limit.
const _powersOf2Bands = <int, (int, int)>{
  1: (5, 6),
  2: (5, 6),
  3: (7, 8),
  4: (7, 8),
  5: (9, 10),
  6: (9, 10),
  7: (11, 16),
  8: (11, 16),
  9: (17, 20),
};

/// Powers of 3, 4, 5 per tier and base: the size table's bands (T4, T6,
/// T8 — at T8 only 3 grows), exponents above the band below.
(int, int) _powersOf3To5Bands(int tier, int base) {
  if (tier < 6) return base == 3 ? (3, 4) : (3, 3);
  if (base == 4) return (4, 5);
  if (base == 5) return (4, 4);
  return tier < 8 ? (5, 6) : (7, 8);
}

/// A number of exactly [digits] digits (1 to 9 for one digit).
int _withDigits(Random r, int digits) =>
    drawBetween(r, digits == 1 ? 1 : pow10(digits - 1), pow10(digits) - 1);
