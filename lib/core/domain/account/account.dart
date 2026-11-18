class Account {
  const Account({required this.id, required this.email});

  /// Supabase Auth user id — also the `playerId` under which levels and
  /// history are stored once signed in (`environmentForAccount`,
  /// `doc/online.md`).
  final String id;

  final String email;

  @override
  bool operator ==(Object other) =>
      other is Account && other.id == id && other.email == email;

  @override
  int get hashCode => Object.hash(id, email);

  @override
  String toString() => 'Account(id: $id, email: $email)';
}
