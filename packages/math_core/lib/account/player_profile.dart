class PlayerProfile {
  const PlayerProfile({required this.accountId, this.displayName});

  final String accountId;

  /// `null`: never chosen. The caller shows a prompt to choose one rather
  /// than an empty name.
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
