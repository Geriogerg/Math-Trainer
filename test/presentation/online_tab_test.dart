import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:math_trainer/composition_root.dart';
import 'package:math_trainer/core/domain/account/account.dart';
import 'package:math_trainer/core/domain/account/account_repository.dart';
import 'package:math_trainer/core/domain/persistence/in_memory_session_repository.dart';
import 'package:math_trainer/presentation/screens/online_tab.dart';
import 'package:math_trainer/presentation/theme/app_theme.dart';

/// Contrôlable (déclenche des échecs, simule la confirmation par email) —
/// contrairement à `FakeAccountRepository` (`test/fake_account_repository.dart`),
/// qui ne sert qu'à satisfaire le constructeur d'`AppEnvironment` ailleurs.
class _FakeAccountRepository implements AccountRepository {
  final _controller = StreamController<Account?>.broadcast();

  bool failSignUp = false;
  bool failSignIn = false;
  bool failSignOut = false;
  bool requiresEmailConfirmation = false;

  @override
  Stream<Account?> get authState => _controller.stream;

  @override
  Future<Account?> signUp({
    required String email,
    required String password,
  }) async {
    if (failSignUp) throw Exception('échec simulé');
    if (requiresEmailConfirmation) return null;
    final account = Account(id: 'user-$email', email: email);
    _controller.add(account);
    return account;
  }

  @override
  Future<Account> signIn({
    required String email,
    required String password,
  }) async {
    if (failSignIn) throw Exception('échec simulé');
    final account = Account(id: 'user-$email', email: email);
    _controller.add(account);
    return account;
  }

  @override
  Future<void> signOut() async {
    if (failSignOut) throw Exception('échec simulé');
    _controller.add(null);
  }
}

void main() {
  Future<void> pumpOnlineTab(
    WidgetTester tester,
    AppEnvironment environment,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(body: OnlineTab(environment: environment)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> fillForm(
    WidgetTester tester, {
    String email = 'joueur@test.com',
    String password = 'motdepasse',
  }) async {
    await tester.enterText(find.byType(TextField).at(0), email);
    await tester.enterText(find.byType(TextField).at(1), password);
  }

  testWidgets('affiche le formulaire de connexion par défaut', (tester) async {
    final environment = AppEnvironment(
      repository: InMemorySessionRepository(),
      playerId: 'test-player',
      accountRepository: _FakeAccountRepository(),
    );

    await pumpOnlineTab(tester, environment);

    expect(find.text('Se connecter'), findsWidgets);
    expect(find.byType(TextField), findsNWidgets(2));
  });

  testWidgets(
    'inscription réussie avec session active bascule vers l\'état connecté',
    (tester) async {
      final environment = AppEnvironment(
        repository: InMemorySessionRepository(),
        playerId: 'test-player',
        accountRepository: _FakeAccountRepository(),
      );

      await pumpOnlineTab(tester, environment);
      await tester.tap(find.text('Pas de compte ? S\'inscrire'));
      await tester.pump();
      await fillForm(tester);
      await tester.tap(find.text('Créer le compte'));
      await tester.pumpAndSettle();

      expect(find.text('Connecté'), findsOneWidget);
      expect(find.text('joueur@test.com'), findsOneWidget);
    },
  );

  testWidgets(
    'inscription nécessitant une confirmation affiche un message et repasse en connexion',
    (tester) async {
      final fakeRepository = _FakeAccountRepository()
        ..requiresEmailConfirmation = true;
      final environment = AppEnvironment(
        repository: InMemorySessionRepository(),
        playerId: 'test-player',
        accountRepository: fakeRepository,
      );

      await pumpOnlineTab(tester, environment);
      await tester.tap(find.text('Pas de compte ? S\'inscrire'));
      await tester.pump();
      await fillForm(tester);
      await tester.tap(find.text('Créer le compte'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Compte créé — vérifie ta boîte mail pour confirmer, puis connecte-toi.',
        ),
        findsOneWidget,
      );
      // Repassé en mode connexion, pas resté sur le formulaire d'inscription.
      expect(find.widgetWithText(FilledButton, 'Se connecter'), findsOneWidget);
    },
  );

  testWidgets('erreur de connexion affiche un message et laisse réessayer', (
    tester,
  ) async {
    final fakeRepository = _FakeAccountRepository()..failSignIn = true;
    final environment = AppEnvironment(
      repository: InMemorySessionRepository(),
      playerId: 'test-player',
      accountRepository: fakeRepository,
    );

    await pumpOnlineTab(tester, environment);
    await fillForm(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Se connecter'));
    await tester.pumpAndSettle();

    expect(find.text('Impossible de se connecter.'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Se connecter'),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('déconnexion revient au formulaire', (tester) async {
    final fakeRepository = _FakeAccountRepository();
    final environment = AppEnvironment(
      repository: InMemorySessionRepository(),
      playerId: 'test-player',
      accountRepository: fakeRepository,
    );

    await pumpOnlineTab(tester, environment);
    await fillForm(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Se connecter'));
    await tester.pumpAndSettle();
    expect(find.text('Connecté'), findsOneWidget);

    await tester.tap(find.text('Se déconnecter'));
    await tester.pumpAndSettle();

    expect(find.text('Connecté'), findsNothing);
    expect(find.byType(TextField), findsNWidgets(2));
  });
}
