/// Raison d'un échec de connexion/inscription, indépendante du backend :
/// l'infrastructure traduit ses propres codes d'erreur vers ces cas, la
/// présentation choisit le message affiché (en français) — jamais le texte
/// brut du serveur, en anglais et pensé pour un développeur.
enum AccountFailure {
  /// Email inconnu ou mot de passe faux — volontairement indistincts côté
  /// serveur (ne pas révéler quels emails ont un compte).
  invalidCredentials,

  /// Compte créé, mais email jamais confirmé.
  emailNotConfirmed,

  emailAlreadyUsed,

  /// Mot de passe refusé par la politique du projet (trop court, trop simple).
  weakPassword,

  /// Email mal formé ou champ requis absent.
  invalidInput,

  /// Trop de tentatives (ou d'emails envoyés) en peu de temps.
  rateLimited,

  /// Serveur injoignable : pas de réseau, ou serveur en erreur (5xx).
  network,

  /// Tout le reste — [AccountException.detail] porte alors le message brut,
  /// seul indice disponible pour diagnostiquer.
  unknown,
}

class AccountException implements Exception {
  const AccountException(this.failure, {this.detail});

  final AccountFailure failure;

  /// Message technique d'origine, pour le diagnostic — pas pour l'affichage
  /// courant.
  final String? detail;

  @override
  String toString() => detail == null
      ? 'AccountException(${failure.name})'
      : 'AccountException(${failure.name}: $detail)';
}
