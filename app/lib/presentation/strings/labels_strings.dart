import 'package:math_core/account/account_exception.dart';
import 'package:math_core/account/display_name.dart';
import 'package:math_core/duel/duel_mode.dart';
import 'package:math_core/method/method.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/patterns/pattern_family.dart';
import 'package:math_core/strategies/strategy.dart';
import 'package:math_core/validation/session_validation.dart';

/// The app's tables of words (Phase 6d, moved here from their own files):
/// the operations' names, the Method's names, account and refusal messages,
/// the duels' words. Every `switch` is exhaustive (rule 11): a new value is
/// a compile error in each language until it is named.
abstract interface class LabelStrings {
  /// An operation's name: "Addition", "Roots".
  String exerciseType(ExerciseType type);

  /// A pattern family's Method name (`doc/levels.md` section 9: the
  /// strategy's name, matching what the lines do).
  String patternFamily(PatternFamily family);

  /// A detected strategy's Method name.
  String strategy(Strategy strategy);

  /// What a fallback's lines do (Phase 6b commit 3, review M11).
  String fallback(MethodFallback fallback);

  /// `doc/levels.md` section 9's fallback column, by operation: a Method the
  /// core built without naming its fallback.
  String operationFallback(ExerciseType type);

  /// What the player reads for an account failure — never the raw server
  /// text, except for an unlisted failure ([detail], the only clue).
  String accountFailure(AccountFailure failure, {String? detail});

  /// Why a player name cannot be saved (names are public content).
  String nameProblem(DisplayNameProblem problem);

  /// Why a game is not on the boards; [known] `null` for a reason this
  /// build does not know (a newer server).
  String uploadRefusal(RejectionReason? known);

  /// Duels left unfinished on this device, sent when the app came back
  /// (Phase 6b commit 5), [modeName] the one mode's name or `null` for
  /// several ([count]).
  String unfinishedDuelsSent(String? modeName, int count);

  /// A duel mode as the Online tab names it.
  String duelMode(DuelMode mode);

  /// A simulated opponent's lane label.
  String get practiceOpponent;

  /// An opponent with no public name.
  String get unnamedPlayer;

  /// Won, lost or drawn, from the player's Glicko score.
  String result(double score);
}

/// LabelStrings in English.
class EnglishLabelStrings implements LabelStrings {
  const EnglishLabelStrings();

  @override
  String exerciseType(ExerciseType type) => switch (type) {
    ExerciseType.addition => 'Addition',
    ExerciseType.subtraction => 'Subtraction',
    ExerciseType.multiplication => 'Multiplication',
    ExerciseType.division => 'Division',
    ExerciseType.power => 'Powers',
    // Square and cube roots since the Levels phase (`doc/levels.md`).
    ExerciseType.squareRoot => 'Roots',
    ExerciseType.percentage => 'Percentages',
    ExerciseType.integral => 'Integrals',
  };

  @override
  String patternFamily(PatternFamily family) => switch (family) {
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
    PatternFamily.nearBase => 'Near 100 or 1\u202f000',
    PatternFamily.times25 => 'Through 100 or 1\u202f000',
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
    PatternFamily.by25 => 'Through 100 or 1\u202f000',
    PatternFamily.by11 => 'Think × 11',
    PatternFamily.halvingChain => 'Halve again',
    PatternFamily.powersOf2 => 'Double from a known power',
    PatternFamily.squaresEndingIn5 => 'Ends in 5',
    PatternFamily.powersOf3To5 => 'Split the exponent',
    PatternFamily.squaresNear50And100 => 'Near 50 or 100',
    PatternFamily.squaresNear1000 => 'Near 1\u202f000',
    PatternFamily.repunits => 'Shift and add',
    PatternFamily.rootsOfPowersOf2 => 'Halve the exponent',
    PatternFamily.rootsEndingIn25 => 'Ends in 25',
    PatternFamily.rootsNear100 => 'Near 100',
    PatternFamily.rootsNear1000 => 'Near 1\u202f000',
    PatternFamily.cubeRootsRepunitAndRound => 'Known cubes',
    PatternFamily.halfAndQuarterOfBig => 'Halve',
    PatternFamily.swap => 'Swap',
    PatternFamily.percentOfBigRound => 'From 10 %, 5 %, 1 %',
    PatternFamily.nearHundredPercent => 'Around 100 %',
    PatternFamily.twoXFromZero ||
    PatternFamily.threeXSquaredFromZero ||
    PatternFamily.fourXCubedFromZero => 'Power rule',
  };

  @override
  String strategy(Strategy strategy) => switch (strategy) {
    Strategy.compensation => 'Round up, give back',
    Strategy.subtractViaRound => 'Round what you take away',
    Strategy.doublingHalving => 'Make 10 or 100',
    Strategy.splitFactor => 'Split the factor',
    Strategy.squareNearBase => 'Near 50 or 100',
    Strategy.differenceOfSquares => 'Difference of squares',
    Strategy.swapPercentage => 'Swap',
  };

  @override
  String fallback(MethodFallback fallback) => switch (fallback) {
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

  @override
  String operationFallback(ExerciseType type) => switch (type) {
    ExerciseType.addition => 'Place value',
    ExerciseType.subtraction => 'Count up',
    ExerciseType.multiplication => 'Split the larger factor',
    ExerciseType.division => 'Think of the multiplication',
    ExerciseType.power => 'From the nearest ten',
    ExerciseType.squareRoot => 'Last digit, then bracket',
    ExerciseType.percentage => 'Build the percentage',
    ExerciseType.integral => 'Antiderivative',
  };

  @override
  String accountFailure(AccountFailure failure, {String? detail}) =>
      switch (failure) {
        AccountFailure.invalidCredentials => 'Incorrect email or password.',
        AccountFailure.emailNotConfirmed =>
          'Email not confirmed yet — open the link in the email, then try '
              'again.',
        AccountFailure.emailAlreadyUsed =>
          'An account already exists with this email.',
        AccountFailure.weakPassword =>
          // No length quoted: the minimum is set per Supabase project.
          'Password too weak — choose a longer one.',
        AccountFailure.invalidInput => 'Invalid email address.',
        AccountFailure.rateLimited =>
          'Too many attempts. Wait a few minutes before trying again.',
        AccountFailure.network =>
          'Server unreachable. Check your connection, then try again.',
        AccountFailure.humanCheck =>
          'The check that you are not a robot did not finish. Try again.',
        AccountFailure.unknown => 'Unexpected error: ${detail ?? '-'}',
      };

  @override
  String nameProblem(DisplayNameProblem problem) => switch (problem) {
    DisplayNameProblem.empty => 'Choose a player name.',
    DisplayNameProblem.tooLong =>
      'Player name: $maxDisplayNameLength characters at most.',
    DisplayNameProblem.spaces =>
      'No space at the start or the end, and one space between words.',
    DisplayNameProblem.charset =>
      "Use letters (Latin, Greek or Cyrillic), digits, spaces and . _ ' - only.",
    DisplayNameProblem.noLetter => 'Use at least one letter or digit.',
    DisplayNameProblem.blocked => 'Choose another name.',
  };

  @override
  String uploadRefusal(RejectionReason? known) => switch (known) {
    RejectionReason.levelsMismatch =>
      'Not ranked: it started from levels the server did not have (another '
          'device, or an older version of the app). Your next games use the '
          'server’s levels.',
    RejectionReason.placementAfterGames =>
      'Not ranked: a placement only counts before your first game.',
    RejectionReason.notReplayable =>
      'Not ranked: played before the app could send games to the server.',
    RejectionReason.outOfOrder =>
      'Not ranked: it reached the server after a newer game.',
    RejectionReason.typeAlreadyPlayed =>
      'Not ranked: these operations already had a level (from another '
          'device), so this placement could not set them.',
    RejectionReason.rulesRetired => 'Not ranked: played before the new levels.',
    RejectionReason.wrongPlayer ||
    RejectionReason.futureTimestamp ||
    RejectionReason.badAnswerCount ||
    RejectionReason.questionMismatch ||
    RejectionReason.correctnessMismatch ||
    RejectionReason.badElapsed ||
    null => 'Not ranked: the server could not check this game.',
  };

  @override
  String unfinishedDuelsSent(String? modeName, int count) => modeName != null
      ? 'Your unfinished $modeName duel was sent: what you had not played '
            'counts as missed.'
      : '$count unfinished duels were sent: what you had not played counts '
            'as missed.';

  @override
  String duelMode(DuelMode mode) => switch (mode) {
    DuelMode.basics => 'Basics',
    DuelMode.advanced => 'Advanced',
    DuelMode.count => 'Get the count',
  };

  @override
  final practiceOpponent = 'Practice';

  @override
  final unnamedPlayer = 'Player';

  @override
  String result(double score) => score == 1
      ? 'Won'
      : score == 0
      ? 'Lost'
      : 'Draw';
}
