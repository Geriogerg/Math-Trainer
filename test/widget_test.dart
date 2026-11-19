import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:math_trainer/app.dart';
import 'package:math_trainer/presentation/screens/session_screen.dart';
import 'package:math_trainer/composition_root.dart';
import 'package:math_trainer/core/domain/persistence/level_cache_entry.dart';
import 'package:math_trainer/core/domain/models/exercise_type.dart';
import 'package:math_trainer/core/domain/persistence/in_memory_session_repository.dart';
import 'package:math_trainer/core/domain/persistence/persisted_answer.dart';
import 'package:math_trainer/core/domain/persistence/persisted_session.dart';
import 'package:math_trainer/core/domain/persistence/session_repository.dart';
import 'package:math_trainer/core/state/session_controller.dart';

import 'fake_account_repository.dart';
import 'fake_profile_repository.dart';

class _ThrowingSessionRepository implements SessionRepository {
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

  final testEnvironment = AppEnvironment(
    repository: InMemorySessionRepository(),
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

    expect(find.text('Math Trainer'), findsOneWidget);
  });

  testWidgets('starting a session pushes the keypad full screen', (
    WidgetTester tester,
  ) async {
    await openPlay(tester, testEnvironment);

    await tester.tap(find.text('Start'));
    await settlePageTransition(tester);

    expect(find.text('7'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.byIcon(Icons.backspace_outlined), findsOneWidget);
  });

  testWidgets('no type selected disables Start and explains why', (
    WidgetTester tester,
  ) async {
    await openPlay(tester, testEnvironment);

    // Untick the 2 types selected by default (step 4.1, commit A).
    for (final label in ['Addition', 'Subtraction']) {
      await tester.tap(find.text(label));
      await tester.pump();
    }

    expect(find.text('No type selected.'), findsOneWidget);

    await tester.tap(find.text('Start'));
    await tester.pump();

    // Still on the selection screen: the disabled button triggered nothing.
    expect(find.text('Math Trainer'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsNothing);
  });

  testWidgets('a single selected type starts a single-type session', (
    WidgetTester tester,
  ) async {
    await openPlay(tester, testEnvironment);

    await tester.tap(find.text('Subtraction'));
    await tester.pump();
    await tester.tap(find.text('Start'));
    await settlePageTransition(tester);

    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets(
    'the back gesture during a session asks for confirmation before interrupting (step 5, commit A)',
    (WidgetTester tester) async {
      await openPlay(tester, testEnvironment);

      await tester.tap(find.text('Start'));
      await settlePageTransition(tester);
      expect(find.byIcon(Icons.check), findsOneWidget);

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
      expect(find.byIcon(Icons.check), findsOneWidget);

      // New attempt, confirmed this time: the session is interrupted.
      await attemptPop();
      await tester.tap(find.text('Quit'));
      await settlePageTransition(tester);

      expect(find.text('Session interrupted'), findsOneWidget);
    },
  );

  /// 2 types by default, n_min=4 (step 4.2): sessionLengthFor(2, 4, 24) = 8
  /// questions. The loop bound (20) is a safety margin, not the real count.
  /// Type '1' then submit, without a pump in between to avoid any collision
  /// with the '1' that would then appear in the displayed answer. A wrong
  /// answer shows its correction for `defaultCorrectionDelay` (Phase 0,
  /// commit 9): let it elapse before the next question.
  Future<void> playToCompletion(WidgetTester tester) async {
    for (
      var i = 0;
      i < 20 && find.text('Session complete').evaluate().isEmpty;
      i++
    ) {
      await tester.tap(find.text('1'));
      await tester.tap(find.byIcon(Icons.check));
      await tester.pump();
      await tester.pump(SessionController.defaultCorrectionDelay);
    }
    expect(find.text('Session complete'), findsOneWidget);
  }

  testWidgets(
    '"New selection" after a session goes back to the selection screen',
    (WidgetTester tester) async {
      await openPlay(tester, testEnvironment);

      await tester.tap(find.text('Start'));
      await settlePageTransition(tester);
      await playToCompletion(tester);

      await tester.tap(find.text('New selection'));
      await settlePageTransition(tester);

      expect(find.text('Math Trainer'), findsOneWidget);
      expect(find.byType(FilterChip), findsWidgets);
    },
  );

  testWidgets(
    "the Play screen's overall level is re-read on return from a session",
    (WidgetTester tester) async {
      // Fresh environment: the shared one accumulates the history of the
      // other tests, and this test needs to start without history.
      final environment = AppEnvironment(
        repository: InMemorySessionRepository(),
        playerId: 'test-player',
        accountRepository: FakeAccountRepository(),
        profileRepository: FakeProfileRepository(),
      );
      await openPlay(tester, environment);
      expect(find.text('Difficulty adapts to your answers.'), findsOneWidget);

      await tester.tap(find.text('Start'));
      await settlePageTransition(tester);
      await playToCompletion(tester);
      await tester.tap(find.text('New selection'));
      await settlePageTransition(tester);

      expect(find.textContaining('Overall level'), findsOneWidget);
    },
  );

  testWidgets(
    '"Play again" restarts immediately without going back through the selection',
    (WidgetTester tester) async {
      await openPlay(tester, testEnvironment);

      await tester.tap(find.text('Start'));
      await settlePageTransition(tester);
      await playToCompletion(tester);

      await tester.tap(find.text('Play again'));
      await settlePageTransition(tester);

      // Straight back on the keypad, not on the selection screen: "1" is the
      // new first question, never the "Math Trainer" screen.
      expect(find.text('Math Trainer'), findsNothing);
      expect(find.text('1 / 8'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
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

      await tester.tap(find.text('Multiplication'));
      await tester.pump();

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.text('Addition'), findsOneWidget);
      expect(find.text('Not played'), findsWidgets);

      await tester.tap(find.text('Play'));
      await tester.pumpAndSettle();

      // IndexedStack: the Play tab keeps its state, Multiplication stays ticked.
      final chip = tester.widget<FilterChip>(
        find.ancestor(
          of: find.text('Multiplication'),
          matching: find.byType(FilterChip),
        ),
      );
      expect(chip.selected, isTrue);
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

      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();

      expect(find.text('Could not start the session.'), findsOneWidget);
      // The button is active again: it is the retry action.
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );

      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();

      // Still blocked (same repository), still the same message, no crash.
      expect(find.text('Could not start the session.'), findsOneWidget);
    },
  );

  testWidgets(
    'the day/night button toggles the theme and persists the choice',
    (WidgetTester tester) async {
      await openPlay(tester, testEnvironment);

      final initialBrightness = Theme.of(
        tester.element(find.text('Math Trainer')),
      ).brightness;

      await tester.tap(
        find.byIcon(
          initialBrightness == Brightness.dark
              ? Icons.light_mode_outlined
              : Icons.dark_mode_outlined,
        ),
      );
      await tester.pumpAndSettle();

      final toggledBrightness = Theme.of(
        tester.element(find.text('Math Trainer')),
      ).brightness;
      expect(toggledBrightness, isNot(initialBrightness));

      // A new instance pointing at the same environment finds the choice.
      await openPlay(tester, testEnvironment);

      final reloadedBrightness = Theme.of(
        tester.element(find.text('Math Trainer')),
      ).brightness;
      expect(reloadedBrightness, toggledBrightness);
    },
  );
}
