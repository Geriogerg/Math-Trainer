class PlayerProfile {
  const PlayerProfile({
    required this.accountId,
    this.displayName,
    this.underReview = false,
  });

  final String accountId;

  /// The owner hid or suspended the account (plan v3.9, Phase 6a): the
  /// player is off the boards, and Profile says "Account under review".
  final bool underReview;

  /// `null`: never chosen. The caller shows a prompt to choose one rather
  /// than an empty name.
  final String? displayName;

  @override
  bool operator ==(Object other) =>
      other is PlayerProfile &&
      other.accountId == accountId &&
      other.displayName == displayName &&
      other.underReview == underReview;

  @override
  int get hashCode => Object.hash(accountId, displayName, underReview);

  @override
  String toString() =>
      'PlayerProfile(accountId: $accountId, displayName: $displayName, '
      'underReview: $underReview)';
}
