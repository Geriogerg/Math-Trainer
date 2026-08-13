import 'package:math_trainer/core/domain/account/account.dart';
import 'package:math_trainer/core/domain/account/account_repository.dart';

/// Pour les tests qui ne s'intéressent pas au compte — `AppEnvironment`
/// exige `accountRepository` (pas de défaut concret, `composition_root.dart`),
/// donc chaque test doit en fournir un même s'il n'exerce jamais l'onglet En
/// ligne. Ne connecte jamais personne ; voir `online_tab_test.dart` pour une
/// fausse implémentation contrôlable qui exerce réellement le comportement.
class FakeAccountRepository implements AccountRepository {
  @override
  Stream<Account?> get authState => const Stream.empty();

  @override
  Future<Account?> signUp({required String email, required String password}) =>
      throw UnimplementedError();

  @override
  Future<Account> signIn({required String email, required String password}) =>
      throw UnimplementedError();

  @override
  Future<void> signOut() => throw UnimplementedError();
}
