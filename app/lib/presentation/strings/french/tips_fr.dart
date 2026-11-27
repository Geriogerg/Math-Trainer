import '../tip_strings.dart';
import '../tips.dart' show TipId;

/// [TipStrings] en français (Phase 6d) : une phrase, un exemple, au « tu ».
/// Les exemples sont de l'arithmétique ; seuls leurs mots et leurs
/// décimales changent (« 37,5 % de 64 », « de 0 à 4 »).
class FrenchTipStrings implements TipStrings {
  const FrenchTipStrings();

  @override
  String text(TipId id) => switch (id) {
    TipId.makeTen => 'Fais 10 d’abord, puis ajoute le reste.',
    TipId.nearDoubles =>
      'Doubles et presque-doubles\u202f: double l’un, puis ajuste.',
    TipId.pairsTo100 => 'Repère les paires qui font 100 ou 1\u202f000.',
    TipId.tensThenUnits => 'Ajoute les dizaines, puis les unités.',
    TipId.roundUpGiveBack =>
      'Arrondis un nombre au-dessus, ajoute, puis retire ce que tu as mis en trop.',
    TipId.roundHundreds =>
      'Grands nombres ronds\u202f: compte en centaines ou en milliers.',
    TipId.threeNumbers =>
      'Trois nombres\u202f: ajoute d’abord la paire qui fait 100.',
    TipId.fromTheLeft => 'Ajoute en partant de la gauche, en gardant un total.',
    TipId.countUp => 'Compte du plus petit nombre jusqu’au plus grand.',
    TipId.subtractRound => 'Retire un nombre rond, puis rends la différence.',
    TipId.acrossRound =>
      'Nombres proches autour d’un rond\u202f: compte en le traversant.',
    TipId.sameGap =>
      'Décale les deux nombres d’autant\u202f: l’écart ne change pas.',
    TipId.acrossZeros =>
      'Avec des zéros, une seule retenue\u202f: retire de 999, puis ajoute 1.',
    TipId.times9 => 'Pense aux motifs\u202f: × 9, c’est × 10, moins une fois.',
    TipId.times5 => '× 5, c’est × 10, divisé par 2.',
    TipId.splitFactor =>
      'Coupe le plus grand facteur, multiplie chaque partie, additionne.',
    TipId.times11 =>
      '× 11\u202f: les deux chiffres écartés, leur somme au milieu.',
    TipId.times25 => '× 25, c’est × 100, divisé par 4.',
    TipId.halveDouble =>
      'Divise un facteur par 2 et double l’autre, jusqu’à ce que ce soit facile.',
    TipId.nearRound =>
      'Près d’un nombre rond\u202f: multiplie par lui, puis corrige.',
    TipId.aroundRound =>
      'Deux nombres autour d’un rond\u202f: son carré moins le carré de l’écart.',
    TipId.sameTensUnits10 =>
      'Mêmes dizaines, unités qui font 10\u202f: dizaine × dizaine suivante, puis '
          'unités × unités.',
    TipId.times101 => '× 101\u202f: cent fois, plus une fois.',
    TipId.powersOf2Product =>
      'Les puissances de 2 se multiplient en ajoutant leurs exposants.',
    TipId.bothNear100 =>
      'Tous deux près de 100\u202f: l’un moins l’écart de l’autre, en centaines, '
          'plus le produit des écarts.',
    TipId.thinkMultiplication => 'Pense à la multiplication qu’elle défait.',
    TipId.halvingTwice =>
      '÷ 4, c’est diviser par 2 deux fois\u202f; ÷ 8, trois fois.',
    TipId.divideBy5 => '÷ 5, c’est doubler, puis ÷ 10.',
    TipId.splitDividend =>
      'Coupe le nombre en parts faciles, divise chacune, additionne.',
    TipId.dropZeros => 'Enlève les mêmes zéros aux deux nombres.',
    TipId.divideBy25 => '÷ 25, c’est × 4, puis ÷ 100.',
    TipId.doublePowersOf2 => 'Puissances de 2\u202f: double, encore et encore.',
    TipId.squareEndingIn5 =>
      'Un carré qui finit par 5\u202f: les dizaines fois la suivante, puis 25.',
    TipId.splitExponent =>
      'Coupe l’exposant\u202f: une puissance est un produit de plus petites.',
    TipId.binomialSquare => '(a + b)² = a² + 2ab + b².',
    TipId.nearFifty =>
      'Près de 50\u202f: 2500, plus ou moins 100 par pas, plus le pas au carré.',
    TipId.repunits => '11, 111\u202f: décale et additionne.',
    TipId.betweenSquares => 'Place-la entre deux carrés que tu connais.',
    TipId.halveExponent =>
      'Une puissance de 2 sous la racine\u202f: divise son exposant par 2.',
    TipId.lastDigit =>
      'Le dernier chiffre aide\u202f: un carré qui finit par 6 a une racine qui '
          'finit par 4 ou 6.',
    TipId.endingIn25 =>
      'Finit par 25\u202f: la racine finit par 5\u202f; le reste est un produit de '
          'voisins.',
    TipId.cubeRootLastDigit =>
      'Une racine cubique par son dernier chiffre\u202f: un cube qui finit par 7 a '
          'une racine qui finit par 3.',
    TipId.nearHundredRoot =>
      'Juste au-dessus ou au-dessous de 100 ou 1\u202f000\u202f: mets au carré le '
          'voisin que tu soupçonnes.',
    TipId.tenPercent => '10\u202f% décale la virgule d’un rang vers la gauche.',
    TipId.halfQuarter =>
      '50\u202f%, c’est la moitié\u202f; 25\u202f%, la moitié de la moitié.',
    TipId.buildPercentage =>
      'Construis n’importe quel pourcentage avec 10\u202f%, 5\u202f% et 1\u202f%.',
    TipId.swapPercentage =>
      'Inverse quand c’est plus simple\u202f: a\u202f% de b, c’est b\u202f% de a.',
    TipId.eighth =>
      '12,5\u202f%, c’est un huitième\u202f: divise par 8, puis multiplie.',
    TipId.nearHundredPercent =>
      'Près de 100\u202f%\u202f: le tout, plus ou moins un peu.',
    TipId.rectangle =>
      'Une constante, c’est un rectangle\u202f: hauteur fois largeur.',
    TipId.triangle => '2x de 0 à b, c’est un triangle d’aire b².',
    TipId.antiderivative => 'Prends la primitive en haut, moins en bas.',
    TipId.differenceOfSquares =>
      '2x de a à b, c’est b² − a²\u202f: une différence de carrés.',
    TipId.powerRule =>
      'La règle des puissances\u202f: xⁿ devient xⁿ⁺¹ ÷ (n + 1).',
  };

  @override
  String example(TipId id) => switch (id) {
    TipId.makeTen => '8 + 7 = 8 + 2 + 5 = 15',
    TipId.nearDoubles => '48 + 49 = 2 × 48 + 1 = 97',
    TipId.pairsTo100 => '37 + 63 = 90 + 10 = 100',
    TipId.tensThenUnits => '47 + 38 = 77 + 8 = 85',
    TipId.roundUpGiveBack => '47 + 68 = 47 + 70 − 2 = 115',
    TipId.roundHundreds =>
      '3\u202f500 + 4\u202f500 = 35 + 45 centaines = 8\u202f000',
    TipId.threeNumbers => '27 + 46 + 73 = 100 + 46 = 146',
    TipId.fromTheLeft => '2468 + 785\u202f: 3168, 3248, 3253',
    TipId.countUp =>
      '15 − 7\u202f: de 7 à 10, 3\u202f; de 10 à 15, 5\u202f; donc 8',
    TipId.subtractRound => '603 − 298 = 603 − 300 + 2 = 305',
    TipId.acrossRound => '5\u202f003 − 4\u202f997 = 3 + 3 = 6',
    TipId.sameGap => '803 − 497 = 806 − 500 = 306',
    TipId.acrossZeros => '1000 − 357 = 999 − 357 + 1 = 643',
    TipId.times9 => '9 × 7 = 70 − 7 = 63',
    TipId.times5 => '14 × 5 = 140 ÷ 2 = 70',
    TipId.splitFactor => '7 × 46 = 280 + 42 = 322',
    TipId.times11 => '43 × 11 = 4 | 7 | 3 = 473',
    TipId.times25 => '36 × 25 = 3600 ÷ 4 = 900',
    TipId.halveDouble => '16 × 25 = 8 × 50 = 4 × 100 = 400',
    TipId.nearRound => '98 × 7 = 700 − 14 = 686',
    TipId.aroundRound => '47 × 53 = 50² − 3² = 2500 − 9 = 2491',
    TipId.sameTensUnits10 => '43 × 47 = 4 × 5 | 3 × 7 = 2\u202f021',
    TipId.times101 => '47 × 101 = 4\u202f700 + 47 = 4\u202f747',
    TipId.powersOf2Product => '64 × 32 = 2⁶ × 2⁵ = 2¹¹ = 2\u202f048',
    TipId.bothNear100 => '97 × 96 = 9\u202f300 + 3 × 4 = 9\u202f312',
    TipId.thinkMultiplication => '56 ÷ 8 = 7, car 7 × 8 = 56',
    TipId.halvingTwice => '28 ÷ 4\u202f: 14, 7',
    TipId.divideBy5 => '235 ÷ 5 = 470 ÷ 10 = 47',
    TipId.splitDividend => '522 ÷ 6 = 480 ÷ 6 + 42 ÷ 6 = 80 + 7 = 87',
    TipId.dropZeros => '36\u202f000 ÷ 400 = 360 ÷ 4 = 90',
    TipId.divideBy25 => '4500 ÷ 25 = 18000 ÷ 100 = 180',
    TipId.doublePowersOf2 => '2⁶\u202f: 2, 4, 8, 16, 32, 64',
    TipId.squareEndingIn5 => '35² = 3 × 4 | 25 = 1225',
    TipId.splitExponent => '3⁸ = 3⁴ × 3⁴ = 81 × 81 = 6\u202f561',
    TipId.binomialSquare => '23² = 400 + 120 + 9 = 529',
    TipId.nearFifty => '48² = 2500 − 200 + 4 = 2304',
    TipId.repunits => '111² = 11\u202f100 + 1\u202f110 + 111 = 12\u202f321',
    TipId.betweenSquares => '√169\u202f: 12² = 144, 14² = 196, donc 13',
    TipId.halveExponent => '√1024 = √2¹⁰ = 2⁵ = 32',
    TipId.lastDigit => '√2116\u202f: 40² = 1600, 50² = 2500, donc 46',
    TipId.endingIn25 => '√7225\u202f: 72 = 8 × 9, donc 85',
    TipId.cubeRootLastDigit =>
      'Racine cubique de 2197\u202f: 10³ = 1000, 20³ = 8000, donc 13',
    TipId.nearHundredRoot =>
      '√10201\u202f: 101² = 10\u202f000 + 200 + 1, donc 101',
    TipId.tenPercent => '10\u202f% de 350 = 35',
    TipId.halfQuarter => '25\u202f% de 4864 = 2432 ÷ 2 = 1216',
    TipId.buildPercentage => '15\u202f% de 600 = 60 + 30 = 90',
    TipId.swapPercentage => '8\u202f% de 25 = 25\u202f% de 8 = 2',
    TipId.eighth => '37,5\u202f% de 64 = 3 × 8 = 24',
    TipId.nearHundredPercent => '99\u202f% de 300 = 300 − 3 = 297',
    TipId.rectangle => '∫ 3 dx de 0 à 4 = 3 × 4 = 12',
    TipId.triangle => '∫ 2x dx de 0 à 3 = 3² = 9',
    TipId.antiderivative => '∫ 3x² dx de 1 à 3 = 27 − 1 = 26',
    TipId.differenceOfSquares => '∫ 2x dx de 19 à 21 = 2 × 40 = 80',
    TipId.powerRule => '∫ 4x³ dx de 0 à 2 = 2⁴ = 16',
  };
}
