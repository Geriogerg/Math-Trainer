import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/domain/account/account.dart';
import '../../core/domain/account/account_repository.dart';

/// Codes `error_code` de Supabase Auth (chaînes, pas l'enum `ErrorCode` de
/// gotrue : `invalid_credentials` et `email_address_invalid` n'y figurent
/// pas dans la version utilisée, le serveur les renvoie pourtant).
AccountException _toAccountException(AuthException error) {
  // Levée par gotrue quand la requête n'aboutit pas (pas de réseau, CORS)
  // ou que le serveur répond 5xx — dans les deux cas, rien à corriger côté
  // joueur, seulement réessayer plus tard.
  if (error is AuthRetryableFetchException) {
    return AccountException(AccountFailure.network, detail: error.message);
  }
  final failure = switch (error.code) {
    'invalid_credentials' => AccountFailure.invalidCredentials,
    'email_not_confirmed' => AccountFailure.emailNotConfirmed,
    'user_already_exists' || 'email_exists' => AccountFailure.emailAlreadyUsed,
    'weak_password' => AccountFailure.weakPassword,
    'email_address_invalid' ||
    'validation_failed' => AccountFailure.invalidInput,
    'over_request_rate_limit' ||
    'over_email_send_rate_limit' => AccountFailure.rateLimited,
    _ => AccountFailure.unknown,
  };
  return AccountException(failure, detail: error.message);
}

class SupabaseAccountRepository implements AccountRepository {
  SupabaseAccountRepository(this._client);

  final SupabaseClient _client;

  Account? _toAccount(User? user) {
    final email = user?.email;
    if (user == null || email == null) return null;
    return Account(id: user.id, email: email);
  }

  /// Malgré son nom, le `ReplaySubject` de `supabase_common` derrière
  /// `onAuthStateChange` ne rejoue que le **dernier** événement à un nouvel
  /// abonné, pas tout l'historique — c'est ce qui garantit le contrat
  /// « état courant d'abord » d'`AccountRepository.authState`. Comportement
  /// de bibliothèque verrouillé par `supabase_account_repository_test.dart`.
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
      throw _toAccountException(e);
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
      if (account == null) {
        throw const AccountException(
          AccountFailure.unknown,
          detail: 'session sans utilisateur ou sans email',
        );
      }
      return account;
    } on AuthException catch (e) {
      throw _toAccountException(e);
    }
  }

  @override
  Future<void> signOut() => _client.auth.signOut();
}
