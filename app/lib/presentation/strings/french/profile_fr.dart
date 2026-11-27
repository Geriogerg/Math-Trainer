import 'package:math_core/challenges/challenge_stats.dart';

import '../profile_strings.dart';

/// [ProfileStrings] en français (Phase 6d).
class FrenchProfileStrings implements ProfileStrings {
  const FrenchProfileStrings();

  @override
  final title = 'Profil';

  @override
  final couldNotLoad = 'Impossible de charger le profil.';

  @override
  final underReview = 'Compte en cours d’examen';

  @override
  final underReviewDetail =
      'Tes résultats n’apparaissent pas dans les classements tant que l’examen '
      'n’est pas fini.';

  @override
  final mainLevel = 'Niveau général';

  @override
  String change30Days(String? delta) =>
      delta == null ? 'Sur 30 jours\u202f: —' : 'Sur 30 jours\u202f: $delta';

  @override
  final last30Days = '30 derniers jours';

  @override
  final notEnoughData = 'Pas assez de données sur les 30 derniers jours.';

  @override
  final byOperation = 'Par opération';

  @override
  final recentGames = 'Parties récentes';

  @override
  final otherDevices =
      'Les parties jouées sur d’autres appareils ne sont pas affichées ici.';

  @override
  String notSentYet(int games) => games == 1
      ? '1 partie pas encore envoyée\u202f: elle part quand le serveur répond.'
      : '$games parties pas encore envoyées\u202f: elles partent quand le serveur '
            'répond.';

  @override
  final noGameYet = 'Aucune partie jouée pour l’instant.';

  @override
  final placement = 'Placement';

  @override
  String score(int points) => 'Score $points';

  @override
  final notPlayed = 'Pas joué';

  @override
  final playerName = 'Nom de joueur';

  @override
  final playerNameUnavailable = 'Nom de joueur indisponible';

  @override
  final choosePlayerName = 'Choisis un nom de joueur';

  @override
  final reloadPlayerName = 'Recharger le nom de joueur';

  @override
  final editPlayerName = 'Modifier le nom de joueur';

  @override
  final guestLine = 'Invité — progression gardée sur cet appareil seulement';

  @override
  final saveYourProgress = 'Sauvegarde ta progression';

  @override
  final haveAccount = 'J’ai déjà un compte';

  @override
  final signOut = 'Se déconnecter';

  @override
  final save = 'Enregistrer';

  @override
  final nameNotAllowed = 'Ce nom n’est pas autorisé.';

  @override
  final nameTaken = 'Ce nom est pris — essaie-en un autre.';

  @override
  final nameNotSaved = 'Nom non enregistré — vérifie ta connexion et réessaie.';

  @override
  final progressSaved = 'Progression sauvegardée sur ton compte.';

  @override
  final progressSavedNameNot =
      'Progression sauvegardée — mais pas le nom de joueur\u202f; remets-le ici.';

  @override
  final confirmEmail =
      'Presque fini — ouvre le lien envoyé à ton e-mail pour confirmer.';

  @override
  final signOutTitle = 'Se déconnecter\u202f?';

  @override
  final signOutLines = const [
    'Tes parties et tes niveaux restent sur ton compte\u202f: reconnecte-toi pour '
        'les retrouver.',
    'Cet appareil repart comme un nouvel invité.',
  ];

  @override
  String deleteTitle({required bool guest}) =>
      guest ? 'Supprimer tes données\u202f?' : 'Supprimer ton compte\u202f?';

  @override
  String deleteDetail({required bool guest}) => guest
      ? 'Tes niveaux, ton historique et ton compte invité sont supprimés de cet '
            'appareil et du serveur. Tu repars comme un nouveau joueur. C’est '
            'définitif.'
      : 'Ton compte, tes niveaux, ton historique et ton nom de joueur sont '
            'supprimés de cet appareil et du serveur. C’est définitif.';

  @override
  final delete = 'Supprimer';

  @override
  String deleted({required bool guest}) =>
      guest ? 'Tes données ont été supprimées.' : 'Ton compte a été supprimé.';

  @override
  final deletedLocalKept =
      'Supprimé du serveur\u202f; certaines données n’ont pas pu être retirées de '
      'cet appareil.';

  @override
  String nothingDeleted(String reason) => 'Rien n’a été supprimé. $reason';

  @override
  String deleteButton({required bool guest}) =>
      guest ? 'Supprimer mes données' : 'Supprimer mon compte';

  @override
  final sendFeedback = 'Envoyer un avis';

  @override
  final privacyPolicy = 'Confidentialité';

  @override
  final legalNotice = 'Mentions légales';

  @override
  final challenges = 'Défis';

  @override
  String challenge(Challenge challenge) => switch (challenge) {
    Challenge.getTheCount => 'Le compte est bon',
    Challenge.chainOperations => 'Calcul en chaîne',
  };

  @override
  final games = 'Parties';

  @override
  final solved = 'Trouvés';

  @override
  final best = 'Record';

  @override
  final tables = 'Tables';

  @override
  final right = 'Justes';

  @override
  final slowest = 'Les plus lents';

  @override
  final weakSpots = 'Points faibles';

  @override
  final noneYet = 'Aucun pour l’instant';

  @override
  String missedOf(int misses, int answers) => '$misses ratés sur $answers';

  @override
  final practice = 'S’exercer';

  @override
  final settings = 'Réglages';

  @override
  final language = 'Langue';

  @override
  final darkMode = 'Mode sombre';

  @override
  final sound = 'Son';

  @override
  final vibration = 'Vibration';

  @override
  final feedbackTitle = 'Envoyer un avis';

  @override
  final feedbackSent = 'Merci — c’est envoyé.';

  @override
  final yourMessage = 'Ton message';

  @override
  final send = 'Envoyer';

  @override
  final sending = 'Envoi…';

  @override
  final feedbackOffline = 'Pas envoyé\u202f: pas de connexion. Réessaie.';

  @override
  final feedbackTooMany =
      'Pas envoyé\u202f: ça fait beaucoup de messages pour une journée. Réessaie '
      'demain.';

  @override
  final feedbackEmpty = 'Écris d’abord quelque chose.';

  @override
  String feedbackTooLong(int max) =>
      'Trop long\u202f: $max caractères au plus.';
}
