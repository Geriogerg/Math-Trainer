import 'dart:async';

import 'package:material_ui/material_ui.dart';
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

/// Controllable — unlike `FakeAccountRepository`
/// (`test/fake_account_repository.dart`), which starts signed in and only
/// serves tests that do not care about the gate itself.
class _ControllableAccountRepository implements AccountRepository {
  final _controller = StreamController<Account?>.broadcast();

  /// Simulates resolving the local session (persisted or absent) —
  /// `AuthGate` must never show the form before this resolution, so the
  /// gate does not flicker for a player already signed in.
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

  testWidgets('shows a loading indicator until the local session is resolved', (
    tester,
  ) async {
    await pumpGate(tester, _ControllableAccountRepository());
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Math Trainer'), findsNothing);
  });

  testWidgets('shows the sign-in form once the session resolves as absent', (
    tester,
  ) async {
    final accountRepository = _ControllableAccountRepository();
    await pumpGate(tester, accountRepository);
    await tester.pump();

    accountRepository.resolveSession(null);
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsWidgets);
    expect(find.byType(TextField), findsNWidgets(2));
  });

  testWidgets('signing in from the form switches to AppShell', (tester) async {
    final accountRepository = _ControllableAccountRepository();
    await pumpGate(tester, accountRepository);
    await tester.pump();
    accountRepository.resolveSession(null);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'player@test.com');
    await tester.enterText(find.byType(TextField).at(1), 'motdepasse');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Math Trainer'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  // Regression: `authState` returns a new `Stream` on each read. Read in
  // `build()`, every rebuild of the parent (day/night toggle) resubscribed
  // `StreamBuilder`, which went back through `waiting`: `AppShell` was
  // unmounted then recreated, and the current tab went back to Play.
  testWidgets("a parent rebuild keeps AppShell's state (current tab)", (
    tester,
  ) async {
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
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    rebuildParent(() {});
    await tester.pump();

    expect(
      find.byType(CircularProgressIndicator),
      findsNothing,
      reason: 'the gate must not go back through the loading state',
    );
    await tester.pumpAndSettle();
    final navigationBar = tester.widget<NavigationBar>(
      find.byType(NavigationBar),
    );
    expect(navigationBar.selectedIndex, 2);
  });

  group('data bound to the account', () {
    // `PlayTab` reads the remembered selection along with the overall level:
    // without simulated preferences, that read fails and the screen stays on
    // the welcome text, whatever the history.
    setUp(() => SharedPreferences.setMockInitialValues({}));

    const accountA = Account(id: 'compte-a', email: 'a@test.com');
    const accountB = Account(id: 'compte-b', email: 'b@test.com');
    const welcome = 'Difficulty adapts to your answers.';

    /// Game played under the device's local id (`test-player`, the one of
    /// `pumpGate`), as before accounts. Addition at level 43, the six other
    /// types at the floor: overall level (43 + 6) / 7 = 7.
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
      "the device's games go to the first account that signs in, not the next one",
      (tester) async {
        final accountRepository = _ControllableAccountRepository();
        final environment = await pumpGate(tester, accountRepository);
        await playOnDevice(environment);

        accountRepository.resolveSession(accountA);
        await tester.pumpAndSettle();
        expect(find.text('Overall level: 7'), findsOneWidget);

        accountRepository.resolveSession(null);
        await tester.pumpAndSettle();
        accountRepository.resolveSession(accountB);
        await tester.pumpAndSettle();
        expect(find.text(welcome), findsOneWidget);

        accountRepository.resolveSession(null);
        await tester.pumpAndSettle();
        accountRepository.resolveSession(accountA);
        await tester.pumpAndSettle();
        expect(find.text('Overall level: 7'), findsOneWidget);
      },
    );

    testWidgets('switching accounts without signing out starts afresh', (
      tester,
    ) async {
      final accountRepository = _ControllableAccountRepository();
      final environment = await pumpGate(tester, accountRepository);
      await playOnDevice(environment);
      accountRepository.resolveSession(accountA);
      await tester.pumpAndSettle();
      expect(find.text('Overall level: 7'), findsOneWidget);

      accountRepository.resolveSession(accountB);
      await tester.pumpAndSettle();

      expect(find.text(welcome), findsOneWidget);
    });
  });
}
