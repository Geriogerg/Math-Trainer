import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:math_trainer/app.dart';
import 'package:math_trainer/presentation/screens/session_screen.dart';
import 'package:math_trainer/presentation/screens/result_screen.dart';
import 'package:math_trainer/presentation/screens/play_tab.dart';
import 'package:math_trainer/presentation/kit/kit.dart';
import 'package:math_trainer/composition_root.dart';
import 'package:math_core/persistence/level_cache_entry.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/leveling/level.dart';
import 'package:math_core/persistence/in_memory_session_repository.dart';
import 'package:math_core/persistence/persisted_answer.dart';
import 'package:math_core/persistence/persisted_session.dart';
import 'package:math_core/persistence/session_repository.dart';
import 'package:math_trainer/core/state/session_controller.dart';

import 'fake_account_repository.dart';
import 'fake_profile_repository.dart';

class _ThrowingSessionRepository implements SessionRepository {
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
  @override
  Future<bool> hasCompletedSession(String playerId) =>
      throw Exception('simulated failure');
  @override
  Future<void> recordSession({
    required PersistedSession session,
    required List<PersistedAnswer> answers,
    required Map<ExerciseType, LevelCacheEntry> levelUpdates,
  }) => throw Exception('simulated failure');

  @override
  Future<List<PersistedSession>> recentSessions(
    String playerId, {
    int limit = 20,
  }) => throw Exception('simulated failure');

  @override
  Future<void> transferPlayerData({
    required String fromPlayerId,
    required String toPlayerId,
  }) => throw Exception('simulated failure');

  @override
  Future<List<PersistedAnswer>> answersForSession(String sessionId) =>
      throw Exception('simulated failure');

  @override
  Future<Map<ExerciseType, LevelCacheEntry>> currentLevels(String playerId) =>
      throw Exception('simulated failure');

  @override
  Future<Map<ExerciseType, double>> averageElapsedMsByType(String playerId) =>
      throw Exception('simulated failure');

  @override
  Future<List<PersistedSession>> sessionsSince(
    String playerId,
    DateTime since,
  ) => throw Exception('simulated failure');
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // Levels for the default selection (addition, subtraction): Start plays
  // a game. Without them it plays a type placement instead (Phase 3a
  // commit 7; tested on its own below).
  final sharedRepository = InMemorySessionRepository();
  setUpAll(
    () => sharedRepository.replaceLevelCache('test-player', {
      for (final type in [ExerciseType.addition, ExerciseType.subtraction])
        type: LevelCacheEntry(
          level: Level.whole(5),
          sessionsPlayed: 4,
          updatedAt: DateTime.utc(2026, 11, 1),
        ),
    }),
  );
  final testEnvironment = AppEnvironment(
    repository: sharedRepository,
    playerId: 'test-player',
    accountRepository: FakeAccountRepository(),
    profileRepository: FakeProfileRepository(),
  );

  /// The app up to the type selection: `AuthGate` and `PlayTab` resolve
  /// their local reads, then a new player skips the placement offer.
  Future<void> openPlay(WidgetTester tester, AppEnvironment environment) async {
    await tester.pumpWidget(MathTrainerApp(environment: environment));
    await tester.pumpAndSettle();
    if (find.text('Skip').evaluate().isNotEmpty) {
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
    }
  }

  /// Home's Basics Play: the setup page (Redesign phase).
  Future<void> openBasicsSetup(WidgetTester tester) async {
    await tester.tap(find.byKey(playButtonKey(ExerciseFamily.basics)));
    await tester.pumpAndSettle();
  }

  Future<void> tapOperation(WidgetTester tester, String label) async {
    await tester.tap(find.bySemanticsLabel(RegExp('^$label, level')));
    await tester.pump();
  }

  // Advances time just enough for the standard MaterialPageRoute transition
  // to settle, without waiting for the rest (SessionScreen's timer runs 5 s
  // per question: a pumpAndSettle() here would never converge while a new
  // question restarts the animation).
  Future<void> settlePageTransition(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('shows the home screen', (WidgetTester tester) async {
    await openPlay(tester, testEnvironment);

    expect(find.text('Basics'), findsOneWidget);
  });

  testWidgets('starting a session pushes the keypad full screen', (
    WidgetTester tester,
  ) async {
    await openPlay(tester, testEnvironment);

    await openBasicsSetup(tester);
    await tester.tap(find.text('Start'));
    await settlePageTransition(tester);

    expect(find.text('7'), findsOneWidget);
    expect(find.byKey(keypadKeyKey('submit')), findsOneWidget);
    expect(find.byIcon(Icons.backspace_outlined), findsOneWidget);
  });

  testWidgets('no operation selected: the row Play is inert', (
    WidgetTester tester,
  ) async {
    await openPlay(tester, testEnvironment);

    // Untick the 2 types selected by default (step 4.1, commit A).
    for (final label in ['Addition', 'Subtraction']) {
      await tapOperation(tester, label);
    }

    await tester.tap(find.byKey(playButtonKey(ExerciseFamily.basics)));
    await tester.pump();

    // Still on Home: the dimmed button triggered nothing.
    expect(find.text('Basics'), findsOneWidget);
    expect(find.text('Start'), findsNothing);
  });

  testWidgets('a single selected type starts a single-type session', (
    WidgetTester tester,
  ) async {
    await openPlay(tester, testEnvironment);

    await tapOperation(tester, 'Subtraction');
    await openBasicsSetup(tester);
    await tester.tap(find.text('Start'));
    await settlePageTransition(tester);

    expect(find.byKey(keypadKeyKey('submit')), findsOneWidget);
    // Addition alone, 10 questions (the default setup).
    expect(find.text('1 / 10'), findsOneWidget);
  });

  testWidgets(
    'the back gesture during a session asks for confirmation before interrupting (step 5, commit A)',
    (WidgetTester tester) async {
      await openPlay(tester, testEnvironment);

      await openBasicsSetup(tester);
      await tester.tap(find.text('Start'));
      await settlePageTransition(tester);
      expect(find.byKey(keypadKeyKey('submit')), findsOneWidget);

      // No visible back button (`doc/design.md`: the session screen carries
      // no navigation): trigger the pop attempt as the system gesture would,
      // through the Navigator holding the pushed route.
      // `pumpAndSettle()` is banned here (see `settlePageTransition`): the
      // question timer keeps running while the dialog is open, and would
      // advance virtual time up to the timeout.
      Future<void> attemptPop() async {
        final context = tester.element(find.byType(SessionScreen));
        Navigator.of(context).maybePop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
      }

      await attemptPop();
      expect(find.text('Quit the game?'), findsOneWidget);

      // Cancel: the dialog closes, the session goes on without losing anything.
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Quit the game?'), findsNothing);
      expect(find.byKey(keypadKeyKey('submit')), findsOneWidget);

      // New attempt, confirmed this time: the session is interrupted.
      await attemptPop();
      await tester.tap(find.text('Quit'));
      await settlePageTransition(tester);

      expect(find.text('Session interrupted'), findsOneWidget);
    },
  );

  /// 2 types by default, 10 questions each (the default setup): 20
  /// questions. The loop bound (30) is a safety margin, not the real count.
  /// Type '1' then submit, without a pump in between to avoid any collision
  /// with the '1' that would then appear in the displayed answer. A wrong
  /// answer shows its correction for `defaultCorrectionDelay` (Phase 0,
  /// commit 9): let it elapse before the next question.
  Future<void> playToCompletion(WidgetTester tester) async {
    for (
      var i = 0;
      i < 30 && find.text('Session complete').evaluate().isEmpty;
      i++
    ) {
      await tester.tap(find.byKey(keypadKeyKey('1')));
      await tester.tap(find.byKey(keypadKeyKey('submit')));
      await tester.pump();
      await tester.pump(SessionController.defaultCorrectionDelay);
    }
    expect(find.text('Session complete'), findsOneWidget);
  }

  testWidgets('"Home" after a session goes back to Home', (
    WidgetTester tester,
  ) async {
    await openPlay(tester, testEnvironment);

    await openBasicsSetup(tester);
    await tester.tap(find.text('Start'));
    await settlePageTransition(tester);
    await playToCompletion(tester);

    await tester.tap(find.text('Home'));
    await settlePageTransition(tester);

    // Home, not the setup page: the levels are what moved.
    expect(find.text('Basics'), findsOneWidget);
  });

  testWidgets(
    'a first game on never-played types is a short placement, then the '
    "Play screen's overall level is re-read (Phase 3a commit 7)",
    (WidgetTester tester) async {
      // Fresh environment: the shared one has levels, this test needs a
      // player without history.
      final environment = AppEnvironment(
        repository: InMemorySessionRepository(),
        playerId: 'test-player',
        accountRepository: FakeAccountRepository(),
        profileRepository: FakeProfileRepository(),
      );
      await openPlay(tester, environment);
      await openBasicsSetup(tester);
      await tester.tap(find.text('Start'));
      await settlePageTransition(tester);
      expect(find.text('1 / 10'), findsOneWidget);
      for (
        var i = 0;
        i < 20 && find.text('Your starting levels').evaluate().isEmpty;
        i++
      ) {
        await tester.tap(find.byKey(keypadKeyKey('1')));
        await tester.tap(find.byKey(keypadKeyKey('submit')));
        await tester.pump();
        await tester.pump(SessionController.defaultCorrectionDelay);
      }
      expect(find.text('Your starting levels'), findsOneWidget);
      expect(find.textContaining('Addition — level'), findsOneWidget);
      expect(find.textContaining('Subtraction — level'), findsOneWidget);

      // Play again and Home, like every result (Redesign close-out).
      expect(find.text('Play again'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(ResultScreen),
          matching: find.text('Home'),
        ),
      );
      await settlePageTransition(tester);
      await tester.pumpAndSettle();

      expect(find.text('Basics'), findsOneWidget);
    },
  );

  testWidgets(
    '"Play again" restarts immediately without going back through the selection',
    (WidgetTester tester) async {
      await openPlay(tester, testEnvironment);

      await openBasicsSetup(tester);
      await tester.tap(find.text('Start'));
      await settlePageTransition(tester);
      await playToCompletion(tester);

      await tester.tap(find.text('Play again'));
      await settlePageTransition(tester);

      // Straight back on the keypad, not on Home.
      expect(find.text('Basics'), findsNothing);
      expect(find.text('1 / 20'), findsOneWidget);
      expect(find.byKey(keypadKeyKey('submit')), findsOneWidget);
    },
  );

  testWidgets(
    "the tab bar switches to Profile without losing Play's selection",
    (WidgetTester tester) async {
      // The identity block at the top of Profile (step 6, slice 2) pushes
      // "Not played" out of the default test window.
      tester.view.physicalSize = const Size(412, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await openPlay(tester, testEnvironment);

      await tapOperation(tester, 'Multiplication');

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.text('Addition'), findsOneWidget);
      expect(find.text('Not played'), findsWidgets);

      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Play'),
        ),
      );
      await tester.pumpAndSettle();

      // IndexedStack: the Play tab keeps its state, Multiplication stays ticked.
      final button = tester.widget<OperationButton>(
        find.byWidgetPredicate(
          (w) => w is OperationButton && w.type == ExerciseType.multiplication,
        ),
      );
      expect(button.selected, isTrue);
    },
  );

  testWidgets(
    'a repository failing at start shows a message and lets the player retry',
    (WidgetTester tester) async {
      final failingEnvironment = AppEnvironment(
        repository: _ThrowingSessionRepository(),
        playerId: 'test-player',
        accountRepository: FakeAccountRepository(),
        profileRepository: FakeProfileRepository(),
      );
      await openPlay(tester, failingEnvironment);

      await openBasicsSetup(tester);
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();

      expect(find.text('Could not start'), findsOneWidget);
      // The button is active again: it is the retry action.
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );

      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();

      // Still blocked (same repository), still the same message, no crash.
      expect(find.text('Could not start'), findsOneWidget);
    },
  );

  testWidgets(
    'the Dark mode switch on Profile toggles the theme and persists it',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(412, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      Future<Brightness> openProfile() async {
        await openPlay(tester, testEnvironment);
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text('Profile'),
          ),
        );
        await tester.pumpAndSettle();
        return Theme.of(tester.element(find.text('Settings'))).brightness;
      }

      final initial = await openProfile();
      await tester.tap(find.widgetWithText(SwitchListTile, 'Dark mode'));
      await tester.pumpAndSettle();
      final toggled = Theme.of(
        tester.element(find.text('Settings')),
      ).brightness;
      expect(toggled, isNot(initial));

      // A new instance pointing at the same environment finds the choice.
      expect(await openProfile(), toggled);
    },
  );
}
