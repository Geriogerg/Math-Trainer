import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:math_trainer/composition_root.dart';
import 'package:math_trainer/core/domain/account/account.dart';
import 'package:math_trainer/core/domain/account/account_repository.dart';
import 'package:math_trainer/core/domain/models/exercise_type.dart';
import 'package:math_trainer/core/domain/persistence/in_memory_session_repository.dart';
import 'package:math_trainer/core/domain/persistence/level_cache_entry.dart';
import 'package:math_trainer/core/domain/persistence/persisted_session.dart';
import 'package:math_trainer/presentation/screens/auth_gate.dart';
import 'package:math_trainer/presentation/theme/app_theme.dart';

import '../fake_account_repository.dart';
import '../fake_profile_repository.dart';

/// Contrôlable — contrairement à `FakeAccountRepository`
/// (`test/fake_account_repository.dart`), qui démarre déjà connecté et ne
/// sert qu'aux tests qui ne s'intéressent pas à la porte elle-même.
class _ControllableAccountRepository implements AccountRepository {
  final _controller = StreamController<Account?>.broadcast();

  /// Simule la résolution de la session locale (persistée ou absente) —
  /// `AuthGate` ne doit jamais afficher le formulaire tant que cette
  /// résolution n'a pas eu lieu, pour ne pas faire clignoter la porte pour
  /// un joueur déjà connecté.
  void resolveSession(Account? account) => _controller.add(account);

  @override
  Stream<Account?> get authState => _controller.stream;

  @override
  Future<Account?> signUp({
    required String email,
    required String password,
  }) async {
    final account = Account(id: 'user-$email', email: email);
    _controller.add(account);
    return account;
  }

  @override
  Future<Account> signIn({
    required String email,
    required String password,
  }) async {
    final account = Account(id: 'user-$email', email: email);
    _controller.add(account);
    return account;
  }

  @override
  Future<void> signOut() async {
    _controller.add(null);
  }
}

void main() {
  Future<AppEnvironment> pumpGate(
    WidgetTester tester,
    _ControllableAccountRepository accountRepository,
  ) async {
    final environment = AppEnvironment(
      repository: InMemorySessionRepository(),
      playerId: 'test-player',
      accountRepository: accountRepository,
      profileRepository: FakeProfileRepository(),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: AuthGate(environment: environment),
      ),
    );
    return environment;
  }

  testWidgets(
    'affiche un indicateur de chargement tant que la session locale n\'est pas résolue',
    (tester) async {
      await pumpGate(tester, _ControllableAccountRepository());
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Math Trainer'), findsNothing);
    },
  );

  testWidgets(
    'affiche le formulaire de connexion une fois la session résolue comme absente',
    (tester) async {
      final accountRepository = _ControllableAccountRepository();
      await pumpGate(tester, accountRepository);
      await tester.pump();

      accountRepository.resolveSession(null);
      await tester.pumpAndSettle();

      expect(find.text('Se connecter'), findsWidgets);
      expect(find.byType(TextField), findsNWidgets(2));
    },
  );

  testWidgets('se connecter depuis le formulaire bascule vers AppShell', (
    tester,
  ) async {
    final accountRepository = _ControllableAccountRepository();
    await pumpGate(tester, accountRepository);
    await tester.pump();
    accountRepository.resolveSession(null);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'joueur@test.com');
    await tester.enterText(find.byType(TextField).at(1), 'motdepasse');
    await tester.tap(find.widgetWithText(FilledButton, 'Se connecter'));
    await tester.pumpAndSettle();

    expect(find.text('Math Trainer'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  // Régression : `authState` renvoie un nouveau `Stream` à chaque lecture.
  // Lu dans `build()`, chaque reconstruction du parent (bascule nuit/jour)
  // réabonnait `StreamBuilder`, qui repassait par `waiting` : `AppShell`
  // était démonté puis recréé, et l'onglet courant revenait sur Jouer.
  testWidgets(
    'une reconstruction du parent conserve l\'état d\'AppShell (onglet courant)',
    (tester) async {
      final environment = AppEnvironment(
        repository: InMemorySessionRepository(),
        playerId: 'test-player',
        accountRepository: FakeAccountRepository(),
        profileRepository: FakeProfileRepository(),
      );
      late StateSetter rebuildParent;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: StatefulBuilder(
            builder: (context, setState) {
              rebuildParent = setState;
              return AuthGate(environment: environment);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Profil'));
      await tester.pumpAndSettle();

      rebuildParent(() {});
      await tester.pump();

      expect(
        find.byType(CircularProgressIndicator),
        findsNothing,
        reason: 'la porte ne doit pas repasser par l\'état de chargement',
      );
      await tester.pumpAndSettle();
      final navigationBar = tester.widget<NavigationBar>(
        find.byType(NavigationBar),
      );
      expect(navigationBar.selectedIndex, 2);
    },
  );

  group('données rattachées au compte', () {
    // `PlayTab` lit la sélection mémorisée avec le niveau global : sans
    // préférences simulées, cette lecture échoue et l'écran reste sur
    // l'accueil, quel que soit l'historique.
    setUp(() => SharedPreferences.setMockInitialValues({}));

    const accountA = Account(id: 'compte-a', email: 'a@test.com');
    const accountB = Account(id: 'compte-b', email: 'b@test.com');
    const welcome = "La difficulté s'ajuste à tes réponses.";

    /// Partie jouée sous l'id local de l'appareil (`test-player`, celui de
    /// `pumpGate`), comme avant le passage aux comptes. Addition au niveau
    /// 43, les six autres types au plancher : niveau global (43 + 6) / 7 = 7.
    Future<void> playOnDevice(AppEnvironment environment) =>
        environment.repository.recordSession(
          session: PersistedSession(
            id: 'session-appareil',
            playerId: environment.playerId,
            seed: 1,
            enabledTypes: const {ExerciseType.addition},
            exerciseCount: 4,
            totalScore: 100,
            levels: const {ExerciseType.addition: 40},
            createdAt: DateTime.utc(2026, 11, 1),
          ),
          answers: const [],
          levelUpdates: {
            ExerciseType.addition: LevelCacheEntry(
              level: 43,
              sessionsPlayed: 1,
              updatedAt: DateTime.utc(2026, 11, 1),
            ),
          },
        );

    testWidgets(
      "les parties de l'appareil reviennent au premier compte connecté, pas au suivant",
      (tester) async {
        final accountRepository = _ControllableAccountRepository();
        final environment = await pumpGate(tester, accountRepository);
        await playOnDevice(environment);

        accountRepository.resolveSession(accountA);
        await tester.pumpAndSettle();
        expect(find.text('Niveau global : 7'), findsOneWidget);

        accountRepository.resolveSession(null);
        await tester.pumpAndSettle();
        accountRepository.resolveSession(accountB);
        await tester.pumpAndSettle();
        expect(find.text(welcome), findsOneWidget);

        accountRepository.resolveSession(null);
        await tester.pumpAndSettle();
        accountRepository.resolveSession(accountA);
        await tester.pumpAndSettle();
        expect(find.text('Niveau global : 7'), findsOneWidget);
      },
    );

    testWidgets(
      'changer de compte sans passer par la déconnexion repart à neuf',
      (tester) async {
        final accountRepository = _ControllableAccountRepository();
        final environment = await pumpGate(tester, accountRepository);
        await playOnDevice(environment);
        accountRepository.resolveSession(accountA);
        await tester.pumpAndSettle();
        expect(find.text('Niveau global : 7'), findsOneWidget);

        accountRepository.resolveSession(accountB);
        await tester.pumpAndSettle();

        expect(find.text(welcome), findsOneWidget);
      },
    );
  });
}
