import 'package:math_core/method/method.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/patterns/pattern_family.dart';
import 'package:math_core/strategies/strategy.dart';
import 'package:math_core/tiers/tip_band.dart';

import 'strings.dart';

/// Every tip's identity (Phase 6d): its words are in each language's
/// [TipStrings], by an exhaustive switch — a tip missing in one language
/// does not compile. Not stored.
enum TipId {
  makeTen,
  nearDoubles,
  pairsTo100,
  tensThenUnits,
  roundUpGiveBack,
  roundHundreds,
  threeNumbers,
  fromTheLeft,
  countUp,
  subtractRound,
  acrossRound,
  sameGap,
  acrossZeros,
  times9,
  times5,
  splitFactor,
  times11,
  times25,
  halveDouble,
  nearRound,
  aroundRound,
  sameTensUnits10,
  times101,
  powersOf2Product,
  bothNear100,
  thinkMultiplication,
  halvingTwice,
  divideBy5,
  splitDividend,
  dropZeros,
  divideBy25,
  doublePowersOf2,
  squareEndingIn5,
  splitExponent,
  binomialSquare,
  nearFifty,
  repunits,
  betweenSquares,
  halveExponent,
  lastDigit,
  endingIn25,
  cubeRootLastDigit,
  nearHundredRoot,
  tenPercent,
  halfQuarter,
  buildPercentage,
  swapPercentage,
  eighth,
  nearHundredPercent,
  rectangle,
  triangle,
  antiderivative,
  differenceOfSquares,
  powerRule,
}

/// One tip of the Tips page (`doc/levels.md`, section 8): one sentence and
/// one worked example, for an operation and a band of tiers. [strategy]
/// links it to the detector's move (Phase 5.1) and [families] to the
/// pattern families it teaches (section 5b): a Method's "More tips" lands
/// on it. Its words come from the interface's language.
class Tip {
  const Tip(
    this.id,
    this.type,
    this.band, {
    this.strategy,
    this.families = const [],
  });

  final TipId id;
  final ExerciseType type;
  final TipBand band;
  final Strategy? strategy;
  final List<PatternFamily> families;

  /// The tip's sentence.
  String get text => strings.tips.text(id);

  /// Its worked example.
  String get example => strings.tips.example(id);
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
  Tip(TipId.makeTen, _add, _b),
  Tip(TipId.nearDoubles, _add, _b, families: [PatternFamily.doubles]),
  Tip(TipId.pairsTo100, _add, _b, families: [PatternFamily.complements]),
  Tip(TipId.tensThenUnits, _add, _i),
  Tip(
    TipId.roundUpGiveBack,
    _add,
    _i,
    strategy: Strategy.compensation,
    families: [
      PatternFamily.addJustBelowRound,
      PatternFamily.addJustBelowPowerOf10,
    ],
  ),
  Tip(TipId.roundHundreds, _add, _i, families: [PatternFamily.roundNumbers]),
  Tip(TipId.threeNumbers, _add, _i, families: [PatternFamily.threeTerms]),
  Tip(TipId.fromTheLeft, _add, _a),
  // Subtraction.
  Tip(TipId.countUp, _sub, _b),
  Tip(
    TipId.subtractRound,
    _sub,
    _i,
    strategy: Strategy.subtractViaRound,
    families: [
      PatternFamily.subtractJustBelowRound,
      PatternFamily.subtractJustBelowPowerOf10,
    ],
  ),
  Tip(TipId.acrossRound, _sub, _i, families: [PatternFamily.acrossRound]),
  Tip(TipId.sameGap, _sub, _i, families: [PatternFamily.sameGapShift]),
  Tip(TipId.acrossZeros, _sub, _a, families: [PatternFamily.fromRound]),
  // Multiplication.
  Tip(TipId.times9, _mul, _b, families: [PatternFamily.times9s]),
  Tip(TipId.times5, _mul, _b, families: [PatternFamily.times5]),
  Tip(TipId.splitFactor, _mul, _i, strategy: Strategy.splitFactor),
  Tip(TipId.times11, _mul, _i, families: [PatternFamily.times11]),
  Tip(TipId.times25, _mul, _i, families: [PatternFamily.times25]),
  Tip(
    TipId.halveDouble,
    _mul,
    _a,
    strategy: Strategy.doublingHalving,
    families: [PatternFamily.doublingHalving],
  ),
  Tip(TipId.nearRound, _mul, _a, families: [PatternFamily.nearBase]),
  Tip(
    TipId.aroundRound,
    _mul,
    _a,
    strategy: Strategy.differenceOfSquares,
    families: [
      PatternFamily.differenceOfSquares,
      PatternFamily.differenceOfSquaresHundreds,
    ],
  ),
  Tip(
    TipId.sameTensUnits10,
    _mul,
    _a,
    families: [PatternFamily.sameTensUnitsTo10],
  ),
  Tip(TipId.times101, _mul, _a, families: [PatternFamily.times101]),
  Tip(
    TipId.powersOf2Product,
    _mul,
    _a,
    families: [PatternFamily.powersOf2Product],
  ),
  Tip(TipId.bothNear100, _mul, _a, families: [PatternFamily.bothNear100]),
  // Division.
  Tip(TipId.thinkMultiplication, _div, _b, families: [PatternFamily.by11]),
  Tip(TipId.halvingTwice, _div, _b, families: [PatternFamily.halvingChain]),
  Tip(TipId.divideBy5, _div, _i),
  Tip(
    TipId.splitDividend,
    _div,
    _i,
    families: [
      PatternFamily.halveBig,
      PatternFamily.bigBy3To5,
      PatternFamily.bigBy6To9,
    ],
  ),
  Tip(TipId.dropZeros, _div, _i, families: [PatternFamily.roundDivision]),
  Tip(TipId.divideBy25, _div, _a, families: [PatternFamily.by25]),
  // Powers.
  Tip(TipId.doublePowersOf2, _pow, _b, families: [PatternFamily.powersOf2]),
  Tip(
    TipId.squareEndingIn5,
    _pow,
    _i,
    families: [PatternFamily.squaresEndingIn5],
  ),
  Tip(TipId.splitExponent, _pow, _i, families: [PatternFamily.powersOf3To5]),
  Tip(TipId.binomialSquare, _pow, _i),
  Tip(
    TipId.nearFifty,
    _pow,
    _a,
    strategy: Strategy.squareNearBase,
    families: [
      PatternFamily.squaresNear50And100,
      PatternFamily.squaresNear1000,
    ],
  ),
  Tip(TipId.repunits, _pow, _a, families: [PatternFamily.repunits]),
  // Roots.
  Tip(TipId.betweenSquares, _root, _b),
  Tip(
    TipId.halveExponent,
    _root,
    _b,
    families: [PatternFamily.rootsOfPowersOf2],
  ),
  Tip(TipId.lastDigit, _root, _i),
  Tip(TipId.endingIn25, _root, _i, families: [PatternFamily.rootsEndingIn25]),
  Tip(
    TipId.cubeRootLastDigit,
    _root,
    _a,
    families: [PatternFamily.cubeRootsRepunitAndRound],
  ),
  Tip(
    TipId.nearHundredRoot,
    _root,
    _a,
    families: [PatternFamily.rootsNear100, PatternFamily.rootsNear1000],
  ),
  // Percentages.
  Tip(TipId.tenPercent, _pct, _b),
  Tip(
    TipId.halfQuarter,
    _pct,
    _b,
    families: [PatternFamily.halfAndQuarterOfBig],
  ),
  Tip(
    TipId.buildPercentage,
    _pct,
    _i,
    families: [PatternFamily.percentOfBigRound],
  ),
  Tip(
    TipId.swapPercentage,
    _pct,
    _i,
    strategy: Strategy.swapPercentage,
    families: [PatternFamily.swap],
  ),
  Tip(TipId.eighth, _pct, _a),
  Tip(
    TipId.nearHundredPercent,
    _pct,
    _a,
    families: [PatternFamily.nearHundredPercent],
  ),
  // Integrals.
  Tip(TipId.rectangle, _int, _b),
  Tip(TipId.triangle, _int, _b, families: [PatternFamily.twoXFromZero]),
  Tip(TipId.antiderivative, _int, _i),
  Tip(
    TipId.differenceOfSquares,
    _int,
    _i,
    families: [PatternFamily.twoXDifferenceOfSquares],
  ),
  Tip(
    TipId.powerRule,
    _int,
    _a,
    families: [
      PatternFamily.threeXSquaredFromZero,
      PatternFamily.fourXCubedFromZero,
    ],
  ),
];
