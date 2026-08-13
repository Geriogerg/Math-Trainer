import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/domain/account/account.dart';
import '../../core/domain/account/account_repository.dart';

class SupabaseAccountRepository implements AccountRepository {
  SupabaseAccountRepository(this._client);

  final SupabaseClient _client;

  Account? _toAccount(User? user) {
    final email = user?.email;
    if (user == null || email == null) return null;
    return Account(id: user.id, email: email);
  }

  @override
  Stream<Account?> get authState => _client.auth.onAuthStateChange.map(
    (state) => _toAccount(state.session?.user),
  );

  @override
  Future<Account?> signUp({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
      );
      // `session == null` : confirmation par email requise, pas encore de
      // connexion active — distinct d'un échec (voir account_repository.dart).
      if (response.session == null) return null;
      return _toAccount(response.user);
    } on AuthException catch (e) {
      throw Exception(e.message);
    }
  }

  @override
  Future<Account> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final account = _toAccount(response.user);
      if (account == null) throw Exception('Connexion impossible.');
      return account;
    } on AuthException catch (e) {
      throw Exception(e.message);
    }
  }

  @override
  Future<void> signOut() => _client.auth.signOut();
}
