import '../common_strings.dart';

/// [CommonStrings] en français (Phase 6d): « tu », court et direct, comme
/// l'anglais. Une espace fine insécable (U+202F) avant « ? », « ! », « : »,
/// « ; » et « % ».
class FrenchCommonStrings implements CommonStrings {
  const FrenchCommonStrings();

  @override
  final back = 'Retour';

  @override
  final start = 'Commencer';

  @override
  final cancel = 'Annuler';

  @override
  final ok = 'OK';

  @override
  final close = 'Fermer';

  @override
  final retry = 'Réessayer';

  @override
  final reload = 'Recharger';

  @override
  final signIn = 'Se connecter';

  @override
  final gotIt = 'Compris';

  @override
  final quit = 'Quitter';

  @override
  final player = 'Joueur';

  @override
  final unreachable = 'Impossible de joindre le serveur.';

  @override
  final tryAgain = 'Impossible de joindre le serveur — réessaie.';
}
