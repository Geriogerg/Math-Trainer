import 'package:math_core/leveling/level_updates.dart';
import 'package:math_core/tiers/tip_band.dart';

import '../game_strings.dart';

/// [GameStrings] en français (Phase 6d). Les décimales prennent la virgule
/// (« 2,4 s », « +0,56 », « 37,5 % ») ; les milliers, l'espace fine, comme en
/// anglais (`groupSeparator`).
class FrenchGameStrings implements GameStrings {
  const FrenchGameStrings();

  @override
  final right = 'Juste';

  @override
  String wrongWithAnswer(String spoken, int answer) =>
      'Faux. $spoken égale $answer.';

  @override
  String timesUpWithAnswer(String spoken, int answer) =>
      'Temps écoulé. $spoken égale $answer.';

  @override
  final timesUp = 'Temps écoulé';

  @override
  String secondsLeft(int seconds) => 'Plus que $seconds secondes';

  @override
  String question(int index, int total, String spoken) =>
      'Question $index sur $total\u202f: $spoken';

  @override
  String yourAnswer(int value) => 'Ta réponse\u202f: $value';

  @override
  final timeLeft = 'Temps restant';

  @override
  String seconds(int n) => n == 1 ? '1 seconde' : '$n secondes';

  @override
  final noQuestion = 'Aucune question à afficher.';

  @override
  final percentOf = 'de';

  @override
  String percent(int whole, int tenths) =>
      '$whole${tenths == 0 ? '' : ',$tenths'}\u202f%';

  @override
  String operationLevel(String operation, int level) =>
      '$operation, niveau $level';

  @override
  final backspace = 'Effacer';

  @override
  final submit = 'Valider';

  @override
  final quitTitle = 'Quitter la partie\u202f?';

  @override
  final quitCounts =
      'Les questions restantes comptent comme ratées\u202f: tes niveaux peuvent '
      'baisser.';

  @override
  final couldNotRestart = 'Impossible de lancer une nouvelle partie.';

  @override
  final notStarted = 'Partie non commencée.';

  @override
  String title({required bool interrupted}) =>
      interrupted ? 'Partie interrompue' : 'Partie terminée';

  @override
  final score = 'Score';

  @override
  String base(int points) => 'Base\u202f: $points';

  @override
  String speedBonus(int points) => 'Bonus de vitesse\u202f: $points';

  @override
  String streakBonus(int points) => 'Bonus de série\u202f: $points';

  @override
  String difficultyBonus(int points) => 'Bonus de difficulté\u202f: $points';

  @override
  final rightCount = 'Justes';

  @override
  final wrongCount = 'Fausses';

  @override
  final timedOut = 'Temps écoulé';

  @override
  final averageTime = 'Temps moyen';

  @override
  String secondsValue(num milliseconds) =>
      '${(milliseconds / 1000).toStringAsFixed(1).replaceAll('.', ',')} s';

  @override
  final bestStreak = 'Meilleure série';

  @override
  final mistakes = 'Erreurs';

  @override
  final notSaved = 'Non enregistrée';

  @override
  final retrySaving = 'Réessayer d’enregistrer';

  @override
  final home = 'Accueil';

  @override
  final playAgain = 'Rejouer';

  @override
  final method = 'Méthode';

  @override
  final hideMethod = 'Masquer la méthode';

  @override
  final moreTips = 'Plus d’astuces';

  @override
  final progressInLevel = 'Progression vers le niveau suivant';

  @override
  final levelUp = '▲ Niveau supérieur';

  @override
  String level(String operation, int whole) => '$operation — niveau $whole';

  @override
  String levelTooFewAnswers(String operation, int whole) =>
      '$operation — niveau $whole (pas assez de réponses pour compter)';

  @override
  String levelChange(String operation, int before, int after, int change) =>
      '$operation\u202f: $before → $after (${levelChangeText(change)})';

  @override
  String levelChangeText(int hundredths) {
    if (hundredths == 0) return 'inchangé';
    final sign = hundredths > 0 ? '+' : '−';
    final a = hundredths.abs();
    return '$sign${a ~/ 100},${(a % 100).toString().padLeft(2, '0')}';
  }

  @override
  String qualityReason(OperationQuality q, {required int change}) {
    final zone = switch (q.zone) {
      QualityZone.up => 'en hausse',
      QualityZone.kept => 'stable',
      QualityZone.down => 'en baisse',
    };
    final bound = change == 0 && q.zone == QualityZone.down
        ? ' (déjà à 0)'
        : change == 0 && q.zone == QualityZone.up
        ? ' (déjà à 100)'
        : '';
    final left = q.unanswered == 0
        ? ''
        : ' · ${q.unanswered} restantes, comptées ratées';
    return '${q.right} justes, ${q.fast} rapides, sur ${q.questions}\u202f: '
        '$zone$bound$left';
  }

  @override
  final undo = 'Annuler';

  @override
  final reset = 'Recommencer';

  @override
  final solved = 'Trouvé';

  @override
  final missed = 'Raté';

  @override
  final time = 'Temps';

  @override
  final closest = 'Le plus proche';

  @override
  String levelBadge(int level) => 'Niveau $level';

  @override
  final notPlayed = 'Pas joué';

  @override
  String tipBand(TipBand band) => switch (band) {
    TipBand.beginner => 'Débutant',
    TipBand.intermediate => 'Intermédiaire',
    TipBand.advanced => 'Avancé',
  };

  @override
  final yourLevel = 'Ton niveau';

  @override
  final drill = 'S’entraîner';

  @override
  String drillLabel(String tip) => 'S’entraîner\u202f: $tip';
}
