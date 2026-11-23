import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:math_trainer/composition_root.dart';
import 'package:math_core/challenges/chain.dart';
import 'package:math_core/leveling/level.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/models/game_setup.dart';
import 'package:math_core/persistence/in_memory_session_repository.dart';
import 'package:math_core/persistence/level_cache_entry.dart';
import 'package:math_core/persistence/persisted_answer.dart';
import 'package:math_core/persistence/persisted_session.dart';
import 'package:math_trainer/presentation/kit/kit.dart';
import 'package:math_trainer/presentation/screens/play_tab.dart';
import 'package:math_trainer/presentation/theme/app_theme.dart';

import '../fake_account_repository.dart';
import '../fake_profile_repository.dart';
import '../fake_stores.dart';
import 'kit_finders.dart';

PersistedSession _session(String id) => PersistedSession(
  id: id,
  playerId: 'test-player',
  seed: 1,
  enabledTypes: const {ExerciseType.addition},
  exerciseCount: 1,
  totalScore: 0,
  levels: {ExerciseType.addition: Level.zero},
  createdAt: DateTime.utc(2026, 11, 1),
);

PersistedAnswer _answer(String sessionId) => PersistedAnswer(
  id: '$sessionId-a',
  sessionId: sessionId,
  exerciseType: 'arithmetic',
  operationType: 'addition',
  operands: const {'operandA': 1, 'operandB': 1},
  submittedValue: 2,
  isCorrect: true,
  elapsedMs: 900,
  createdAt: DateTime.utc(2026, 11, 1),
);

/// A player with one completed game, addition at [level].
Future<InMemorySessionRepository> _playedRepository({int level = 42}) async {
  final repository = InMemorySessionRepository();
  await repository.recordSession(
    session: _session('played'),
    answers: [_answer('played')],
    levelUpdates: {
      ExerciseType.addition: LevelCacheEntry(
        level: Level.whole(level),
        sessionsPlayed: 1,
        updatedAt: DateTime.utc(2026, 11, 1),
      ),
    },
  );
  return repository;
}

FilledButton _playButton(WidgetTester tester, ExerciseFamily family) =>
    tester.widget<FilledButton>(
      find.descendant(
        of: find.byKey(playButtonKey(family)),
        matching: find.byType(FilledButton),
      ),
    );

void main() {
  Future<void> pumpPlayTab(
    WidgetTester tester,
    AppEnvironment environment,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(body: PlayTab(environment: environment)),
      ),
    );
    await tester.pumpAndSettle();
  }

  AppEnvironment environmentWith(
    InMemorySessionRepository repository, {
    FakeTypeSelectionStore? selection,
    FakeGameSetupStore? setup,
    FakeChainSetupStore? chainSetup,
  }) => AppEnvironment(
    repository: repository,
    playerId: 'test-player',
    accountRepository: FakeAccountRepository(),
    profileRepository: FakeProfileRepository(),
    typeSelectionStore: selection ?? FakeTypeSelectionStore(),
    gameSetupStore: setup ?? FakeGameSetupStore(),
    chainSetupStore: chainSetup ?? FakeChainSetupStore(),
  );

  testWidgets('a new player lands on Home, every level at 0 — no placement '
      '(doc/levels.md)', (tester) async {
    await pumpPlayTab(tester, environmentWith(InMemorySessionRepository()));
    expect(find.text('Basics'), findsOneWidget);
    expect(find.text('Find your level'), findsNothing);
    expect(findLevelBadge(0), findsWidgets);
  });

  group('Home', () {
    testWidgets('labels, the main level, a level on every operation', (
      tester,
    ) async {
      await pumpPlayTab(tester, environmentWith(await _playedRepository()));

      for (final label in ['Play', 'Basics', 'Advanced', 'Challenges']) {
        expect(find.text(label), findsWidgets, reason: label);
      }
      expect(find.text('Get the count'), findsOneWidget);
      expect(find.text('Chain operations'), findsOneWidget);
      // Main level: (42 + 3 × 0) / 4 = 10.5, shown 11.
      expect(findLevelBadge(11), findsOneWidget);
      expect(find.byType(OperationButton), findsNWidgets(8));
      expect(find.text('42'), findsOneWidget);
      // Never played: shown at 0, where everyone starts.
      expect(find.text('0'), findsNWidgets(7));
      // No explanatory sentence: labels only.
      expect(find.textContaining('.'), findsNothing);
      // Each row's Play says which row to screen readers (and to the
      // smoke test, tool/smoke/preview_smoke.mjs).
      expect(find.bySemanticsLabel('Play Basics'), findsOneWidget);
      expect(find.bySemanticsLabel('Play Advanced'), findsOneWidget);
    });

    testWidgets('a tap toggles an operation and is remembered', (tester) async {
      final selection = FakeTypeSelectionStore();
      await pumpPlayTab(
        tester,
        environmentWith(await _playedRepository(), selection: selection),
      );
      await tester.tap(find.bySemanticsLabel(RegExp('^Multiplication, level')));
      await tester.pumpAndSettle();
      expect(selection.stored, {
        ExerciseType.addition,
        ExerciseType.subtraction,
        ExerciseType.multiplication,
      });
    });

    testWidgets('a row\'s Play is inert until the row has a selection', (
      tester,
    ) async {
      await pumpPlayTab(
        tester,
        environmentWith(
          await _playedRepository(),
          selection: FakeTypeSelectionStore({ExerciseType.addition}),
        ),
      );
      expect(_playButton(tester, ExerciseFamily.basics).onPressed, isNotNull);
      expect(_playButton(tester, ExerciseFamily.advanced).onPressed, isNull);

      await tester.tap(find.bySemanticsLabel(RegExp('^Integrals, level')));
      await tester.pumpAndSettle();
      expect(_playButton(tester, ExerciseFamily.advanced).onPressed, isNotNull);
    });
  });

  testWidgets('the chain card opens its setup page; back returns', (
    tester,
  ) async {
    await pumpPlayTab(tester, environmentWith(await _playedRepository()));
    await tester.tap(find.text('Chain operations'));
    await tester.pumpAndSettle();
    for (final label in ['Seconds', 'Operations', 'Start']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    for (final n in ['1', '2', '3', '5', '10', '15']) {
      expect(find.text(n), findsOneWidget, reason: n);
    }
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Basics'), findsOneWidget);
  });

  testWidgets('the chain setup is remembered (Redesign close-out)', (
    tester,
  ) async {
    final store = FakeChainSetupStore(
      ChainSetup(secondsPerScreen: 3, operations: 15),
    );
    await pumpPlayTab(
      tester,
      environmentWith(await _playedRepository(), chainSetup: store),
    );
    await tester.tap(find.text('Chain operations'));
    await tester.pumpAndSettle();
    Matcher selected(bool value) => isSemantics(isSelected: value);
    expect(tester.getSemantics(find.text('3')), selected(true));
    expect(tester.getSemantics(find.text('15')), selected(true));
    expect(tester.getSemantics(find.text('2')), selected(false));

    await tester.tap(find.text('1'));
    await tester.tap(find.text('5'));
    await tester.pumpAndSettle();
    expect(store.stored, ChainSetup(secondsPerScreen: 1, operations: 5));
  });

  group('setup page', () {
    Future<FakeGameSetupStore> openBasicsSetup(
      WidgetTester tester, {
      GameSetup? stored,
    }) async {
      final setup = FakeGameSetupStore(stored);
      await pumpPlayTab(
        tester,
        environmentWith(
          await _playedRepository(),
          selection: FakeTypeSelectionStore({
            ExerciseType.addition,
            ExerciseType.multiplication,
            ExerciseType.power,
          }),
          setup: setup,
        ),
      );
      await tester.tap(find.byKey(playButtonKey(ExerciseFamily.basics)));
      await tester.pumpAndSettle();
      return setup;
    }

    testWidgets('the row\'s operators as the title, then the choices', (
      tester,
    ) async {
      await openBasicsSetup(tester);
      // Only the basics of the selection.
      expect(find.text('+ ×'), findsOneWidget);
      for (final label in ['Questions', 'Mode', 'Training', 'Levelling']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      for (final n in ['4', '5', '10', '20']) {
        expect(find.text(n), findsOneWidget);
      }
      // Levelling by default: no difficulty row.
      expect(find.text('Medium'), findsNothing);
      expect(find.text('Start'), findsOneWidget);
    });

    testWidgets('the difficulty row appears in Training only; choices are '
        'remembered', (tester) async {
      final store = await openBasicsSetup(tester);
      await tester.tap(find.text('Training'));
      await tester.pumpAndSettle();
      expect(find.text('Easy'), findsOneWidget);
      await tester.tap(find.text('Hard'));
      await tester.tap(find.text('5'));
      await tester.pumpAndSettle();
      expect(
        store.stored,
        GameSetup(
          questionsPerOperation: 5,
          mode: GameMode.training,
          difficulty: TrainingDifficulty.hard,
        ),
      );
      await tester.tap(find.text('Levelling'));
      await tester.pumpAndSettle();
      expect(find.text('Easy'), findsNothing);
    });

    testWidgets('back returns to Home', (tester) async {
      await openBasicsSetup(tester);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Basics'), findsOneWidget);
    });

    testWidgets('Start plays the row\'s operations with the setup', (
      tester,
    ) async {
      await openBasicsSetup(
        tester,
        stored: GameSetup(questionsPerOperation: 4),
      );
      await tester.tap(find.text('Start'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      // Addition and multiplication, 4 each — a never-played operation
      // starts at 0, no placement first (`doc/levels.md`).
      expect(find.text('1 / 8'), findsOneWidget);
    });

    testWidgets('Training starts at once too', (tester) async {
      await openBasicsSetup(
        tester,
        stored: GameSetup(questionsPerOperation: 4, mode: GameMode.training),
      );
      await tester.tap(find.text('Start'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      // Addition and multiplication, 4 each.
      expect(find.text('1 / 8'), findsOneWidget);
    });
  });
}
