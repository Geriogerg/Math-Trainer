import 'package:math_core/method/method.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/patterns/pattern_family.dart';
import 'package:math_core/strategies/strategy.dart';

/// The strategy's name a Method shows above its lines (`doc/levels.md`
/// section 9: "the name of the strategy", minimal text; v1.6: "the strategy
/// name matches what the lines do"). The domain names none: these are the
/// app's words. [type] names a fallback the core did not describe.
String methodName(Method method, ExerciseType type) {
  if (method.family case final family?) return patternFamilyLabel(family);
  if (method.strategy case final strategy?) return strategyLabel(strategy);
  if (method.fallback case final fallback?) return fallbackLabel(fallback);
  return operationFallbackLabel(type);
}

String patternFamilyLabel(PatternFamily family) => switch (family) {
  PatternFamily.doubles => 'Doubles',
  PatternFamily.complements => 'Complements',
  PatternFamily.addJustBelowRound ||
  PatternFamily.addJustBelowPowerOf10 => 'Round up, give back',
  PatternFamily.roundNumbers => 'Count in round units',
  PatternFamily.threeTerms => 'Complements first',
  PatternFamily.subtractJustBelowRound ||
  PatternFamily.subtractJustBelowPowerOf10 => 'Round what you take away',
  PatternFamily.fromRound => 'From 999…, plus 1',
  PatternFamily.acrossRound => 'Count up across',
  PatternFamily.sameGapShift => 'Same gap',
  PatternFamily.times5 => '× 10, then halve',
  PatternFamily.times11 => '× 10, plus itself',
  PatternFamily.nearBase => 'Near 100 or 1 000',
  PatternFamily.times25 => 'Through 100 or 1 000',
  PatternFamily.differenceOfSquares ||
  PatternFamily.differenceOfSquaresHundreds ||
  PatternFamily.twoXDifferenceOfSquares => 'Difference of squares',
  PatternFamily.doublingHalving => 'Halve and double',
  PatternFamily.times9s => 'Round up, take back',
  PatternFamily.sameTensUnitsTo10 => 'Same tens, units make 10',
  PatternFamily.times101 => '× 100, plus itself',
  PatternFamily.powersOf2Product => 'Add the exponents',
  PatternFamily.bothNear100 => 'Both near 100',
  PatternFamily.halveBig => 'Split, then halve',
  PatternFamily.roundDivision => 'Drop the zeros',
  PatternFamily.bigBy3To5 || PatternFamily.bigBy6To9 => 'Split the dividend',
  PatternFamily.by25 => 'Through 100 or 1 000',
  PatternFamily.by11 => 'Think × 11',
  PatternFamily.halvingChain => 'Halve again',
  PatternFamily.powersOf2 => 'Double from a known power',
  PatternFamily.squaresEndingIn5 => 'Ends in 5',
  PatternFamily.powersOf3To5 => 'Split the exponent',
  PatternFamily.squaresNear50And100 => 'Near 50 or 100',
  PatternFamily.squaresNear1000 => 'Near 1 000',
  PatternFamily.repunits => 'Shift and add',
  PatternFamily.rootsOfPowersOf2 => 'Halve the exponent',
  PatternFamily.rootsEndingIn25 => 'Ends in 25',
  PatternFamily.rootsNear100 => 'Near 100',
  PatternFamily.rootsNear1000 => 'Near 1 000',
  PatternFamily.cubeRootsRepunitAndRound => 'Known cubes',
  PatternFamily.halfAndQuarterOfBig => 'Halve',
  PatternFamily.swap => 'Swap',
  PatternFamily.percentOfBigRound => 'From 10 %, 5 %, 1 %',
  PatternFamily.nearHundredPercent => 'Around 100 %',
  PatternFamily.twoXFromZero ||
  PatternFamily.threeXSquaredFromZero ||
  PatternFamily.fourXCubedFromZero => 'Power rule',
};

String strategyLabel(Strategy strategy) => switch (strategy) {
  Strategy.compensation => 'Round up, give back',
  Strategy.subtractViaRound => 'Round what you take away',
  Strategy.doublingHalving => 'Make 10 or 100',
  Strategy.splitFactor => 'Split the factor',
  Strategy.squareNearBase => 'Near 50 or 100',
  Strategy.differenceOfSquares => 'Difference of squares',
  Strategy.swapPercentage => 'Swap',
};

/// What a fallback's lines do (Phase 6b commit 3, review M11: "From the
/// nearest ten" stood above 2³, "Think of the multiplication" above a split
/// dividend).
String fallbackLabel(MethodFallback fallback) => switch (fallback) {
  MethodFallback.makeTen => 'Make 10',
  MethodFallback.nearDouble => 'Near a double',
  MethodFallback.countOn => 'Count on',
  MethodFallback.placeValue => 'Place value',
  MethodFallback.thinkAddition => 'Think of the addition',
  MethodFallback.countUp => 'Count up',
  MethodFallback.takeAwayInParts => 'Take away in parts',
  MethodFallback.timesOneOrTen => 'Times 1 or 10',
  MethodFallback.fives => 'Through 5 ×',
  MethodFallback.repeatedAddition => 'Add it up',
  MethodFallback.tensFirst => 'Tens first',
  MethodFallback.splitFactor => 'Split the larger factor',
  MethodFallback.thinkMultiplication => 'Think of the multiplication',
  MethodFallback.splitDividend => 'Split the dividend',
  MethodFallback.nearestTen => 'From the nearest ten',
  MethodFallback.squareTens => 'Square the tens',
  MethodFallback.multiplyOut => 'Multiply it out',
  MethodFallback.knownPower => 'A known power',
  MethodFallback.lastDigitBracket => 'Last digit, then bracket',
  MethodFallback.friendlyFraction => 'A friendly fraction',
  MethodFallback.wholeAndRest => 'The whole and the rest',
  MethodFallback.buildPercentage => 'Build the percentage',
  MethodFallback.swapAndBuild => 'Swap, then build',
  MethodFallback.antiderivative => 'Antiderivative',
  MethodFallback.productOver100 => 'Times, then ÷ 100',
};

/// `doc/levels.md` section 9's fallback column, by operation: a Method the
/// core built without naming its fallback.
String operationFallbackLabel(ExerciseType type) => switch (type) {
  ExerciseType.addition => 'Place value',
  ExerciseType.subtraction => 'Count up',
  ExerciseType.multiplication => 'Split the larger factor',
  ExerciseType.division => 'Think of the multiplication',
  ExerciseType.power => 'From the nearest ten',
  ExerciseType.squareRoot => 'Last digit, then bracket',
  ExerciseType.percentage => 'Build the percentage',
  ExerciseType.integral => 'Antiderivative',
};
