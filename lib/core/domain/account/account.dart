class Account {
  const Account({required this.id, required this.email});

  /// Identifiant utilisateur côté Supabase Auth — c'est aussi le `playerId`
  /// sous lequel niveaux et historique sont enregistrés une fois connecté
  /// (`environmentForAccount`, `doc/online.md`).
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
