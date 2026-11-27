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
  /// [ageDeclaredAt]: when the player ticked "I am 15 or older" (Phase 6c
  /// commit 2, plan v4.1; review B1) — kept with the account, as the policy
  /// says.
  ///
  /// `null`: the project requires email confirmation, and the email is
  /// pending until the link in the email is opened (Phase 6; confirmation
  /// is off until then). Throws an `AccountException` on failure
  /// (`emailAlreadyUsed` — the player may sign in to that account instead —
  /// `weakPassword`, `invalidInput`, `network`).
  Future<Account?> linkEmail({
    required String email,
    required String password,
    required DateTime ageDeclaredAt,
  });

  /// Throws an `AccountException` on failure (invalid credentials,
  /// network unavailable).
  Future<Account> signIn({required String email, required String password});

  /// Creates an anonymous player and signs them in (plan, section 6.3:
  /// anonymous-first). Needs the network once; the session is then
  /// persisted locally like any other. Throws an `AccountException` on
  /// failure (`network`, `rateLimited`, `unknown` — e.g. anonymous sign-ins
  /// disabled in the project).
  Future<Account> signInAnonymously();

  /// Deletes the signed-in account on the server — the auth user and,
  /// by cascade, its profile and every server row of this player — through
  /// a database function that only ever deletes the caller
  /// (`supabase/migrations/…_delete_my_account.sql`): no service key in the app. Works for a
  /// guest too. Does **not** sign out: the caller wipes local data first,
  /// then signs out (`AccountDeletionController`). Throws an
  /// `AccountException` if the server deletion failed (`network`, `unknown`
  /// — e.g. the SQL function is not installed): nothing was deleted then.
  Future<void> deleteAccount();

  /// The signed-in player's access token (a JWT), refreshed first if it
  /// has expired — what the server checks on an upload. `null` when nobody
  /// is signed in or the refresh failed (offline): the caller retries later.
  Future<String?> accessToken();

  /// Signs out locally in every case, even offline — never throws. Never
  /// offered to an anonymous player (`Account.isAnonymous`): their account
  /// would be lost.
  Future<void> signOut();
}
