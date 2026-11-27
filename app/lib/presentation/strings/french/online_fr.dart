import 'package:math_core/duel/duel_mode.dart';
import 'package:math_core/friends/friends.dart';

import '../online_strings.dart';
import 'labels_fr.dart';

/// [OnlineStrings] en français (Phase 6d).
class FrenchOnlineStrings implements OnlineStrings {
  const FrenchOnlineStrings();

  /// Les modes comme l'onglet En ligne les nomme.
  static String _mode(DuelMode mode) =>
      const FrenchLabelStrings().duelMode(mode);

  @override
  final tabPlay = 'Jouer';

  @override
  final tabOnline = 'En ligne';

  @override
  final tabProfile = 'Profil';

  @override
  final tabRanks = 'Classements';

  @override
  final onlineAttention = 'En ligne, quelque chose t’attend';

  @override
  final online = 'En ligne';

  @override
  final notAvailable = 'Le jeu en ligne n’est pas encore disponible.';

  @override
  final duels = 'Duels';

  @override
  final waitingForYou = 'Ils t’attendent';

  @override
  final play = 'Jouer';

  @override
  final recent = 'Récents';

  @override
  String challengeFrom(String name, String mode) => '$name · $mode';

  @override
  String practiceDuel(String mode) => 'Entraînement · $mode';

  @override
  String racedYourRun(String name) => '$name a affronté ta course';

  @override
  String duelWith(String name, String mode) => '$name · $mode';

  @override
  final notCountedLower = 'non compté';

  @override
  final waitingLower = 'en attente';

  @override
  final needsAccount =
      'Les duels demandent un compte sauvegardé\u202f: sauvegarde ta progression '
      '— un e-mail et un nom de joueur — pour affronter les autres.';

  @override
  final saveYourProgress = 'Sauvegarde ta progression';

  @override
  final couldNotLoad = 'Impossible de charger tes duels.';

  @override
  String modeRule(DuelMode mode) => switch (mode) {
    DuelMode.basics => '8 questions, 2 de chaque\u202f: + − × ÷.',
    DuelMode.advanced => '8 questions, 2 de chaque\u202f: x², √, % et ∫.',
    DuelMode.count =>
      '3 manches de 30 s\u202f: approche-toi au plus de la cible.',
  };

  @override
  String rulesTitle(String mode) => 'Duel · $mode';

  @override
  List<String> rules(DuelMode mode) => [
    switch (mode) {
      DuelMode.basics =>
        '8 questions, 2 de chaque\u202f: + − × ÷, 30 s chacune. Le plus de bonnes '
            'réponses gagne\u202f; à égalité, le plus rapide.',
      DuelMode.advanced =>
        '8 questions, 2 de chaque\u202f: x², √, % et ∫, 30 s chacune. Le plus de '
            'bonnes réponses gagne\u202f; à égalité, le plus rapide.',
      DuelMode.count =>
        '3 manches de 30 s, les mêmes nombres pour les deux. Le plus proche des '
            'cibles gagne\u202f; à égalité, le plus rapide.',
    },
    rated,
    leaving,
  ];

  @override
  final rated =
      'Classé\u202f: les deux cotes bougent — sauf si personne n’est trouvé et '
      'que tu affrontes un adversaire d’entraînement.';

  @override
  final leaving = 'Partir compte comme une défaite.';

  @override
  final ratedReminder = 'Classé · partir compte comme une défaite';

  @override
  final rulesLink = 'Règles';

  @override
  final rulesLinkSpoken = 'Règles des duels';

  @override
  final allRulesTitle = 'Règles des duels';

  @override
  List<String> get allRules => [
    for (final mode in DuelMode.values)
      '${_mode(mode)}\u202f: ${modeRule(mode)}',
    '30 s par question. Le plus de bonnes réponses gagne\u202f; à égalité, le '
        'plus rapide. Le compte est bon\u202f: le plus proche des cibles gagne.',
    rated,
    leaving,
  ];

  @override
  final saveToPlay = 'Sauvegarde ta progression pour jouer en ligne.';

  @override
  final challengeExists = 'Un défi est déjà ouvert.';

  @override
  final cannotBeChallenged = 'Ce joueur ne peut pas être défié.';

  @override
  final duelNotAvailable = 'Ce duel n’est pas disponible.';

  @override
  final appOutdated =
      'Une nouvelle version du jeu est sortie. Recharge la page pour jouer en '
      'duel — rien n’a été lancé.';

  @override
  final quitDuelTitle = 'Quitter le duel\u202f?';

  @override
  final stillCounts = 'Il compte quand même.';

  @override
  final wakingServer = 'Réveil du serveur…';

  @override
  final findingOpponent = 'Recherche d’un adversaire…';

  @override
  final wakeCaption = 'Ça peut prendre jusqu’à une minute.';

  @override
  final you = 'Toi';

  @override
  final notCounted = 'Non compté';

  @override
  final sent = 'Envoyé';

  @override
  final sendAgain = 'Renvoyer';

  @override
  final rematch = 'Revanche';

  @override
  String practiceSubtitle(String mode) => '$mode · Entraînement';

  @override
  final friends = 'Amis';

  @override
  String friendsPill(int requests) => requests == 0
      ? 'Amis'
      : 'Amis, $requests demande${requests == 1 ? '' : 's'}';

  @override
  String requestOutcome(FriendRequestOutcome outcome) => switch (outcome) {
    FriendRequestOutcome.sent => 'Demande envoyée.',
    FriendRequestOutcome.friends => 'Vous êtes maintenant amis.',
    FriendRequestOutcome.already => 'Déjà amis.',
    FriendRequestOutcome.pending => 'Demande déjà envoyée.',
    FriendRequestOutcome.unknown => 'Aucun joueur n’a ce code.',
    FriendRequestOutcome.self => 'C’est ton propre code.',
    FriendRequestOutcome.tooMany => 'Trop de demandes aujourd’hui.',
    FriendRequestOutcome.other => 'Impossible d’envoyer la demande.',
  };

  @override
  final linkCopied = 'Lien copié';

  @override
  final newCodeTitle = 'Obtenir un nouveau code\u202f?';

  @override
  final newCodeDetail =
      'Ton code actuel et les liens partagés ne marchent plus. Tes amis restent.';

  @override
  final newCode = 'Nouveau code';

  @override
  final newCodeFailed = 'Impossible d’obtenir un nouveau code — réessaie.';

  @override
  final shareLink = 'Partager le lien';

  @override
  final addCode = 'Ajouter un code';

  @override
  final add = 'Ajouter';

  @override
  final yourCode = 'Ton code';

  @override
  final requests = 'Demandes';

  @override
  final decline = 'Refuser';

  @override
  final accept = 'Accepter';

  @override
  final noFriendsYet = 'Partage ton lien ou ajoute le code d’un ami.';

  @override
  String headToHead(String name, int wins, int losses) =>
      '$name, $wins victoire${wins > 1 ? 's' : ''}, $losses défaite${losses > 1 ? 's' : ''}';

  @override
  final challenge = 'Défier';

  @override
  final thisPlayer = 'ce joueur';

  @override
  String removeTitle(String name) => 'Retirer $name\u202f?';

  @override
  final remove = 'Retirer';

  @override
  final removeFriend = 'Retirer cet ami';

  @override
  final noDuelYet = 'Aucun duel pour l’instant.';

  @override
  String drawn(int draws) => ' · $draws nul${draws > 1 ? 's' : ''}';

  @override
  final inviteTitle = 'Envoyer une demande d’ami\u202f?';

  @override
  String inviteDetail(String code) =>
      'Un lien d’invitation propose d’ajouter le joueur au code $code.';

  @override
  final notNow = 'Pas maintenant';

  @override
  final sendRequest = 'Envoyer la demande';
}
