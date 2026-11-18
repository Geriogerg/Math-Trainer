import 'account.dart';

// Part of the contract: every caller of `signIn`/`signUp` needs it.
export 'account_exception.dart';

/// Online account — concrete implementation (Supabase) in
/// `infrastructure/backend/`, never in the domain (rule 3).
abstract class AccountRepository {
  /// Signed-in account, `null` if nobody is signed in. Each subscription
  /// first receives the **current** state, then every change (sign-in,
  /// sign-out, session expiry) without polling — so `.first` gives the
  /// account signed in at the time of the call, never an earlier state.
  Stream<Account?> get authState;

  /// `null`: account created, but email confirmation is required before
  /// signing in (a Supabase project's default) — not a failure, `authState`
  /// stays `null` until confirmation and an explicit sign-in. Throws an
  /// `AccountException` on a real failure (email already used, network
  /// unavailable).
  Future<Account?> signUp({required String email, required String password});

  /// Throws an `AccountException` on failure (invalid credentials,
  /// network unavailable).
  Future<Account> signIn({required String email, required String password});

  /// Signs out locally in every case, even offline — never throws.
  Future<void> signOut();
}
