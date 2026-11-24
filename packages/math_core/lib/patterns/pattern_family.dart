import '../models/exercise_type.dart';
import '../tiers/tier.dart';

/// The pattern families of `doc/levels.md` section 5b (rules v4 and v5):
/// numbers chosen so that a shortcut makes them easy, even when they are
/// big. Each family belongs to one operation and is drawn from the tier
/// [from] on — under v5, sized by the tier it is drawn at
/// (`patternQuestion`).
///
/// Not stored: a game's families are recomputed by replaying it
/// (`replaySessionPatterns`). The Tips page links each one to its tip.
/// The declaration order is the spec's.
enum PatternFamily {
  // Addition.
  /// 48 + 49, 250 + 251.
  doubles(ExerciseType.addition, Tier.t1),

  /// 37 + 63, 418 + 582.
  complements(ExerciseType.addition, Tier.t2),

  /// 65 + 98, 347 + 199.
  addJustBelowRound(ExerciseType.addition, Tier.t2),

  /// 3 500 + 4 500, 250 000 + 750 000.
  roundNumbers(ExerciseType.addition, Tier.t3),

  /// 27 + 46 + 73.
  threeTerms(ExerciseType.addition, Tier.t4),

  /// 4 562 + 998, 73 845 + 9 999.
  addJustBelowPowerOf10(ExerciseType.addition, Tier.t5),

  // Subtraction.
  /// 742 − 198, 9 856 − 996.
  subtractJustBelowRound(ExerciseType.subtraction, Tier.t3),

  /// 1 000 − 357, 10 000 − 2 486.
  fromRound(ExerciseType.subtraction, Tier.t4),

  /// 5 003 − 4 997.
  acrossRound(ExerciseType.subtraction, Tier.t4),

  /// 803 − 497 (= 806 − 500).
  sameGapShift(ExerciseType.subtraction, Tier.t5),

  /// 84 312 − 9 998.
  subtractJustBelowPowerOf10(ExerciseType.subtraction, Tier.t6),

  // Multiplication.
  /// 48 × 5 → 4 864 × 5 (× 10 ÷ 2), × 50.
  times5(ExerciseType.multiplication, Tier.t2),

  /// 43 × 11, 352 × 11.
  times11(ExerciseType.multiplication, Tier.t3),

  /// 98 × 7, 103 × 8.
  nearBase(ExerciseType.multiplication, Tier.t4),

  /// 36 × 25, 88 × 125.
  times25(ExerciseType.multiplication, Tier.t5),

  /// 17 × 23, 47 × 53.
  differenceOfSquares(ExerciseType.multiplication, Tier.t5),

  /// 16 × 35 (= 8 × 70).
  doublingHalving(ExerciseType.multiplication, Tier.t5),

  /// 47 × 99, 236 × 999.
  times9s(ExerciseType.multiplication, Tier.t5),

  /// 43 × 47 = 4 × 5 | 3 × 7 = 2 021.
  sameTensUnitsTo10(ExerciseType.multiplication, Tier.t6),

  /// 47 × 101.
  times101(ExerciseType.multiplication, Tier.t6),

  /// 64 × 32.
  powersOf2Product(ExerciseType.multiplication, Tier.t6),

  /// 97 × 96, 98 × 102.
  bothNear100(ExerciseType.multiplication, Tier.t7),

  /// 195 × 205.
  differenceOfSquaresHundreds(ExerciseType.multiplication, Tier.t9),

  // Division.
  /// 86 ÷ 2 → 486 242 ÷ 2.
  halveBig(ExerciseType.division, Tier.t2),

  /// 36 000 ÷ 400.
  roundDivision(ExerciseType.division, Tier.t4),

  /// 123 456 ÷ 3, 864 312 ÷ 4.
  bigBy3To5(ExerciseType.division, Tier.t5),

  /// 4 875 ÷ 25 (× 4 ÷ 100), ÷ 125.
  by25(ExerciseType.division, Tier.t5),

  /// 473 ÷ 11.
  by11(ExerciseType.division, Tier.t6),

  /// 7 344 ÷ 8, ÷ 16.
  halvingChain(ExerciseType.division, Tier.t6),

  /// 7 254 ÷ 6, 2 450 245 ÷ 7.
  bigBy6To9(ExerciseType.division, Tier.t7),

  // Powers.
  /// 2⁵ → 2²⁰.
  powersOf2(ExerciseType.power, Tier.t1),

  /// 35², 105² = 11 025.
  squaresEndingIn5(ExerciseType.power, Tier.t3),

  /// 3⁸, 4⁵, 5⁴.
  powersOf3To5(ExerciseType.power, Tier.t4),

  /// 48², 103².
  squaresNear50And100(ExerciseType.power, Tier.t5),

  /// 111² = 12 321, 11³ = 1 331.
  repunits(ExerciseType.power, Tier.t6),

  /// 997² = 994 009.
  squaresNear1000(ExerciseType.power, Tier.t9),

  // Roots.
  /// √64 → √65 536. From T3 since spec v1.4 (rules v5); v4 drew it from
  /// T2.
  rootsOfPowersOf2(ExerciseType.squareRoot, Tier.t3, Tier.t2),

  /// √7 225.
  rootsEndingIn25(ExerciseType.squareRoot, Tier.t3),

  /// √10 201.
  rootsNear100(ExerciseType.squareRoot, Tier.t5),

  /// ∛1 331, ∛8 000.
  cubeRootsRepunitAndRound(ExerciseType.squareRoot, Tier.t6),

  /// √994 009.
  rootsNear1000(ExerciseType.squareRoot, Tier.t9),

  // Percentages.
  /// 25 % of 480 → 25 % of 486 400; 50 %.
  halfAndQuarterOfBig(ExerciseType.percentage, Tier.t2),

  /// 8 % of 25, 12 % of 50.
  swap(ExerciseType.percentage, Tier.t3),

  /// 15 % of 2 400 000.
  percentOfBigRound(ExerciseType.percentage, Tier.t5),

  /// 99 % of 300, 125 % of 64; 101 %, 200 %.
  nearHundredPercent(ExerciseType.percentage, Tier.t7),

  // Integrals.
  /// ∫₀⁴ 2x dx → ∫₀²⁵ 2x dx = 25².
  twoXFromZero(ExerciseType.integral, Tier.t1),

  /// ∫₀⁵ 3x² dx = 5³.
  threeXSquaredFromZero(ExerciseType.integral, Tier.t4),

  /// ∫₁₉²¹ 2x dx = (21 − 19)(21 + 19).
  twoXDifferenceOfSquares(ExerciseType.integral, Tier.t5),

  /// ∫₀³ 4x³ dx = 3⁴.
  fourXCubedFromZero(ExerciseType.integral, Tier.t7);

  const PatternFamily(this.type, this.from, [this._v4From]);

  /// The operation it belongs to.
  final ExerciseType type;

  /// The tier it is drawn from on (and every tier above), under the
  /// current rules (`doc/levels.md` v1.4).
  final Tier from;

  /// Where rules v4 drew it from, when that differs from [from].
  final Tier? _v4From;

  /// The families of [type] drawn at [tier] under rules v5, in declaration
  /// order (never a `Set`: rule 2).
  static List<PatternFamily> availableAt(ExerciseType type, Tier tier) => [
    for (final f in values)
      if (f.type == type && f.from.index <= tier.index) f,
  ];

  /// [availableAt] as rules v4 drew it (`doc/levels.md` v1.2). Frozen: v4
  /// games replay with it.
  static List<PatternFamily> availableAtV4(ExerciseType type, Tier tier) => [
    for (final f in values)
      if (f.type == type && (f._v4From ?? f.from).index <= tier.index) f,
  ];
}
