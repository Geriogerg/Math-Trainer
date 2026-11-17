import 'package:math_trainer/core/domain/account/account.dart';
import 'package:math_trainer/core/domain/account/account_repository.dart';

const _fakeAccount = Account(id: 'fake-account-id', email: 'joueur@test.com');

/// Pour les tests qui ne s'intéressent pas au compte — `AppEnvironment`
/// exige `accountRepository` (pas de défaut concret, `composition_root.dart`),
/// donc chaque test doit en fournir un même s'il n'exerce jamais l'onglet
/// Profil. Connecté par défaut : avec `AuthGate`, la connexion est
/// obligatoire pour atteindre `AppShell`, donc un flux jamais connecté
/// bloquerait tous les tests qui ne testent pas l'authentification
/// elle-même. Voir `auth_gate_test.dart` pour une fausse implémentation
/// contrôlable qui exerce réellement la porte de connexion.
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
  Future<void> signOut() => throw UnimplementedError();
}
