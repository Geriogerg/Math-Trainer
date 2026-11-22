import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:math_trainer/composition_root.dart';
import 'package:math_core/leveling/level.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/persistence/in_memory_session_repository.dart';
import 'package:math_core/persistence/level_cache_entry.dart';
import 'package:math_core/persistence/persisted_answer.dart';
import 'package:math_core/persistence/persisted_session.dart';
import 'package:math_core/persistence/type_selection_store.dart';
import 'package:math_trainer/presentation/screens/play_tab.dart';
import 'package:math_trainer/presentation/theme/app_theme.dart';

import '../fake_account_repository.dart';
import '../fake_placement_skip_store.dart';
import '../fake_profile_repository.dart';
import 'kit_finders.dart';

/// In-memory store — no shared test infrastructure for a single class of a
/// few lines (project convention).
class _FakeTypeSelectionStore implements TypeSelectionStore {
  Set<ExerciseType>? stored;

  @override
  Future<Set<ExerciseType>?> load() async => stored;

  @override
  Future<void> save(Set<ExerciseType> types) async => stored = types;
}

void main() {
  /// [skipPlacement]: a player with no session first sees the placement
  /// offer; the selection tests go past it like the player would.
  Future<void> pumpPlayTab(
    WidgetTester tester,
    AppEnvironment environment, {
    bool skipPlacement = true,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(body: PlayTab(environment: environment)),
      ),
    );
    await tester.pumpAndSettle();
    if (skipPlacement && find.text('Skip').evaluate().isNotEmpty) {
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
    }
  }

  AppEnvironment environmentWith(InMemorySessionRepository repository) =>
      AppEnvironment(
        repository: repository,
        playerId: 'test-player',
        accountRepository: FakeAccountRepository(),
        profileRepository: FakeProfileRepository(),
        typeSelectionStore: _FakeTypeSelectionStore(),
        placementSkipStore: FakePlacementSkipStore(),
      );

  group('placement offer', () {
    testWidgets('a player with no session is offered the placement first', (
      tester,
    ) async {
      await pumpPlayTab(
        tester,
        environmentWith(InMemorySessionRepository()),
        skipPlacement: false,
      );

      expect(find.text('Find your level'), findsOneWidget);
      expect(find.text('Find my level'), findsOneWidget);
      expect(find.byType(FilterChip), findsNothing);
    });

    testWidgets('Skip goes to the type selection', (tester) async {
      await pumpPlayTab(
        tester,
        environmentWith(InMemorySessionRepository()),
        skipPlacement: false,
      );

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(find.byType(FilterChip), findsNWidgets(7));
    });

    PersistedSession sessionOf(String id) => PersistedSession(
      id: id,
      playerId: 'test-player',
      seed: 1,
      enabledTypes: const {ExerciseType.addition},
      exerciseCount: 1,
      totalScore: 0,
      levels: {ExerciseType.addition: Level.floor},
      createdAt: DateTime.utc(2026, 11, 1),
    );

    testWidgets('an interrupted session does not count: still offered', (
      tester,
    ) async {
      final repository = InMemorySessionRepository();
      await repository.recordSession(
        session: sessionOf('interrupted'),
        answers: const [],
        levelUpdates: const {},
      );

      await pumpPlayTab(
        tester,
        environmentWith(repository),
        skipPlacement: false,
      );

      expect(find.text('Find my level'), findsOneWidget);
    });

    testWidgets('a completed session means no offer', (tester) async {
      final repository = InMemorySessionRepository();
      await repository.recordSession(
        session: sessionOf('completed'),
        answers: [
          PersistedAnswer(
            id: 'a1',
            sessionId: 'completed',
            exerciseType: 'arithmetic',
            operationType: 'addition',
            operands: const {'left': 1, 'right': 1},
            submittedValue: 2,
            isCorrect: true,
            elapsedMs: 900,
            createdAt: DateTime.utc(2026, 11, 1),
          ),
        ],
        levelUpdates: const {},
      );

      await pumpPlayTab(
        tester,
        environmentWith(repository),
        skipPlacement: false,
      );

      expect(find.text('Find my level'), findsNothing);
      expect(find.byType(FilterChip), findsNWidgets(7));
    });

    testWidgets('a skip is remembered for this player', (tester) async {
      final skips = FakePlacementSkipStore();
      AppEnvironment environment() => AppEnvironment(
        repository: InMemorySessionRepository(),
        playerId: 'test-player',
        accountRepository: FakeAccountRepository(),
        profileRepository: FakeProfileRepository(),
        typeSelectionStore: _FakeTypeSelectionStore(),
        placementSkipStore: skips,
      );
      await pumpPlayTab(tester, environment(), skipPlacement: false);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(skips.skipped, {'test-player'});

      // A new launch: straight to the type selection.
      await tester.pumpWidget(const SizedBox());
      await pumpPlayTab(tester, environment(), skipPlacement: false);
      expect(find.text('Find my level'), findsNothing);
      expect(find.byType(FilterChip), findsNWidgets(7));
    });

    testWidgets('nothing is drawn before the startup read resolves', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: Scaffold(
            body: PlayTab(
              environment: environmentWith(InMemorySessionRepository()),
            ),
          ),
        ),
      );
      // First frame: neither the selection nor the offer (no flash).
      expect(find.byType(FilterChip), findsNothing);
      expect(find.text('Find my level'), findsNothing);
      await tester.pumpAndSettle();
      expect(find.text('Find my level'), findsOneWidget);
    });

    testWidgets('Find my level starts the placement session', (tester) async {
      await pumpPlayTab(
        tester,
        environmentWith(InMemorySessionRepository()),
        skipPlacement: false,
      );

      await tester.tap(find.text('Find my level'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('finding your level'), findsOneWidget);
      expect(find.text('1 / 20'), findsOneWidget);
    });
  });

  testWidgets('an already saved selection replaces the default at start', (
    tester,
  ) async {
    final store = _FakeTypeSelectionStore()
      ..stored = {ExerciseType.multiplication, ExerciseType.division};
    final environment = AppEnvironment(
      repository: InMemorySessionRepository(),
      playerId: 'test-player',
      accountRepository: FakeAccountRepository(),
      profileRepository: FakeProfileRepository(),
      typeSelectionStore: store,
      placementSkipStore: FakePlacementSkipStore(),
    );

    await pumpPlayTab(tester, environment);

    FilterChip chipFor(String label) => tester.widget<FilterChip>(
      find.ancestor(of: find.text(label), matching: find.byType(FilterChip)),
    );

    expect(chipFor('Multiplication').selected, isTrue);
    expect(chipFor('Division').selected, isTrue);
    expect(chipFor('Addition').selected, isFalse);
    expect(chipFor('Subtraction').selected, isFalse);
  });

  testWidgets('without history, a missing saved selection keeps the default', (
    tester,
  ) async {
    final environment = AppEnvironment(
      repository: InMemorySessionRepository(),
      playerId: 'test-player',
      accountRepository: FakeAccountRepository(),
      profileRepository: FakeProfileRepository(),
      typeSelectionStore: _FakeTypeSelectionStore(),
      placementSkipStore: FakePlacementSkipStore(),
    );

    await pumpPlayTab(tester, environment);

    FilterChip chipFor(String label) => tester.widget<FilterChip>(
      find.ancestor(of: find.text(label), matching: find.byType(FilterChip)),
    );

    expect(chipFor('Addition').selected, isTrue);
    expect(chipFor('Subtraction').selected, isTrue);
  });

  testWidgets('changing a chip persists the new selection in the store', (
    tester,
  ) async {
    final store = _FakeTypeSelectionStore();
    final environment = AppEnvironment(
      repository: InMemorySessionRepository(),
      playerId: 'test-player',
      accountRepository: FakeAccountRepository(),
      profileRepository: FakeProfileRepository(),
      typeSelectionStore: store,
      placementSkipStore: FakePlacementSkipStore(),
    );

    await pumpPlayTab(tester, environment);
    await tester.tap(find.text('Multiplication'));
    await tester.pumpAndSettle();

    expect(store.stored, {
      ExerciseType.addition,
      ExerciseType.subtraction,
      ExerciseType.multiplication,
    });

    // A second instance pointing at the same store finds the change.
    final secondEnvironment = AppEnvironment(
      repository: InMemorySessionRepository(),
      playerId: 'test-player',
      accountRepository: FakeAccountRepository(),
      profileRepository: FakeProfileRepository(),
      typeSelectionStore: store,
      placementSkipStore: FakePlacementSkipStore(),
    );
    await pumpPlayTab(tester, secondEnvironment);

    final chip = tester.widget<FilterChip>(
      find.ancestor(
        of: find.text('Multiplication'),
        matching: find.byType(FilterChip),
      ),
    );
    expect(chip.selected, isTrue);
  });

  testWidgets('without history: welcome sentence, no overall level', (
    tester,
  ) async {
    final environment = AppEnvironment(
      repository: InMemorySessionRepository(),
      playerId: 'test-player',
      accountRepository: FakeAccountRepository(),
      profileRepository: FakeProfileRepository(),
      typeSelectionStore: _FakeTypeSelectionStore(),
      placementSkipStore: FakePlacementSkipStore(),
    );

    await pumpPlayTab(tester, environment);

    expect(find.text('Difficulty adapts to your answers.'), findsOneWidget);
    expect(find.textContaining('Main level'), findsNothing);
  });

  testWidgets('with history: overall level shown, not the welcome sentence', (
    tester,
  ) async {
    final repository = InMemorySessionRepository();
    await repository.recordSession(
      session: PersistedSession(
        id: 'session-1',
        playerId: 'test-player',
        seed: 1,
        enabledTypes: const {ExerciseType.addition},
        exerciseCount: 4,
        totalScore: 40,
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
      typeSelectionStore: _FakeTypeSelectionStore(),
      placementSkipStore: FakePlacementSkipStore(),
    );

    await pumpPlayTab(tester, environment);

    // Main level: (42 + 3 × 1 floor for the basics not played) / 4 ≈ 11.
    expect(findLevelBadge(11), findsOneWidget);
    expect(find.text('Difficulty adapts to your answers.'), findsNothing);
  });
}
