import 'package:math_core/leaderboard/leaderboard.dart';

import '../ranks_strings.dart';

/// [RanksStrings] en français (Phase 6d).
class FrenchRanksStrings implements RanksStrings {
  const FrenchRanksStrings();

  @override
  final title = 'Classements';

  @override
  final notAvailable = 'Les classements ne sont pas encore disponibles.';

  @override
  final aroundMe = 'Autour de moi';

  @override
  final top100 = 'Top 100';

  @override
  final couldNotLoad = 'Impossible de charger les classements.';

  @override
  final emptyBoard = 'Personne dans ce classement pour l’instant.';

  @override
  final mainBoard = 'Général';

  @override
  String topPercent(int percent) => 'Top $percent\u202f%';

  @override
  String rankOf(int rank, int total, String standing) =>
      'Rang $rank sur $total · $standing';

  @override
  String levelStanding(int whole) => 'niveau $whole';

  @override
  String ratingStanding(String rating) => 'cote $rating';

  @override
  String you(String name) => '$name (toi)';

  @override
  final reportName = 'Signaler le nom';

  @override
  String reportTitle(String name) => 'Signaler «\u202f$name\u202f»\u202f?';

  @override
  final reportDetail =
      'Signale un nom injurieux ou qui se fait passer pour quelqu’un. Un nom '
      'signalé est masqué jusqu’à son examen.';

  @override
  final report = 'Signaler';

  @override
  final reported = 'Signalé — merci.';

  @override
  final reportFailed = 'Impossible d’envoyer le signalement.';

  @override
  final reportNeedsAccount = 'Sauvegarde ta progression pour signaler un nom.';

  @override
  final progressSaved = 'Progression sauvegardée sur ton compte.';

  @override
  final saveYourProgress = 'Sauvegarde ta progression';

  @override
  String notRanked(
    NotRankedReason reason, {
    required int needed,
    required bool mainBoard,
    required bool duelBoard,
    required String boardName,
  }) {
    final games = needed == 1 ? 'encore 1 partie' : 'encore $needed parties';
    return switch (reason) {
      NotRankedReason.noSessions =>
        'Joue une partie pour entrer dans les classements. Tes parties comptent '
            'une fois arrivées au serveur.',
      NotRankedReason.notEnoughSessions =>
        mainBoard
            ? 'Termine $games pour entrer dans le classement général.'
            : 'E${games.substring(1)} en ${boardName.toLowerCase()} pour '
                  'entrer dans ce classement.',
      NotRankedReason.inactive when duelBoard =>
        'Joue un duel classé pour réapparaître\u202f: le classement montre les '
            'joueurs actifs ces 30 derniers jours.',
      NotRankedReason.inactive =>
        'Joue une partie pour réapparaître\u202f: le classement montre les joueurs '
            'actifs ces 30 derniers jours. Ton niveau ne baisse jamais pendant '
            'ton absence.',
      NotRankedReason.noDuels =>
        'Joue un duel dans ce mode pour entrer dans son classement.',
      NotRankedReason.provisional =>
        needed == 1
            ? 'Encore 1 duel classé pour entrer dans ce classement.'
            : 'Encore $needed duels classés pour entrer dans ce classement.',
      NotRankedReason.notLinked =>
        'Les classements montrent les joueurs qui ont sauvegardé leur '
            'progression. Sauvegarde la tienne — un e-mail et un nom de joueur — '
            'pour prendre ta place.',
      NotRankedReason.signedOut ||
      NotRankedReason.other => 'Tu n’es pas encore dans ce classement.',
    };
  }
}
