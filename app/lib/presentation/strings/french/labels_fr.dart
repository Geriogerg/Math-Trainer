import 'package:math_core/account/account_exception.dart';
import 'package:math_core/account/display_name.dart';
import 'package:math_core/duel/duel_mode.dart';
import 'package:math_core/method/method.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/patterns/pattern_family.dart';
import 'package:math_core/strategies/strategy.dart';
import 'package:math_core/validation/session_validation.dart';

import '../labels_strings.dart';

/// [LabelStrings] en français (Phase 6d).
class FrenchLabelStrings implements LabelStrings {
  const FrenchLabelStrings();

  @override
  String exerciseType(ExerciseType type) => switch (type) {
    ExerciseType.addition => 'Addition',
    ExerciseType.subtraction => 'Soustraction',
    ExerciseType.multiplication => 'Multiplication',
    ExerciseType.division => 'Division',
    ExerciseType.power => 'Puissances',
    ExerciseType.squareRoot => 'Racines',
    ExerciseType.percentage => 'Pourcentages',
    ExerciseType.integral => 'Intégrales',
  };

  @override
  String patternFamily(PatternFamily family) => switch (family) {
    PatternFamily.doubles => 'Doubles',
    PatternFamily.complements => 'Compléments',
    PatternFamily.addJustBelowRound ||
    PatternFamily.addJustBelowPowerOf10 => 'Arrondir, puis rendre',
    PatternFamily.roundNumbers => 'Compter en unités rondes',
    PatternFamily.threeTerms => 'Compléments d’abord',
    PatternFamily.subtractJustBelowRound ||
    PatternFamily.subtractJustBelowPowerOf10 => 'Arrondir ce qu’on retire',
    PatternFamily.fromRound => 'Depuis 999…, plus 1',
    PatternFamily.acrossRound => 'Compter en traversant',
    PatternFamily.sameGapShift => 'Même écart',
    PatternFamily.times5 => '× 10, puis la moitié',
    PatternFamily.times11 => '× 10, plus lui-même',
    PatternFamily.nearBase => 'Près de 100 ou 1\u202f000',
    PatternFamily.times25 => 'Par 100 ou 1\u202f000',
    PatternFamily.differenceOfSquares ||
    PatternFamily.differenceOfSquaresHundreds ||
    PatternFamily.twoXDifferenceOfSquares => 'Différence de carrés',
    PatternFamily.doublingHalving => 'Moitié et double',
    PatternFamily.times9s => 'Arrondir, puis retirer',
    PatternFamily.sameTensUnitsTo10 => 'Mêmes dizaines, unités à 10',
    PatternFamily.times101 => '× 100, plus lui-même',
    PatternFamily.powersOf2Product => 'Ajouter les exposants',
    PatternFamily.bothNear100 => 'Tous deux près de 100',
    PatternFamily.halveBig => 'Couper, puis la moitié',
    PatternFamily.roundDivision => 'Enlever les zéros',
    PatternFamily.bigBy3To5 || PatternFamily.bigBy6To9 => 'Couper le dividende',
    PatternFamily.by25 => 'Par 100 ou 1\u202f000',
    PatternFamily.by11 => 'Penser × 11',
    PatternFamily.halvingChain => 'Encore la moitié',
    PatternFamily.powersOf2 => 'Doubler depuis une puissance connue',
    PatternFamily.squaresEndingIn5 => 'Finit par 5',
    PatternFamily.powersOf3To5 => 'Couper l’exposant',
    PatternFamily.squaresNear50And100 => 'Près de 50 ou 100',
    PatternFamily.squaresNear1000 => 'Près de 1\u202f000',
    PatternFamily.repunits => 'Décaler et additionner',
    PatternFamily.rootsOfPowersOf2 => 'Diviser l’exposant par 2',
    PatternFamily.rootsEndingIn25 => 'Finit par 25',
    PatternFamily.rootsNear100 => 'Près de 100',
    PatternFamily.rootsNear1000 => 'Près de 1\u202f000',
    PatternFamily.cubeRootsRepunitAndRound => 'Cubes connus',
    PatternFamily.halfAndQuarterOfBig => 'La moitié',
    PatternFamily.swap => 'Inverser',
    PatternFamily.percentOfBigRound => 'Depuis 10\u202f%, 5\u202f%, 1\u202f%',
    PatternFamily.nearHundredPercent => 'Autour de 100\u202f%',
    PatternFamily.twoXFromZero ||
    PatternFamily.threeXSquaredFromZero ||
    PatternFamily.fourXCubedFromZero => 'Règle des puissances',
  };

  @override
  String strategy(Strategy strategy) => switch (strategy) {
    Strategy.compensation => 'Arrondir, puis rendre',
    Strategy.subtractViaRound => 'Arrondir ce qu’on retire',
    Strategy.doublingHalving => 'Faire 10 ou 100',
    Strategy.splitFactor => 'Couper le facteur',
    Strategy.squareNearBase => 'Près de 50 ou 100',
    Strategy.differenceOfSquares => 'Différence de carrés',
    Strategy.swapPercentage => 'Inverser',
  };

  @override
  String fallback(MethodFallback fallback) => switch (fallback) {
    MethodFallback.makeTen => 'Faire 10',
    MethodFallback.nearDouble => 'Presque un double',
    MethodFallback.countOn => 'Compter en avançant',
    MethodFallback.placeValue => 'Par rangs',
    MethodFallback.thinkAddition => 'Penser à l’addition',
    MethodFallback.countUp => 'Compter jusqu’au nombre',
    MethodFallback.takeAwayInParts => 'Retirer par morceaux',
    MethodFallback.timesOneOrTen => 'Fois 1 ou 10',
    MethodFallback.fives => 'Par 5 ×',
    MethodFallback.repeatedAddition => 'Additionner',
    MethodFallback.tensFirst => 'Les dizaines d’abord',
    MethodFallback.splitFactor => 'Couper le plus grand facteur',
    MethodFallback.thinkMultiplication => 'Penser à la multiplication',
    MethodFallback.splitDividend => 'Couper le dividende',
    MethodFallback.nearestTen => 'Depuis la dizaine la plus proche',
    MethodFallback.squareTens => 'Les dizaines au carré',
    MethodFallback.multiplyOut => 'Multiplier',
    MethodFallback.knownPower => 'Une puissance connue',
    MethodFallback.lastDigitBracket => 'Dernier chiffre, puis encadrer',
    MethodFallback.friendlyFraction => 'Une fraction simple',
    MethodFallback.wholeAndRest => 'Le tout et le reste',
    MethodFallback.buildPercentage => 'Construire le pourcentage',
    MethodFallback.swapAndBuild => 'Inverser, puis construire',
    MethodFallback.antiderivative => 'Primitive',
    MethodFallback.productOver100 => 'Multiplier, puis ÷ 100',
  };

  @override
  String operationFallback(ExerciseType type) => switch (type) {
    ExerciseType.addition => 'Par rangs',
    ExerciseType.subtraction => 'Compter jusqu’au nombre',
    ExerciseType.multiplication => 'Couper le plus grand facteur',
    ExerciseType.division => 'Penser à la multiplication',
    ExerciseType.power => 'Depuis la dizaine la plus proche',
    ExerciseType.squareRoot => 'Dernier chiffre, puis encadrer',
    ExerciseType.percentage => 'Construire le pourcentage',
    ExerciseType.integral => 'Primitive',
  };

  @override
  String accountFailure(
    AccountFailure failure, {
    String? detail,
  }) => switch (failure) {
    AccountFailure.invalidCredentials => 'E-mail ou mot de passe incorrect.',
    AccountFailure.emailNotConfirmed =>
      'E-mail pas encore confirmé — ouvre le lien reçu, puis réessaie.',
    AccountFailure.emailAlreadyUsed => 'Un compte existe déjà avec cet e-mail.',
    AccountFailure.weakPassword =>
      'Mot de passe trop faible — choisis-en un plus long.',
    AccountFailure.invalidInput => 'Adresse e-mail invalide.',
    AccountFailure.rateLimited =>
      'Trop d’essais. Attends quelques minutes avant de réessayer.',
    AccountFailure.network =>
      'Serveur injoignable. Vérifie ta connexion, puis réessaie.',
    AccountFailure.humanCheck =>
      'La vérification anti-robot n’a pas abouti. Réessaie.',
    AccountFailure.unknown => 'Erreur inattendue\u202f: ${detail ?? '-'}',
  };

  @override
  String nameProblem(DisplayNameProblem problem) => switch (problem) {
    DisplayNameProblem.empty => 'Choisis un nom de joueur.',
    DisplayNameProblem.tooLong =>
      'Nom de joueur\u202f: $maxDisplayNameLength caractères au plus.',
    DisplayNameProblem.spaces =>
      'Pas d’espace au début ni à la fin, et une seule entre les mots.',
    DisplayNameProblem.charset =>
      'Utilise des lettres (latines, grecques ou cyrilliques), des chiffres, '
          "des espaces et . _ ' - seulement.",
    DisplayNameProblem.noLetter => 'Mets au moins une lettre ou un chiffre.',
    DisplayNameProblem.blocked => 'Choisis un autre nom.',
  };

  @override
  String uploadRefusal(RejectionReason? known) => switch (known) {
    RejectionReason.levelsMismatch =>
      'Pas classée\u202f: elle partait de niveaux que le serveur n’avait pas (un '
          'autre appareil, ou une ancienne version de l’app). Tes prochaines '
          'parties utilisent les niveaux du serveur.',
    RejectionReason.placementAfterGames =>
      'Pas classée\u202f: un placement ne compte qu’avant ta première partie.',
    RejectionReason.notReplayable =>
      'Pas classée\u202f: jouée avant que l’app puisse envoyer les parties au '
          'serveur.',
    RejectionReason.outOfOrder =>
      'Pas classée\u202f: elle est arrivée au serveur après une partie plus récente.',
    RejectionReason.typeAlreadyPlayed =>
      'Pas classée\u202f: ces opérations avaient déjà un niveau (d’un autre '
          'appareil), ce placement ne pouvait donc pas les fixer.',
    RejectionReason.rulesRetired =>
      'Pas classée\u202f: jouée avant les nouveaux niveaux.',
    RejectionReason.wrongPlayer ||
    RejectionReason.futureTimestamp ||
    RejectionReason.badAnswerCount ||
    RejectionReason.questionMismatch ||
    RejectionReason.correctnessMismatch ||
    RejectionReason.badElapsed ||
    null => 'Pas classée\u202f: le serveur n’a pas pu vérifier cette partie.',
  };

  @override
  String unfinishedDuelsSent(String? modeName, int count) => modeName != null
      ? 'Ton duel $modeName inachevé a été envoyé\u202f: ce que tu n’avais pas '
            'joué compte comme raté.'
      : '$count duels inachevés ont été envoyés\u202f: ce que tu n’avais pas joué '
            'compte comme raté.';

  @override
  String duelMode(DuelMode mode) => switch (mode) {
    DuelMode.basics => 'Bases',
    DuelMode.advanced => 'Avancé',
    DuelMode.count => 'Le compte est bon',
  };

  @override
  final practiceOpponent = 'Entraînement';

  @override
  final unnamedPlayer = 'Joueur';

  @override
  String result(double score) => score == 1
      ? 'Gagné'
      : score == 0
      ? 'Perdu'
      : 'Égalité';
}
