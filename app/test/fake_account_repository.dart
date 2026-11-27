import 'package:math_core/account/account.dart';
import 'package:math_core/account/account_repository.dart';

const _fakeAccount = Account(id: 'fake-account-id', email: 'player@test.com');

/// For tests that do not care about the account — `AppEnvironment` requires
/// `accountRepository` (no concrete default, `composition_root.dart`), so
/// every test must provide one even if it never exercises the Profile tab.
/// Signed in by default: with `AuthGate`, signing in is mandatory to reach
/// `AppShell`, so a never-signed-in stream would block every test that does
/// not test authentication itself. See `auth_gate_test.dart` for a
/// controllable fake that really exercises the sign-in gate.
class FakeAccountRepository implements AccountRepository {
  FakeAccountRepository({this.anonymous = false});

  /// A guest (Phase 6a: only saved accounts report names).
  final bool anonymous;

  @override
  Future<String?> accessToken() async => 'test-token';
  @override
  Future<void> deleteAccount() => throw UnimplementedError();
  @override
  Stream<Account?> get authState => Stream.value(
    anonymous
        ? const Account(id: 'fake-account-id', isAnonymous: true)
        : _fakeAccount,
  );

  @override
  Future<Account?> linkEmail({
    required String email,
    required String password,
    required DateTime ageDeclaredAt,
    required String language,
  }) => throw UnimplementedError();

  @override
  Future<void> resendConfirmation({required String email}) =>
      throw UnimplementedError();

  @override
  Future<void> requestPasswordReset({required String email}) =>
      throw UnimplementedError();

  @override
  Future<void> setPassword({required String password}) =>
      throw UnimplementedError();

  /// The languages the app told the account (Phase 6d).
  final rememberedLanguages = <String>[];

  @override
  Future<void> rememberLanguage(String language) async =>
      rememberedLanguages.add(language);

  @override
  Future<Account> signIn({required String email, required String password}) =>
      throw UnimplementedError();

  @override
  Future<Account> signInAnonymously() => throw UnimplementedError();

  @override
  Future<void> signOut() => throw UnimplementedError();
}
