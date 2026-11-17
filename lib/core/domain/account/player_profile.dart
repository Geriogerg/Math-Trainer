class PlayerProfile {
  const PlayerProfile({required this.accountId, this.displayName});

  final String accountId;

  /// `null` : jamais choisi. L'appelant affiche une invite à en choisir un
  /// plutôt qu'un nom vide.
  final String? displayName;

  @override
  bool operator ==(Object other) =>
      other is PlayerProfile &&
      other.accountId == accountId &&
      other.displayName == displayName;

  @override
  int get hashCode => Object.hash(accountId, displayName);

  @override
  String toString() =>
      'PlayerProfile(accountId: $accountId, displayName: $displayName)';
}
