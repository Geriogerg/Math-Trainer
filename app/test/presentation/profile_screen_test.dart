import '../fake_stores.dart';
import 'package:math_core/challenges/challenge_stats.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_core/models/operation_type.dart';
import 'package:math_core/models/exercise.dart';
import 'package:math_core/models/answer_result.dart';
import 'package:math_core/challenges/tables.dart';

import 'package:math_trainer/composition_root.dart';
import 'package:math_core/account/account.dart';
import 'package:math_core/account/account_repository.dart';
import 'package:math_core/leveling/level.dart';
import 'package:math_core/leveling/rules_version.dart';
import 'package:math_core/persistence/level_cache_entry.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/persistence/in_memory_session_repository.dart';
import 'package:math_core/persistence/persisted_answer.dart';
import 'package:math_core/persistence/persisted_session.dart';
import 'package:math_core/persistence/session_repository.dart';
import 'package:math_core/sync/session_upload.dart';
import 'package:math_core/sync/session_upload_client.dart';
import 'package:math_trainer/presentation/screens/profile_screen.dart';
import 'package:math_trainer/presentation/theme/app_theme.dart';

import '../fake_account_repository.dart';
import '../fake_profile_repository.dart';
import 'kit_finders.dart';

/// A server that is never reached in these tests.
class _NoUploadClient implements SessionUploadClient {
  @override
  Future<UploadOutcome> upload(SessionUpload upload) =>
      throw StateError('no upload in this test');
}

/// Fails while [shouldFail] is true, succeeds afterwards — simulates a
/// network/disk that recovers, to test the "Retry" button.
class _FlakySessionRepository implements SessionRepository {
  @override
  Future<List<StoredGame>> storedGames(String playerId) async => const [];

  @override
  Future<List<PersistedSession>> pendingUploads(String playerId) async => [];
  @override
  Future<void> markSynced(String sessionId, DateTime syncedAt) async {}
  @override
  Future<void> markUploadRefused(String sessionId, String reason) async {}
  @override
  Future<void> replaceLevelCache(
    String playerId,
    Map<ExerciseType, LevelCacheEntry> levels,
  ) async {}
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
  @override
  Future<String?> accessToken() async => 'test-token';
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
    required DateTime ageDeclaredAt,
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

  testWidgets('no placement offered; the main level is 0 before any game', (
    tester,
  ) async {
    await setTallSurface(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(
          body: ProfileScreen(
            environment: AppEnvironment(
              repository: InMemorySessionRepository(),
              playerId: 'test-player',
              accountRepository: FakeAccountRepository(),
              profileRepository: FakeProfileRepository(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Find my level'), findsNothing);
    expect(findLevelBadge(0), findsOneWidget);
  });

  testWidgets('a refused game says why it is not ranked (Phase 3a commit 2)', (
    WidgetTester tester,
  ) async {
    await setTallSurface(tester);
    final repository = InMemorySessionRepository();
    for (final (id, day) in [('accepted', 8), ('refused', 9)]) {
      await repository.recordSession(
        session: PersistedSession(
          id: id,
          playerId: 'test-player',
          seed: 1,
          enabledTypes: const {ExerciseType.addition},
          exerciseCount: 8,
          totalScore: 80,
          levels: {ExerciseType.addition: Level.whole(1)},
          createdAt: DateTime.utc(2026, 8, day),
        ),
        answers: const [],
        levelUpdates: const {},
      );
    }
    await repository.markSynced('accepted', DateTime.utc(2026, 8, 8, 1));
    await repository.markUploadRefused('refused', 'levelsMismatch');
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

    expect(find.textContaining('Not ranked:'), findsOneWidget);
    expect(
      find.textContaining('levels the server did not have'),
      findsOneWidget,
    );
  });

  testWidgets(
    'shows every type, one known level and "Not played" for the others',
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

      expect(findLevelBadge(42), findsOneWidget);
      expect(
        find.text('Not played'),
        findsNWidgets(ExerciseType.values.length - 1),
      );
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
      expect(
        find.text('Not played'),
        findsNWidgets(ExerciseType.values.length),
      );

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
      expect(
        find.text('Not played'),
        findsNWidgets(ExerciseType.values.length),
      );

      // Inactive → active transition: didUpdateWidget must restart the load.
      await pump(true);
      await tester.pumpAndSettle();

      expect(findLevelBadge(42), findsOneWidget);
      expect(
        find.text('Not played'),
        findsNWidgets(ExerciseType.values.length - 1),
      );
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
    expect(findLevelBadge(7), findsOneWidget);
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
          rulesVersion: RulesVersion.current,
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
      // Main level: 50 / 4 = 12.5 (the basics not played at 0), shown as
      // its whole part, 12 (Phase 6b commit 7, review m3: it was rounded).
      expect(findLevelBadge(12), findsOneWidget);
      // Overall level after the window's first session (36/7) then after the
      // last (56/7): 20/7 ≈ +3 — the last game counts.
      expect(find.textContaining('30-day change: +3'), findsOneWidget);
      // Effect of each of the two latest sessions: 10/7 ≈ +1; the oldest has
      // no previous session to compare with.
      expect(find.text('+1'), findsNWidgets(2));
      expect(find.text('Not enough data for the last 30 days.'), findsNothing);
      expect(findLevelBadge(50), findsOneWidget);
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

  // Phase 6a commit 3 (plan v3.9): the owner hid or suspended the account.
  testWidgets('an account the owner hid says "Account under review"; any '
      'other says nothing', (WidgetTester tester) async {
    await setTallSurface(tester);
    final profiles = FakeProfileRepository()..displayName = 'Alex';
    Future<void> pump() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: Scaffold(
            body: ProfileScreen(
              key: UniqueKey(),
              environment: AppEnvironment(
                repository: InMemorySessionRepository(),
                playerId: 'test-player',
                accountRepository: FakeAccountRepository(),
                profileRepository: profiles,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pump();
    expect(find.text('Account under review'), findsNothing);

    profiles.underReview = true;
    await pump();
    expect(find.text('Account under review'), findsOneWidget);
    expect(
      find.textContaining('not shown on the boards'),
      findsOneWidget,
      reason: 'said in words, never by colour alone',
    );
    expect(find.text('Alex'), findsOneWidget, reason: 'the rest is unchanged');
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

  // Phase 6a commit 4 (plan v3.9): names are unique.
  testWidgets('a name another player holds: "taken", the old name stays', (
    WidgetTester tester,
  ) async {
    await setTallSurface(tester);
    final profileRepository = FakeProfileRepository()
      ..displayName = 'Alex'
      ..nameTaken = true;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(
          body: ProfileScreen(
            environment: AppEnvironment(
              repository: InMemorySessionRepository(),
              playerId: 'test-player',
              accountRepository: FakeAccountRepository(),
              profileRepository: profileRepository,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Lili Rose');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('This name is taken — try another.'), findsOneWidget);
    expect(find.text('Alex'), findsOneWidget);
  });

  testWidgets('games not sent yet are counted under Recent sessions '
      '(Phase 6b commit 4, review m17)', (WidgetTester tester) async {
    await setTallSurface(tester);
    final repository = InMemorySessionRepository();
    for (final (id, day) in [('a', 8), ('b', 9)]) {
      await repository.recordSession(
        session: PersistedSession(
          id: id,
          playerId: 'test-player',
          seed: 1,
          enabledTypes: const {ExerciseType.addition},
          exerciseCount: 8,
          totalScore: 80,
          levels: {ExerciseType.addition: Level.whole(1)},
          createdAt: DateTime.utc(2026, 8, day),
          rulesVersion: RulesVersion.current,
        ),
        answers: const [],
        levelUpdates: const {},
      );
    }
    Future<void> pumpWith(SessionUploadClient? uploads) async {
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
                uploadClient: uploads,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pumpWith(_NoUploadClient());
    expect(
      find.text('2 games not sent yet: they go when the server answers.'),
      findsOneWidget,
    );
    await repository.markSynced('a', DateTime.utc(2026, 8, 9, 1));
    await tester.pumpWidget(const SizedBox());
    await pumpWith(_NoUploadClient());
    expect(
      find.text('1 game not sent yet: it goes when the server answers.'),
      findsOneWidget,
    );
    // No server: nothing is waiting to be sent.
    await tester.pumpWidget(const SizedBox());
    await pumpWith(null);
    expect(find.textContaining('not sent yet'), findsNothing);
  });

  testWidgets('a saved account is told other devices\' games are not here; '
      'a guest is not (Phase 6b commit 5, review M14)', (
    WidgetTester tester,
  ) async {
    await setTallSurface(tester);
    Future<void> pumpAs({required bool guest}) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: Scaffold(
            body: ProfileScreen(
              environment: AppEnvironment(
                repository: InMemorySessionRepository(),
                playerId: 'test-player',
                accountRepository: FakeAccountRepository(anonymous: guest),
                profileRepository: FakeProfileRepository(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    const line = 'Games played on other devices are not shown here.';
    await pumpAs(guest: false);
    expect(find.text(line), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await pumpAs(guest: true);
    expect(find.text(line), findsNothing);
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
    // Asked first (Phase 6b commit 4, review m17): Cancel changes nothing.
    expect(find.text('Sign out?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(accountRepository.signOutCalled, isFalse);
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out').last);
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

      await tester.scrollUntilVisible(
        find.text('Delete my data'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
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

      await tester.scrollUntilVisible(
        find.text('Delete my data'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
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
      await tester.scrollUntilVisible(
        find.text('Delete my account'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Delete my account'), findsOneWidget);
      expect(find.text('Delete my data'), findsNothing);
    });
  });

  testWidgets('the challenges: games, solved, best time (Redesign phase)', (
    WidgetTester tester,
  ) async {
    await setTallSurface(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(
          body: ProfileScreen(
            environment: AppEnvironment(
              repository: InMemorySessionRepository(),
              playerId: 'test-player',
              accountRepository: FakeAccountRepository(),
              profileRepository: FakeProfileRepository(),
              challengeStatsStore: FakeChallengeStatsStore({
                Challenge.getTheCount: const ChallengeStats(
                  games: 7,
                  solved: 4,
                  bestTimeMs: 12340,
                ),
              }),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Chain operations'), 200);
    expect(find.text('Challenges'), findsOneWidget);
    expect(find.text('Get the count'), findsOneWidget);
    expect(find.text('12.3 s'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    // Never played: zeros and a dash.
    expect(find.text('—'), findsWidgets);
  });

  testWidgets('Tables: games, right answers as a count, the slowest facts '
      '(doc/levels.md section 7)', (WidgetTester tester) async {
    await setTallSurface(tester);
    AnswerResult fact(int t, int m, int ms, {bool right = true}) =>
        AnswerResult(
          exercise: ArithmeticExercise(
            operandA: t,
            operandB: m,
            operationType: OperationType.multiplication,
          ),
          submittedValue: right ? t * m : 0,
          isCorrect: right,
          elapsedMs: ms,
          answeredAt: DateTime.utc(2026, 11, 23),
        );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(
          body: ProfileScreen(
            environment: AppEnvironment(
              repository: InMemorySessionRepository(),
              playerId: 'test-player',
              accountRepository: FakeAccountRepository(),
              profileRepository: FakeProfileRepository(),
              tablesStore: FakeTablesStore(
                stats: TablesStats.none.record([
                  fact(17, 8, 9400),
                  fact(13, 7, 6100, right: false),
                  fact(12, 12, 2000),
                  fact(6, 7, 1000),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Slowest'), 200);
    expect(find.text('Tables'), findsOneWidget);
    expect(find.text('3 / 4'), findsOneWidget);
    expect(find.text('17 × 8   9.4 s'), findsOneWidget);
    expect(find.text('13 × 7   6.1 s'), findsOneWidget);
    expect(find.text('12 × 12   2.0 s'), findsOneWidget);
    expect(find.textContaining('6 × 7'), findsNothing);
  });
}

String _labelFor(ExerciseType type) => switch (type) {
  ExerciseType.addition => 'Addition',
  ExerciseType.subtraction => 'Subtraction',
  ExerciseType.multiplication => 'Multiplication',
  ExerciseType.division => 'Division',
  ExerciseType.power => 'Powers',
  ExerciseType.squareRoot => 'Roots',
  ExerciseType.percentage => 'Percentages',
  ExerciseType.integral => 'Integrals',
};
