import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:math_trainer/composition_root.dart';
import 'package:math_trainer/core/domain/account/account.dart';
import 'package:math_trainer/core/domain/account/account_repository.dart';
import 'package:math_trainer/core/domain/leveling/level.dart';
import 'package:math_trainer/core/domain/persistence/level_cache_entry.dart';
import 'package:math_trainer/core/domain/models/exercise_type.dart';
import 'package:math_trainer/core/domain/persistence/in_memory_session_repository.dart';
import 'package:math_trainer/core/domain/persistence/persisted_answer.dart';
import 'package:math_trainer/core/domain/persistence/persisted_session.dart';
import 'package:math_trainer/core/domain/persistence/session_repository.dart';
import 'package:math_trainer/presentation/screens/profile_screen.dart';
import 'package:math_trainer/presentation/theme/app_theme.dart';

import '../fake_account_repository.dart';
import '../fake_profile_repository.dart';

/// Fails while [shouldFail] is true, succeeds afterwards — simulates a
/// network/disk that recovers, to test the "Retry" button.
class _FlakySessionRepository implements SessionRepository {
  @override
  Future<void> deletePlayerData(String playerId) => throw UnimplementedError();
  bool shouldFail = true;

  @override
  Future<bool> hasCompletedSession(String playerId) async {
    if (shouldFail) throw Exception('simulated failure');
    return false;
  }

  @override
  Future<Map<ExerciseType, LevelCacheEntry>> currentLevels(
    String playerId,
  ) async {
    if (shouldFail) throw Exception('simulated failure');
    return {
      ExerciseType.addition: LevelCacheEntry(
        level: Level.whole(7),
        sessionsPlayed: 1,
        updatedAt: DateTime.utc(2026, 8, 8),
      ),
    };
  }

  @override
  Future<void> recordSession({
    required PersistedSession session,
    required List<PersistedAnswer> answers,
    required Map<ExerciseType, LevelCacheEntry> levelUpdates,
  }) => throw UnimplementedError();

  @override
  Future<List<PersistedSession>> recentSessions(
    String playerId, {
    int limit = 20,
  }) async {
    if (shouldFail) throw Exception('simulated failure');
    return [];
  }

  @override
  Future<void> transferPlayerData({
    required String fromPlayerId,
    required String toPlayerId,
  }) async {}

  @override
  Future<List<PersistedAnswer>> answersForSession(String sessionId) =>
      throw UnimplementedError();

  @override
  Future<Map<ExerciseType, double>> averageElapsedMsByType(
    String playerId,
  ) async {
    if (shouldFail) throw Exception('simulated failure');
    return {};
  }

  @override
  Future<List<PersistedSession>> sessionsSince(
    String playerId,
    DateTime since,
  ) async {
    if (shouldFail) throw Exception('simulated failure');
    return [];
  }
}

/// Local fake recording the call to `signOut()` — the shared
/// `FakeAccountRepository` throws `UnimplementedError` there (it only
/// satisfies the constructor for tests that do not care).
class _RecordingAccountRepository implements AccountRepository {
  _RecordingAccountRepository({
    this.account = const Account(id: 'test-account', email: 'player@test.com'),
  });

  final Account account;

  @override
  Future<Account> signInAnonymously() => throw UnimplementedError();

  bool signOutCalled = false;
  bool deleteCalled = false;

  @override
  Future<void> deleteAccount() async {
    deleteCalled = true;
  }

  @override
  Stream<Account?> get authState => Stream.value(account);

  @override
  Future<Account?> linkEmail({
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<Account> signIn({required String email, required String password}) =>
      throw UnimplementedError();

  @override
  Future<void> signOut() async {
    signOutCalled = true;
  }
}

void main() {
  // A longer screen now (identity block + 4 progress blocks): a test window
  // that is too short would leave the last lines outside the initial
  // viewport, hence missing from `find.text()` without scrolling.
  Future<void> setTallSurface(WidgetTester tester) async {
    tester.view.physicalSize = const Size(412, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('placement from Profile (owner, end of Phase 1)', () {
    Future<void> pumpProfile(
      WidgetTester tester,
      InMemorySessionRepository repository,
    ) async {
      await setTallSurface(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: Scaffold(
            body: ProfileScreen(
              environment: AppEnvironment(
                repository: repository,
                playerId: 'test-player',
                accountRepository: FakeAccountRepository(),
                profileRepository: FakeProfileRepository(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    PersistedSession game(int exerciseCount) => PersistedSession(
      id: 'game',
      playerId: 'test-player',
      seed: 1,
      enabledTypes: const {ExerciseType.addition},
      exerciseCount: exerciseCount,
      totalScore: 10,
      levels: {ExerciseType.addition: Level.floor},
      createdAt: DateTime.utc(2026, 11, 1),
    );

    PersistedAnswer anAnswer() => PersistedAnswer(
      id: 'answer',
      sessionId: 'game',
      exerciseType: 'arithmetic',
      operationType: 'addition',
      operands: const {'left': 1, 'right': 1},
      submittedValue: 2,
      isCorrect: true,
      elapsedMs: 900,
      createdAt: DateTime.utc(2026, 11, 1),
    );

    testWidgets('offered while no session is completed', (tester) async {
      final repository = InMemorySessionRepository();
      // Interrupted: 1 answer out of 4.
      await repository.recordSession(
        session: game(4),
        answers: [anAnswer()],
        levelUpdates: const {},
      );
      await pumpProfile(tester, repository);

      expect(find.text('Find my level'), findsOneWidget);
    });

    testWidgets('gone once a session is completed', (tester) async {
      final repository = InMemorySessionRepository();
      await repository.recordSession(
        session: game(1),
        answers: [anAnswer()],
        levelUpdates: const {},
      );
      await pumpProfile(tester, repository);

      expect(find.text('Find my level'), findsNothing);
    });
  });

  testWidgets(
    'shows the 7 types, one known level and "Not played" for the others',
    (WidgetTester tester) async {
      await setTallSurface(tester);
      final repository = InMemorySessionRepository();
      await repository.recordSession(
        session: PersistedSession(
          id: 'session-1',
          playerId: 'test-player',
          seed: 1,
          enabledTypes: const {ExerciseType.addition},
          exerciseCount: 8,
          totalScore: 80,
          levels: {ExerciseType.addition: Level.whole(1)},
          createdAt: DateTime.utc(2026, 8, 8),
        ),
        answers: const [],
        levelUpdates: {
          ExerciseType.addition: LevelCacheEntry(
            level: Level.whole(42),
            sessionsPlayed: 1,
            updatedAt: DateTime.utc(2026, 8, 8),
          ),
        },
      );
      final environment = AppEnvironment(
        repository: repository,
        playerId: 'test-player',
        accountRepository: FakeAccountRepository(),
        profileRepository: FakeProfileRepository(),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: Scaffold(body: ProfileScreen(environment: environment)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Level 42'), findsOneWidget);
      expect(find.text('Not played'), findsNWidgets(6));
      for (final type in ExerciseType.values) {
        expect(find.text(_labelFor(type)), findsOneWidget);
      }
    },
  );

  testWidgets(
    'becoming active after a session reloads the levels (IndexedStack does not '
    'rebuild the widget)',
    (WidgetTester tester) async {
      await setTallSurface(tester);
      final repository = InMemorySessionRepository();
      final environment = AppEnvironment(
        repository: repository,
        playerId: 'test-player',
        accountRepository: FakeAccountRepository(),
        profileRepository: FakeProfileRepository(),
      );

      Future<void> pump(bool isActive) => tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: Scaffold(
            body: ProfileScreen(environment: environment, isActive: isActive),
          ),
        ),
      );

      await pump(false);
      await tester.pumpAndSettle();
      expect(find.text('Not played'), findsNWidgets(7));

      await repository.recordSession(
        session: PersistedSession(
          id: 'session-1',
          playerId: 'test-player',
          seed: 1,
          enabledTypes: const {ExerciseType.addition},
          exerciseCount: 8,
          totalScore: 80,
          levels: {ExerciseType.addition: Level.whole(1)},
          createdAt: DateTime.utc(2026, 8, 8),
        ),
        answers: const [],
        levelUpdates: {
          ExerciseType.addition: LevelCacheEntry(
            level: Level.whole(42),
            sessionsPlayed: 1,
            updatedAt: DateTime.utc(2026, 8, 8),
          ),
        },
      );

      // Still inactive: no reload, the view stays the one from before the session.
      await pump(false);
      await tester.pumpAndSettle();
      expect(find.text('Not played'), findsNWidgets(7));

      // Inactive → active transition: didUpdateWidget must restart the load.
      await pump(true);
      await tester.pumpAndSettle();

      expect(find.text('Level 42'), findsOneWidget);
      expect(find.text('Not played'), findsNWidgets(6));
    },
  );

  testWidgets('a failing repository shows a message and a Retry button', (
    WidgetTester tester,
  ) async {
    await setTallSurface(tester);
    final repository = _FlakySessionRepository();
    final environment = AppEnvironment(
      repository: repository,
      playerId: 'test-player',
      accountRepository: FakeAccountRepository(),
      profileRepository: FakeProfileRepository(),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(body: ProfileScreen(environment: environment)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not load the profile.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);
  });

  testWidgets('Retry reloads and shows the profile if it succeeds', (
    WidgetTester tester,
  ) async {
    await setTallSurface(tester);
    final repository = _FlakySessionRepository();
    final environment = AppEnvironment(
      repository: repository,
      playerId: 'test-player',
      accountRepository: FakeAccountRepository(),
      profileRepository: FakeProfileRepository(),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(body: ProfileScreen(environment: environment)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Could not load the profile.'), findsOneWidget);

    repository.shouldFail = false;
    await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Could not load the profile.'), findsNothing);
    expect(find.text('Level 7'), findsOneWidget);
  });

  testWidgets(
    'overall level, change, curve and recent sessions reflect the history (commit E)',
    (WidgetTester tester) async {
      await setTallSurface(tester);
      final repository = InMemorySessionRepository();
      // Relative to the real "now", not a fixed date: the widget filters on
      // `DateTime.now()`, a hard-coded date would drift out of the 30-day
      // window over time.
      final now = DateTime.now().toUtc();

      Future<void> recordAt(
        String id,
        DateTime createdAt,
        int level,
        int score, {
        List<PersistedAnswer> answers = const [],
      }) => repository.recordSession(
        session: PersistedSession(
          id: id,
          playerId: 'test-player',
          seed: 1,
          enabledTypes: const {ExerciseType.addition},
          exerciseCount: 4,
          totalScore: score,
          levels: {ExerciseType.addition: Level.whole(level)},
          createdAt: createdAt,
          // What the controller stores: the overall level (7 types, six at
          // the floor) once addition has moved to [level].
          overallLevelAfter: (level + 6) / 7,
        ),
        answers: answers,
        levelUpdates: {
          ExerciseType.addition: LevelCacheEntry(
            level: Level.whole(level),
            sessionsPlayed: 1,
            updatedAt: createdAt,
          ),
        },
      );

      await recordAt(
        'session-a',
        now.subtract(const Duration(days: 20)),
        30,
        50,
      );
      await recordAt(
        'session-b',
        now.subtract(const Duration(days: 10)),
        40,
        60,
      );
      await recordAt(
        'session-c',
        now.subtract(const Duration(days: 1)),
        50,
        70,
        answers: [
          PersistedAnswer(
            id: 'answer-1',
            sessionId: 'session-c',
            exerciseType: 'arithmetic',
            operationType: 'addition',
            operands: const {'operandA': 1, 'operandB': 1},
            submittedValue: 2,
            isCorrect: true,
            elapsedMs: 1000,
            createdAt: now,
          ),
          PersistedAnswer(
            id: 'answer-2',
            sessionId: 'session-c',
            exerciseType: 'arithmetic',
            operationType: 'addition',
            operands: const {'operandA': 1, 'operandB': 1},
            submittedValue: 2,
            isCorrect: true,
            elapsedMs: 2000,
            createdAt: now,
          ),
        ],
      );
      final environment = AppEnvironment(
        repository: repository,
        playerId: 'test-player',
        accountRepository: FakeAccountRepository(),
        profileRepository: FakeProfileRepository(),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: Scaffold(body: ProfileScreen(environment: environment)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Profile'), findsOneWidget);
      // (50 + 6 × 1 floor for the 6 types not played) / 7 = 8.
      expect(find.textContaining('Overall level: 8'), findsOneWidget);
      // Overall level after the window's first session (36/7) then after the
      // last (56/7): 20/7 ≈ +3 — the last game counts.
      expect(find.textContaining('30-day change: +3'), findsOneWidget);
      // Effect of each of the two latest sessions: 10/7 ≈ +1; the oldest has
      // no previous session to compare with.
      expect(find.text('+1'), findsNWidgets(2));
      expect(find.text('Not enough data for the last 30 days.'), findsNothing);
      expect(find.textContaining('Level 50 · 1500 ms'), findsOneWidget);
      expect(find.textContaining('Score 70'), findsOneWidget);
      expect(find.textContaining('Score 60'), findsOneWidget);
      expect(find.textContaining('Score 50'), findsOneWidget);
    },
  );

  testWidgets('shows the prompt when no player name is saved', (
    WidgetTester tester,
  ) async {
    await setTallSurface(tester);
    final environment = AppEnvironment(
      repository: InMemorySessionRepository(),
      playerId: 'test-player',
      accountRepository: FakeAccountRepository(),
      profileRepository: FakeProfileRepository()..displayName = null,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(body: ProfileScreen(environment: environment)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Choose a player name'), findsOneWidget);
    expect(find.text('player@test.com'), findsOneWidget);
  });

  // Regression: the name (network) and the statistics (local) were read in
  // the same `Future.wait` — offline, the whole screen fell to "Could not
  // load the profile.", local statistics included.
  testWidgets('player name unreachable: the local statistics stay shown', (
    WidgetTester tester,
  ) async {
    await setTallSurface(tester);
    final profileRepository = FakeProfileRepository()..shouldFail = true;
    final environment = AppEnvironment(
      repository: InMemorySessionRepository(),
      playerId: 'test-player',
      accountRepository: FakeAccountRepository(),
      profileRepository: profileRepository,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(body: ProfileScreen(environment: environment)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not load the profile.'), findsNothing);
    expect(find.text('By operation'), findsOneWidget);
    expect(find.text('player@test.com'), findsOneWidget);
    expect(find.text('Player name unavailable'), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);

    profileRepository
      ..shouldFail = false
      ..displayName = 'Alex';
    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();

    expect(find.text('Alex'), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
  });

  testWidgets('shows the player name already saved', (
    WidgetTester tester,
  ) async {
    await setTallSurface(tester);
    final environment = AppEnvironment(
      repository: InMemorySessionRepository(),
      playerId: 'test-player',
      accountRepository: FakeAccountRepository(),
      profileRepository: FakeProfileRepository()..displayName = 'Alex',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(body: ProfileScreen(environment: environment)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Alex'), findsOneWidget);
    expect(find.text('Choose a player name'), findsNothing);
  });

  testWidgets(
    'editing the player name calls updateDisplayName and refreshes the display',
    (WidgetTester tester) async {
      await setTallSurface(tester);
      final profileRepository = FakeProfileRepository()..displayName = 'Alex';
      final environment = AppEnvironment(
        repository: InMemorySessionRepository(),
        playerId: 'test-player',
        accountRepository: FakeAccountRepository(),
        profileRepository: profileRepository,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: Scaffold(body: ProfileScreen(environment: environment)),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Nouveau nom');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(profileRepository.displayName, 'Nouveau nom');
      expect(find.text('Nouveau nom'), findsOneWidget);
    },
  );

  testWidgets('an unsaved name is reported, the old name stays shown', (
    WidgetTester tester,
  ) async {
    await setTallSurface(tester);
    final profileRepository = FakeProfileRepository()
      ..displayName = 'Alex'
      ..updateShouldFail = true;
    final environment = AppEnvironment(
      repository: InMemorySessionRepository(),
      playerId: 'test-player',
      accountRepository: FakeAccountRepository(),
      profileRepository: profileRepository,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(body: ProfileScreen(environment: environment)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Nouveau nom');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Name not saved'), findsOneWidget);
    expect(find.text('Alex'), findsOneWidget);
  });

  testWidgets('Sign out calls signOut', (WidgetTester tester) async {
    await setTallSurface(tester);
    final accountRepository = _RecordingAccountRepository();
    final environment = AppEnvironment(
      repository: InMemorySessionRepository(),
      playerId: 'test-player',
      accountRepository: accountRepository,
      profileRepository: FakeProfileRepository(),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(body: ProfileScreen(environment: environment)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(accountRepository.signOutCalled, isTrue);
  });

  testWidgets('a guest sees "Guest", can save their progress, never sign out', (
    WidgetTester tester,
  ) async {
    await setTallSurface(tester);
    final environment = AppEnvironment(
      repository: InMemorySessionRepository(),
      playerId: 'guest-1',
      accountRepository: _RecordingAccountRepository(
        account: const Account(id: 'guest-1', isAnonymous: true),
      ),
      profileRepository: FakeProfileRepository(),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(body: ProfileScreen(environment: environment)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Guest'), findsOneWidget);
    expect(find.text('Sign out'), findsNothing);
    expect(find.text('Save your progress'), findsOneWidget);
    expect(find.text('I already have an account'), findsOneWidget);

    await tester.tap(find.text('Save your progress'));
    await tester.pumpAndSettle();
    expect(find.text('Player name'), findsOneWidget);
  });

  group('deletion', () {
    Future<_RecordingAccountRepository> pumpProfile(
      WidgetTester tester,
      Account account,
    ) async {
      await setTallSurface(tester);
      final accounts = _RecordingAccountRepository(account: account);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: Scaffold(
            body: ProfileScreen(
              environment: AppEnvironment(
                repository: InMemorySessionRepository(),
                playerId: account.id,
                accountRepository: accounts,
                profileRepository: FakeProfileRepository(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return accounts;
    }

    testWidgets('a guest deletes their data after confirming', (tester) async {
      final accounts = await pumpProfile(
        tester,
        const Account(id: 'guest-1', isAnonymous: true),
      );

      await tester.ensureVisible(find.text('Delete my data'));
      await tester.tap(find.text('Delete my data'));
      await tester.pumpAndSettle();
      expect(find.text('Delete your data?'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(accounts.deleteCalled, isTrue);
      expect(accounts.signOutCalled, isTrue);
      expect(find.text('Your data was deleted.'), findsOneWidget);
    });

    testWidgets('Cancel deletes nothing', (tester) async {
      final accounts = await pumpProfile(
        tester,
        const Account(id: 'guest-1', isAnonymous: true),
      );

      await tester.ensureVisible(find.text('Delete my data'));
      await tester.tap(find.text('Delete my data'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(accounts.deleteCalled, isFalse);
      expect(accounts.signOutCalled, isFalse);
    });

    testWidgets('an email account reads "Delete my account"', (tester) async {
      await pumpProfile(
        tester,
        const Account(id: 'a', email: 'player@test.com'),
      );
      expect(find.text('Delete my account'), findsOneWidget);
      expect(find.text('Delete my data'), findsNothing);
    });
  });
}

String _labelFor(ExerciseType type) => switch (type) {
  ExerciseType.addition => 'Addition',
  ExerciseType.subtraction => 'Subtraction',
  ExerciseType.multiplication => 'Multiplication',
  ExerciseType.division => 'Division',
  ExerciseType.power => 'Powers',
  ExerciseType.squareRoot => 'Square roots',
  ExerciseType.percentage => 'Percentages',
};
