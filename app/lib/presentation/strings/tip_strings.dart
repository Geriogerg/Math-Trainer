import 'tips.dart' show TipId;

/// The tips' words (Phase 6d: moved out of `tips.dart`): each [TipId]'s
/// sentence and worked example. Plain text in the interface face: no glyph
/// the bundled fonts lack (no `∛`, no subscripts).
abstract interface class TipStrings {
  String text(TipId id);

  String example(TipId id);
}

/// TipStrings in English.
class EnglishTipStrings implements TipStrings {
  const EnglishTipStrings();

  @override
  String text(TipId id) => switch (id) {
    TipId.makeTen => 'Make 10 first, then add what is left.',
    TipId.nearDoubles => 'Doubles and near doubles: double one, then adjust.',
    TipId.pairsTo100 => 'Spot the pairs that make 100 or 1\u202f000.',
    TipId.tensThenUnits => 'Add the tens, then the units.',
    TipId.roundUpGiveBack =>
      'Round one number up, add, then take back the extra.',
    TipId.roundHundreds => 'Big round numbers: count in hundreds or thousands.',
    TipId.threeNumbers => 'Three numbers: add the pair that makes 100 first.',
    TipId.fromTheLeft => 'Add from the left, keeping a running total.',
    TipId.countUp => 'Count up from the smaller number to the larger.',
    TipId.subtractRound =>
      'Subtract a round number, then give back the difference.',
    TipId.acrossRound =>
      'Close numbers across a round one: count up through it.',
    TipId.sameGap => 'Move both numbers by the same amount: the gap stays.',
    TipId.acrossZeros =>
      'Across zeros, borrow once: subtract from 999, then add 1.',
    TipId.times9 => 'Use patterns: × 9 is × 10, minus once.',
    TipId.times5 => '× 5 is × 10, halved.',
    TipId.splitFactor => 'Split the larger factor, multiply each part, add.',
    TipId.times11 => '× 11: the two digits apart, their sum between.',
    TipId.times25 => '× 25 is × 100, divided by 4.',
    TipId.halveDouble =>
      'Halve one factor and double the other until it is easy.',
    TipId.nearRound => 'Near a round number: multiply by it, then correct.',
    TipId.aroundRound =>
      'Two numbers around a round one: its square minus the gap squared.',
    TipId.sameTensUnits10 =>
      'Same tens, units making 10: tens × next ten, then units × units.',
    TipId.times101 => '× 101: a hundred times, plus once.',
    TipId.powersOf2Product => 'Powers of 2 multiply by adding their exponents.',
    TipId.bothNear100 =>
      'Both near 100: one minus the other gap, hundreds, plus the gaps multiplied.',
    TipId.thinkMultiplication => 'Think of the multiplication it undoes.',
    TipId.halvingTwice => '÷ 4 is halving twice; ÷ 8, three times.',
    TipId.divideBy5 => '÷ 5 is doubling, then ÷ 10.',
    TipId.splitDividend =>
      'Split the number into easy parts, divide each, add.',
    TipId.dropZeros => 'Drop the same zeros from both numbers.',
    TipId.divideBy25 => '÷ 25 is × 4, then ÷ 100.',
    TipId.doublePowersOf2 => 'Powers of 2: double, again and again.',
    TipId.squareEndingIn5 =>
      'A square ending in 5: the tens times the next one, then 25.',
    TipId.splitExponent =>
      'Split the exponent: a power is a product of smaller ones.',
    TipId.binomialSquare => '(a + b)² = a² + 2ab + b².',
    TipId.nearFifty =>
      'Near 50: 2\u202f500, plus or minus 100 per step, plus the step squared.',
    TipId.repunits => '11, 111: shift and add.',
    TipId.betweenSquares => 'Place it between two squares you know.',
    TipId.halveExponent => 'A power of 2 under the root: halve its exponent.',
    TipId.lastDigit =>
      'The last digit narrows it: a square ending in 6 has a root ending in 4 or 6.',
    TipId.endingIn25 =>
      'Ending in 25: the root ends in 5; what is left is a product of neighbours.',
    TipId.cubeRootLastDigit =>
      'A cube root by its last digit: a cube ending in 7 has a root ending in 3.',
    TipId.nearHundredRoot =>
      'Just above or below 100 or 1\u202f000: square the neighbour you suspect.',
    TipId.tenPercent => '10 % moves the decimal point one place left.',
    TipId.halfQuarter => '50% is a half; 25%, a half of a half.',
    TipId.buildPercentage => 'Build any percentage from 10 %, 5 % and 1 %.',
    TipId.swapPercentage => 'Swap when it is easier: a % of b is b % of a.',
    TipId.eighth => '12.5 % is an eighth: divide by 8, then multiply.',
    TipId.nearHundredPercent =>
      'Near 100 %: the whole, plus or minus a little.',
    TipId.rectangle => 'A constant is a rectangle: height times width.',
    TipId.triangle => '2x from 0 to b is a triangle of area b².',
    TipId.antiderivative =>
      'Take the antiderivative at the top, minus at the bottom.',
    TipId.differenceOfSquares =>
      '2x from a to b is b² − a²: a difference of squares.',
    TipId.powerRule => 'The power rule: xⁿ becomes xⁿ⁺¹ ÷ (n + 1).',
  };

  @override
  String example(TipId id) => switch (id) {
    TipId.makeTen => '8 + 7 = 8 + 2 + 5 = 15',
    TipId.nearDoubles => '48 + 49 = 2 × 48 + 1 = 97',
    TipId.pairsTo100 => '37 + 63 = 90 + 10 = 100',
    TipId.tensThenUnits => '47 + 38 = 77 + 8 = 85',
    TipId.roundUpGiveBack => '47 + 68 = 47 + 70 − 2 = 115',
    TipId.roundHundreds =>
      '3\u202f500 + 4\u202f500 = 35 + 45 hundreds = 8\u202f000',
    TipId.threeNumbers => '27 + 46 + 73 = 100 + 46 = 146',
    TipId.fromTheLeft => '2\u202f468 + 785: 3\u202f168, 3\u202f248, 3\u202f253',
    TipId.countUp => '15 − 7: 7 to 10 is 3, 10 to 15 is 5, so 8',
    TipId.subtractRound => '603 − 298 = 603 − 300 + 2 = 305',
    TipId.acrossRound => '5\u202f003 − 4\u202f997 = 3 + 3 = 6',
    TipId.sameGap => '803 − 497 = 806 − 500 = 306',
    TipId.acrossZeros => '1\u202f000 − 357 = 999 − 357 + 1 = 643',
    TipId.times9 => '9 × 7 = 70 − 7 = 63',
    TipId.times5 => '14 × 5 = 140 ÷ 2 = 70',
    TipId.splitFactor => '7 × 46 = 280 + 42 = 322',
    TipId.times11 => '43 × 11 = 4 | 7 | 3 = 473',
    TipId.times25 => '36 × 25 = 3\u202f600 ÷ 4 = 900',
    TipId.halveDouble => '16 × 25 = 8 × 50 = 4 × 100 = 400',
    TipId.nearRound => '98 × 7 = 700 − 14 = 686',
    TipId.aroundRound => '47 × 53 = 50² − 3² = 2\u202f500 − 9 = 2\u202f491',
    TipId.sameTensUnits10 => '43 × 47 = 4 × 5 | 3 × 7 = 2\u202f021',
    TipId.times101 => '47 × 101 = 4\u202f700 + 47 = 4\u202f747',
    TipId.powersOf2Product => '64 × 32 = 2⁶ × 2⁵ = 2¹¹ = 2\u202f048',
    TipId.bothNear100 => '97 × 96 = 9\u202f300 + 3 × 4 = 9\u202f312',
    TipId.thinkMultiplication => '56 ÷ 8 = 7, since 7 × 8 = 56',
    TipId.halvingTwice => '28 ÷ 4: 14, 7',
    TipId.divideBy5 => '235 ÷ 5 = 470 ÷ 10 = 47',
    TipId.splitDividend => '522 ÷ 6 = 480 ÷ 6 + 42 ÷ 6 = 80 + 7 = 87',
    TipId.dropZeros => '36\u202f000 ÷ 400 = 360 ÷ 4 = 90',
    TipId.divideBy25 => '4\u202f500 ÷ 25 = 18\u202f000 ÷ 100 = 180',
    TipId.doublePowersOf2 => '2⁶: 2, 4, 8, 16, 32, 64',
    TipId.squareEndingIn5 => '35² = 3 × 4 | 25 = 1\u202f225',
    TipId.splitExponent => '3⁸ = 3⁴ × 3⁴ = 81 × 81 = 6\u202f561',
    TipId.binomialSquare => '23² = 400 + 120 + 9 = 529',
    TipId.nearFifty => '48² = 2\u202f500 − 200 + 4 = 2\u202f304',
    TipId.repunits => '111² = 11\u202f100 + 1\u202f110 + 111 = 12\u202f321',
    TipId.betweenSquares => '√169: 12² = 144, 14² = 196, so 13',
    TipId.halveExponent => '√1\u202f024 = √2¹⁰ = 2⁵ = 32',
    TipId.lastDigit => '√2\u202f116: 40² = 1\u202f600, 50² = 2\u202f500, so 46',
    TipId.endingIn25 => '√7\u202f225: 72 = 8 × 9, so 85',
    TipId.cubeRootLastDigit =>
      'Cube root of 2\u202f197: 10³ = 1\u202f000, 20³ = 8\u202f000, so 13',
    TipId.nearHundredRoot =>
      '√10\u202f201: 101² = 10\u202f000 + 200 + 1, so 101',
    TipId.tenPercent => '10% of 350 = 35',
    TipId.halfQuarter => '25% of 4\u202f864 = 2\u202f432 ÷ 2 = 1\u202f216',
    TipId.buildPercentage => '15% of 600 = 60 + 30 = 90',
    TipId.swapPercentage => '8% of 25 = 25% of 8 = 2',
    TipId.eighth => '37.5% of 64 = 3 × 8 = 24',
    TipId.nearHundredPercent => '99% of 300 = 300 − 3 = 297',
    TipId.rectangle => '∫ 3 dx from 0 to 4 = 3 × 4 = 12',
    TipId.triangle => '∫ 2x dx from 0 to 3 = 3² = 9',
    TipId.antiderivative => '∫ 3x² dx from 1 to 3 = 27 − 1 = 26',
    TipId.differenceOfSquares => '∫ 2x dx from 19 to 21 = 2 × 40 = 80',
    TipId.powerRule => '∫ 4x³ dx from 0 to 2 = 2⁴ = 16',
  };
}
