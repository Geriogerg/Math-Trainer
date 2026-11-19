import 'account.dart';

// Part of the contract: every caller of `signIn`/`linkEmail` needs it.
export 'account_exception.dart';

/// Online account — concrete implementation (Supabase) in
/// `infrastructure/backend/`, never in the domain (rule 3).
abstract class AccountRepository {
  /// Signed-in account, `null` if nobody is signed in. Each subscription
  /// first receives the **current** state, then every change (sign-in,
  /// sign-out, session expiry) without polling — so `.first` gives the
  /// account signed in at the time of the call, never an earlier state.
  Stream<Account?> get authState;

  /// Turns the signed-in **guest** into a permanent account: email and
  /// password set in one atomic step (a weak password changes nothing), the
  /// account id kept — so levels and history stay where they are (plan,
  /// section 6.3). `authState` then emits the same id, no longer anonymous.
  ///
  /// `null`: the project requires email confirmation, and the email is
  /// pending until the link in the email is opened (Phase 6; confirmation
  /// is off until then). Throws an `AccountException` on failure
  /// (`emailAlreadyUsed` — the player may sign in to that account instead —
  /// `weakPassword`, `invalidInput`, `network`).
  Future<Account?> linkEmail({required String email, required String password});

  /// Throws an `AccountException` on failure (invalid credentials,
  /// network unavailable).
  Future<Account> signIn({required String email, required String password});

  /// Creates an anonymous player and signs them in (plan, section 6.3:
  /// anonymous-first). Needs the network once; the session is then
  /// persisted locally like any other. Throws an `AccountException` on
  /// failure (`network`, `rateLimited`, `unknown` — e.g. anonymous sign-ins
  /// disabled in the project).
  Future<Account> signInAnonymously();

  /// Signs out locally in every case, even offline — never throws. Never
  /// offered to an anonymous player (`Account.isAnonymous`): their account
  /// would be lost.
  Future<void> signOut();
}
