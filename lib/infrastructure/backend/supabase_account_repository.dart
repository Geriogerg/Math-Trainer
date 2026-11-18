import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/domain/account/account.dart';
import '../../core/domain/account/account_repository.dart';

/// Supabase Auth `error_code` values (strings, not gotrue's `ErrorCode`
/// enum: `invalid_credentials` and `email_address_invalid` are missing from
/// it in the version used, yet the server returns them).
AccountException _toAccountException(AuthException error) {
  // Thrown by gotrue when the request does not go through (no network,
  // CORS) or the server answers 5xx — in both cases nothing to fix on the
  // player's side, only retry later.
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

  /// Despite its name, the `ReplaySubject` from `supabase_common` behind
  /// `onAuthStateChange` replays only the **latest** event to a new
  /// subscriber, not the whole history — which is what guarantees the
  /// "current state first" contract of `AccountRepository.authState`.
  /// Library behaviour locked by `supabase_account_repository_test.dart`.
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
      // `session == null`: email confirmation required, no active session
      // yet — not a failure (see account_repository.dart).
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
          detail: 'session without a user or an email',
        );
      }
      return account;
    } on AuthException catch (e) {
      throw _toAccountException(e);
    }
  }

  /// gotrue clears the local session and emits `signedOut` *before*
  /// notifying the server: offline, the player is indeed signed out, only
  /// the server-side revocation fails (the token will expire on its own).
  /// Letting that error propagate left it unhandled from the "Sign out"
  /// button, for a sign-out that had actually happened.
  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on AuthException catch (_) {
      // Local sign-out already done, see above.
    }
  }
}
