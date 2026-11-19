class Account {
  const Account({required this.id, this.email, this.isAnonymous = false});

  /// Supabase Auth user id — also the `playerId` under which levels and
  /// history are stored (`environmentForAccount`, `doc/online.md`). Linking
  /// an email to an anonymous account keeps this id, hence the history.
  final String id;

  /// `null` for an anonymous player (created silently on first launch, plan
  /// section 6.3) until they link an email.
  final String? email;

  /// An anonymous player has no way back into this account once its local
  /// session is gone: they must never be offered a sign-out.
  final bool isAnonymous;

  @override
  bool operator ==(Object other) =>
      other is Account &&
      other.id == id &&
      other.email == email &&
      other.isAnonymous == isAnonymous;

  @override
  int get hashCode => Object.hash(id, email, isAnonymous);

  @override
  String toString() =>
      'Account(id: $id, email: $email, isAnonymous: $isAnonymous)';
}
