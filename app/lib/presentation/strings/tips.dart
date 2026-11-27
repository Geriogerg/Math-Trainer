import 'package:math_core/method/method.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/patterns/pattern_family.dart';
import 'package:math_core/strategies/strategy.dart';
import 'package:math_core/tiers/tip_band.dart';

/// One tip of the Tips page (`doc/levels.md`, section 8): one sentence and
/// one worked example, for an operation and a band of tiers. [strategy]
/// links it to the detector's move (Phase 5.1) and [families] to the
/// pattern families it teaches (section 5b): a Method's "More tips" lands
/// on it.
class Tip {
  const Tip(
    this.type,
    this.band,
    this.text,
    this.example, {
    this.strategy,
    this.families = const [],
  });

  final ExerciseType type;
  final TipBand band;
  final String text;
  final String example;
  final Strategy? strategy;
  final List<PatternFamily> families;
}

/// The tip a [method] follows: its family's, else its strategy's; `null`
/// for a fallback (the operation's section then).
Tip? tipFor(Method method) {
  for (final tip in tips) {
    if (method.family case final f? when tip.families.contains(f)) return tip;
    if (method.strategy case final st? when tip.strategy == st) return tip;
  }
  return null;
}

const _add = ExerciseType.addition;
const _sub = ExerciseType.subtraction;
const _mul = ExerciseType.multiplication;
const _div = ExerciseType.division;
const _pow = ExerciseType.power;
const _root = ExerciseType.squareRoot;
const _pct = ExerciseType.percentage;
const _int = ExerciseType.integral;
const _b = TipBand.beginner;
const _i = TipBand.intermediate;
const _a = TipBand.advanced;

/// The tips, in the spec's order. Plain text in the interface face: no
/// glyph the bundled fonts lack (no `∛`, no subscripts).
const tips = <Tip>[
  // Addition.
  Tip(
    _add,
    _b,
    'Make 10 first, then add what is left.',
    '8 + 7 = 8 + 2 + 5 = 15',
  ),
  Tip(
    _add,
    _b,
    'Doubles and near doubles: double one, then adjust.',
    '48 + 49 = 2 × 48 + 1 = 97',
    families: [PatternFamily.doubles],
  ),
  Tip(
    _add,
    _b,
    'Spot the pairs that make 100 or 1 000.',
    '37 + 63 = 90 + 10 = 100',
    families: [PatternFamily.complements],
  ),
  Tip(_add, _i, 'Add the tens, then the units.', '47 + 38 = 77 + 8 = 85'),
  Tip(
    _add,
    _i,
    'Round one number up, add, then take back the extra.',
    '47 + 68 = 47 + 70 − 2 = 115',
    strategy: Strategy.compensation,
    families: [
      PatternFamily.addJustBelowRound,
      PatternFamily.addJustBelowPowerOf10,
    ],
  ),
  Tip(
    _add,
    _i,
    'Big round numbers: count in hundreds or thousands.',
    '3 500 + 4 500 = 35 + 45 hundreds = 8 000',
    families: [PatternFamily.roundNumbers],
  ),
  Tip(
    _add,
    _i,
    'Three numbers: add the pair that makes 100 first.',
    '27 + 46 + 73 = 100 + 46 = 146',
    families: [PatternFamily.threeTerms],
  ),
  Tip(
    _add,
    _a,
    'Add from the left, keeping a running total.',
    '2468 + 785: 3168, 3248, 3253',
  ),
  // Subtraction.
  Tip(
    _sub,
    _b,
    'Count up from the smaller number to the larger.',
    '15 − 7: 7 to 10 is 3, 10 to 15 is 5, so 8',
  ),
  Tip(
    _sub,
    _i,
    'Subtract a round number, then give back the difference.',
    '603 − 298 = 603 − 300 + 2 = 305',
    strategy: Strategy.subtractViaRound,
    families: [
      PatternFamily.subtractJustBelowRound,
      PatternFamily.subtractJustBelowPowerOf10,
    ],
  ),
  Tip(
    _sub,
    _i,
    'Close numbers across a round one: count up through it.',
    '5 003 − 4 997 = 3 + 3 = 6',
    families: [PatternFamily.acrossRound],
  ),
  Tip(
    _sub,
    _i,
    'Move both numbers by the same amount: the gap stays.',
    '803 − 497 = 806 − 500 = 306',
    families: [PatternFamily.sameGapShift],
  ),
  Tip(
    _sub,
    _a,
    'Across zeros, borrow once: subtract from 999, then add 1.',
    '1000 − 357 = 999 − 357 + 1 = 643',
    families: [PatternFamily.fromRound],
  ),
  // Multiplication.
  Tip(
    _mul,
    _b,
    'Use patterns: × 9 is × 10, minus once.',
    '9 × 7 = 70 − 7 = 63',
    families: [PatternFamily.times9s],
  ),
  Tip(
    _mul,
    _b,
    '× 5 is × 10, halved.',
    '14 × 5 = 140 ÷ 2 = 70',
    families: [PatternFamily.times5],
  ),
  Tip(
    _mul,
    _i,
    'Split the larger factor, multiply each part, add.',
    '7 × 46 = 280 + 42 = 322',
    strategy: Strategy.splitFactor,
  ),
  Tip(
    _mul,
    _i,
    '× 11: the two digits apart, their sum between.',
    '43 × 11 = 4 | 7 | 3 = 473',
    families: [PatternFamily.times11],
  ),
  Tip(
    _mul,
    _i,
    '× 25 is × 100, divided by 4.',
    '36 × 25 = 3600 ÷ 4 = 900',
    families: [PatternFamily.times25],
  ),
  Tip(
    _mul,
    _a,
    'Halve one factor and double the other until it is easy.',
    '16 × 25 = 8 × 50 = 4 × 100 = 400',
    strategy: Strategy.doublingHalving,
    families: [PatternFamily.doublingHalving],
  ),
  Tip(
    _mul,
    _a,
    'Near a round number: multiply by it, then correct.',
    '98 × 7 = 700 − 14 = 686',
    families: [PatternFamily.nearBase],
  ),
  Tip(
    _mul,
    _a,
    'Two numbers around a round one: its square minus the gap squared.',
    '47 × 53 = 50² − 3² = 2500 − 9 = 2491',
    strategy: Strategy.differenceOfSquares,
    families: [
      PatternFamily.differenceOfSquares,
      PatternFamily.differenceOfSquaresHundreds,
    ],
  ),
  Tip(
    _mul,
    _a,
    'Same tens, units making 10: tens × next ten, then units × units.',
    '43 × 47 = 4 × 5 | 3 × 7 = 2 021',
    families: [PatternFamily.sameTensUnitsTo10],
  ),
  Tip(
    _mul,
    _a,
    '× 101: a hundred times, plus once.',
    '47 × 101 = 4 700 + 47 = 4 747',
    families: [PatternFamily.times101],
  ),
  Tip(
    _mul,
    _a,
    'Powers of 2 multiply by adding their exponents.',
    '64 × 32 = 2⁶ × 2⁵ = 2¹¹ = 2 048',
    families: [PatternFamily.powersOf2Product],
  ),
  Tip(
    _mul,
    _a,
    'Both near 100: one minus the other gap, hundreds, plus the gaps multiplied.',
    '97 × 96 = 9 300 + 3 × 4 = 9 312',
    families: [PatternFamily.bothNear100],
  ),
  // Division.
  Tip(
    _div,
    _b,
    'Think of the multiplication it undoes.',
    '56 ÷ 8 = 7, since 7 × 8 = 56',
    families: [PatternFamily.by11],
  ),
  Tip(
    _div,
    _b,
    '÷ 4 is halving twice; ÷ 8, three times.',
    '28 ÷ 4: 14, 7',
    families: [PatternFamily.halvingChain],
  ),
  Tip(_div, _i, '÷ 5 is doubling, then ÷ 10.', '235 ÷ 5 = 470 ÷ 10 = 47'),
  Tip(
    _div,
    _i,
    'Split the number into easy parts, divide each, add.',
    '522 ÷ 6 = 480 ÷ 6 + 42 ÷ 6 = 80 + 7 = 87',
    families: [
      PatternFamily.halveBig,
      PatternFamily.bigBy3To5,
      PatternFamily.bigBy6To9,
    ],
  ),
  Tip(
    _div,
    _i,
    'Drop the same zeros from both numbers.',
    '36 000 ÷ 400 = 360 ÷ 4 = 90',
    families: [PatternFamily.roundDivision],
  ),
  Tip(
    _div,
    _a,
    '÷ 25 is × 4, then ÷ 100.',
    '4500 ÷ 25 = 18000 ÷ 100 = 180',
    families: [PatternFamily.by25],
  ),
  // Powers.
  Tip(
    _pow,
    _b,
    'Powers of 2: double, again and again.',
    '2⁶: 2, 4, 8, 16, 32, 64',
    families: [PatternFamily.powersOf2],
  ),
  Tip(
    _pow,
    _i,
    'A square ending in 5: the tens times the next one, then 25.',
    '35² = 3 × 4 | 25 = 1225',
    families: [PatternFamily.squaresEndingIn5],
  ),
  Tip(
    _pow,
    _i,
    'Split the exponent: a power is a product of smaller ones.',
    '3⁸ = 3⁴ × 3⁴ = 81 × 81 = 6 561',
    families: [PatternFamily.powersOf3To5],
  ),
  Tip(_pow, _i, '(a + b)² = a² + 2ab + b².', '23² = 400 + 120 + 9 = 529'),
  Tip(
    _pow,
    _a,
    'Near 50: 2500, plus or minus 100 per step, plus the step squared.',
    '48² = 2500 − 200 + 4 = 2304',
    strategy: Strategy.squareNearBase,
    families: [
      PatternFamily.squaresNear50And100,
      PatternFamily.squaresNear1000,
    ],
  ),
  Tip(
    _pow,
    _a,
    '11, 111: shift and add.',
    '111² = 11 100 + 1 110 + 111 = 12 321',
    families: [PatternFamily.repunits],
  ),
  // Roots.
  Tip(
    _root,
    _b,
    'Place it between two squares you know.',
    '√169: 12² = 144, 14² = 196, so 13',
  ),
  Tip(
    _root,
    _b,
    'A power of 2 under the root: halve its exponent.',
    '√1024 = √2¹⁰ = 2⁵ = 32',
    families: [PatternFamily.rootsOfPowersOf2],
  ),
  Tip(
    _root,
    _i,
    'The last digit narrows it: a square ending in 6 has a root ending in 4 or 6.',
    '√2116: 40² = 1600, 50² = 2500, so 46',
  ),
  Tip(
    _root,
    _i,
    'Ending in 25: the root ends in 5; what is left is a product of neighbours.',
    '√7225: 72 = 8 × 9, so 85',
    families: [PatternFamily.rootsEndingIn25],
  ),
  Tip(
    _root,
    _a,
    'A cube root by its last digit: a cube ending in 7 has a root ending in 3.',
    'Cube root of 2197: 10³ = 1000, 20³ = 8000, so 13',
    families: [PatternFamily.cubeRootsRepunitAndRound],
  ),
  Tip(
    _root,
    _a,
    'Just above or below 100 or 1 000: square the neighbour you suspect.',
    '√10201: 101² = 10 000 + 200 + 1, so 101',
    families: [PatternFamily.rootsNear100, PatternFamily.rootsNear1000],
  ),
  // Percentages.
  Tip(
    _pct,
    _b,
    '10 % moves the decimal point one place left.',
    '10% of 350 = 35',
  ),
  Tip(
    _pct,
    _b,
    '50 % is a half; 25 %, a half of a half.',
    '25% of 4864 = 2432 ÷ 2 = 1216',
    families: [PatternFamily.halfAndQuarterOfBig],
  ),
  Tip(
    _pct,
    _i,
    'Build any percentage from 10 %, 5 % and 1 %.',
    '15% of 600 = 60 + 30 = 90',
    families: [PatternFamily.percentOfBigRound],
  ),
  Tip(
    _pct,
    _i,
    'Swap when it is easier: a % of b is b % of a.',
    '8% of 25 = 25% of 8 = 2',
    strategy: Strategy.swapPercentage,
    families: [PatternFamily.swap],
  ),
  Tip(
    _pct,
    _a,
    '12.5 % is an eighth: divide by 8, then multiply.',
    '37.5% of 64 = 3 × 8 = 24',
  ),
  Tip(
    _pct,
    _a,
    'Near 100 %: the whole, plus or minus a little.',
    '99% of 300 = 300 − 3 = 297',
    families: [PatternFamily.nearHundredPercent],
  ),
  // Integrals.
  Tip(
    _int,
    _b,
    'A constant is a rectangle: height times width.',
    '∫ 3 dx from 0 to 4 = 3 × 4 = 12',
  ),
  Tip(
    _int,
    _b,
    '2x from 0 to b is a triangle of area b².',
    '∫ 2x dx from 0 to 3 = 3² = 9',
    families: [PatternFamily.twoXFromZero],
  ),
  Tip(
    _int,
    _i,
    'Take the antiderivative at the top, minus at the bottom.',
    '∫ 3x² dx from 1 to 3 = 27 − 1 = 26',
  ),
  Tip(
    _int,
    _i,
    '2x from a to b is b² − a²: a difference of squares.',
    '∫ 2x dx from 19 to 21 = 2 × 40 = 80',
    families: [PatternFamily.twoXDifferenceOfSquares],
  ),
  Tip(
    _int,
    _a,
    'The power rule: xⁿ becomes xⁿ⁺¹ ÷ (n + 1).',
    '∫ 4x³ dx from 0 to 2 = 2⁴ = 16',
    families: [
      PatternFamily.threeXSquaredFromZero,
      PatternFamily.fourXCubedFromZero,
    ],
  ),
];
