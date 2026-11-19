import 'package:math_trainer/core/domain/leveling/level.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:math_trainer/composition_root.dart';
import 'package:math_trainer/core/domain/models/exercise_type.dart';
import 'package:math_trainer/core/domain/persistence/in_memory_session_repository.dart';
import 'package:math_trainer/core/domain/persistence/level_cache_entry.dart';
import 'package:math_trainer/core/domain/persistence/persisted_session.dart';
import 'package:math_trainer/core/domain/persistence/type_selection_store.dart';
import 'package:math_trainer/presentation/screens/play_tab.dart';
import 'package:math_trainer/presentation/theme/app_theme.dart';

import '../fake_account_repository.dart';
import '../fake_profile_repository.dart';

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
  Future<void> pumpPlayTab(
    WidgetTester tester,
    AppEnvironment environment,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(body: PlayTab(environment: environment)),
      ),
    );
    await tester.pumpAndSettle();
  }

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
    );

    await pumpPlayTab(tester, environment);

    expect(find.text('Difficulty adapts to your answers.'), findsOneWidget);
    expect(find.textContaining('Overall level'), findsNothing);
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
    );

    await pumpPlayTab(tester, environment);

    // (42 + 6 × 1 floor for the 6 types not played) / 7 ≈ 6.86 → 7.
    expect(find.text('Overall level: 7'), findsOneWidget);
    expect(find.text('Difficulty adapts to your answers.'), findsNothing);
  });
}
