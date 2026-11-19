import 'package:math_trainer/core/domain/account/account.dart';
import 'package:math_trainer/core/domain/account/account_repository.dart';

const _fakeAccount = Account(id: 'fake-account-id', email: 'player@test.com');

/// For tests that do not care about the account — `AppEnvironment` requires
/// `accountRepository` (no concrete default, `composition_root.dart`), so
/// every test must provide one even if it never exercises the Profile tab.
/// Signed in by default: with `AuthGate`, signing in is mandatory to reach
/// `AppShell`, so a never-signed-in stream would block every test that does
/// not test authentication itself. See `auth_gate_test.dart` for a
/// controllable fake that really exercises the sign-in gate.
class FakeAccountRepository implements AccountRepository {
  @override
  Stream<Account?> get authState => Stream.value(_fakeAccount);

  @override
  Future<Account?> signUp({required String email, required String password}) =>
      throw UnimplementedError();

  @override
  Future<Account> signIn({required String email, required String password}) =>
      throw UnimplementedError();

  @override
  Future<Account> signInAnonymously() => throw UnimplementedError();

  @override
  Future<void> signOut() => throw UnimplementedError();
}
