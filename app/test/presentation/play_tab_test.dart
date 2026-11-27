import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:math_trainer/composition_root.dart';
import 'package:math_trainer/core/state/hints.dart';
import 'package:math_core/challenges/chain.dart';
import 'package:math_core/challenges/tables.dart';
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
    FakeTablesStore? tables,
    FakeHintsStore? hints,
  }) => AppEnvironment(
    repository: repository,
    playerId: 'test-player',
    accountRepository: FakeAccountRepository(),
    profileRepository: FakeProfileRepository(),
    typeSelectionStore: selection ?? FakeTypeSelectionStore(),
    gameSetupStore: setup ?? FakeGameSetupStore(),
    chainSetupStore: chainSetup ?? FakeChainSetupStore(),
    tablesStore: tables ?? FakeTablesStore(),
    hints: hints,
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
      // One line under each control (Phase 6b commit 4, review M16: the
      // Redesign's "labels only" relaxed for strangers).
      for (final line in [
        'Your level: the mean of + − × ÷.',
        'Tap the operations to play. Each has its own level, 0–100.',
        'Reach a target with the numbers given.',
        'Times tables, at your pace. Never ranked.',
      ]) {
        expect(find.text(line), findsOneWidget, reason: line);
      }
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

  group('first run (Phase 6b commit 4, review M16)', () {
    testWidgets('the card says how levels move, until "Got it"', (
      tester,
    ) async {
      final hints = FakeHintsStore();
      final repository = await _playedRepository();
      await pumpPlayTab(tester, environmentWith(repository, hints: hints));
      expect(find.byKey(firstRunCardKey), findsOneWidget);
      expect(find.text('How levels work'), findsOneWidget);
      expect(
        find.text('Training games and Practice never move levels.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();
      expect(find.byKey(firstRunCardKey), findsNothing);
      expect(hints.seenHints, {Hint.firstRun});

      // Seen: never again.
      await tester.pumpWidget(const SizedBox());
      await pumpPlayTab(tester, environmentWith(repository, hints: hints));
      expect(find.byKey(firstRunCardKey), findsNothing);
    });

    testWidgets('Chain operations: its rules on the first open only', (
      tester,
    ) async {
      final hints = FakeHintsStore({Hint.firstRun});
      await pumpPlayTab(
        tester,
        environmentWith(await _playedRepository(), hints: hints),
      );
      await tester.tap(find.text('Chain operations'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Keep the result in your head'), findsOne);
      expect(find.text('Seconds'), findsNothing);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('Seconds'), findsOneWidget);
      expect(hints.seenHints, contains(Hint.chainRules));

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chain operations'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Keep the result in your head'), findsNothing);
      expect(find.text('Seconds'), findsOneWidget);
    });

    testWidgets('Get the count: its rules on the first open', (tester) async {
      final hints = FakeHintsStore({Hint.firstRun});
      await pumpPlayTab(
        tester,
        environmentWith(await _playedRepository(), hints: hints),
      );
      await tester.ensureVisible(find.text('Get the count'));
      await tester.tap(find.text('Get the count'));
      await tester.pumpAndSettle();
      expect(find.textContaining('each number once at most'), findsOneWidget);
      expect(hints.seenHints, isNot(contains(Hint.countRules)));
      await tester.tap(find.text('OK'));
      await tester.pump();
      expect(hints.seenHints, contains(Hint.countRules));
    });

    testWidgets('the setup says what each choice does', (tester) async {
      await pumpPlayTab(
        tester,
        environmentWith(
          await _playedRepository(),
          selection: FakeTypeSelectionStore({
            ExerciseType.addition,
            ExerciseType.multiplication,
          }),
          setup: FakeGameSetupStore(GameSetup(questionsPerOperation: 10)),
        ),
      );
      await tester.tap(find.byKey(playButtonKey(ExerciseFamily.basics)));
      await tester.pumpAndSettle();
      expect(find.text('10 per operation: 20 questions in all.'), findsOne);
      expect(
        find.text(
          'Moves your levels. Quitting counts the questions left as missed.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Training'));
      await tester.pumpAndSettle();
      expect(
        find.text('A fixed difficulty. Your levels never move.'),
        findsOne,
      );
      expect(find.text('Easy: level 10 · Medium: 40 · Hard: 70.'), findsOne);
    });
  });

  group('Tables mode (doc/levels.md section 7)', () {
    Future<FakeTablesStore> openTables(
      WidgetTester tester, {
      TablesSetup? stored,
    }) async {
      final store = FakeTablesStore(setup: stored);
      await pumpPlayTab(
        tester,
        environmentWith(await _playedRepository(), tables: store),
      );
      await tester.scrollUntilVisible(find.text('Tables'), 100);
      await tester.tap(find.text('Tables'));
      await tester.pumpAndSettle();
      return store;
    }

    testWidgets('its card opens its setup page, labels only; back returns', (
      tester,
    ) async {
      await openTables(tester);
      for (final label in ['From', 'To', 'Multipliers', 'Questions', 'Start']) {
        expect(find.text(label), findsWidgets, reason: label);
      }
      expect(find.text('1–10'), findsOneWidget);
      expect(find.text('1–20'), findsOneWidget);
      expect(find.textContaining('.'), findsNothing);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Basics'), findsOneWidget);
    });

    testWidgets('the range moves, the first table pushing the last; '
        'remembered', (tester) async {
      final store = await openTables(
        tester,
        stored: TablesSetup(firstTable: 12, lastTable: 12),
      );
      expect(find.bySemanticsLabel('From 12'), findsOneWidget);
      await tester.tap(find.byTooltip('From +1'));
      await tester.pumpAndSettle();
      expect(store.setup, TablesSetup(firstTable: 13, lastTable: 13));
      await tester.tap(find.text('1–20'));
      await tester.tap(find.text('50'));
      await tester.pumpAndSettle();
      expect(
        store.setup,
        TablesSetup(
          firstTable: 13,
          lastTable: 13,
          maxMultiplier: 20,
          questions: 50,
        ),
      );
    });

    testWidgets('the ends of 1–50 disable their buttons', (tester) async {
      await openTables(
        tester,
        stored: TablesSetup(firstTable: 1, lastTable: 50),
      );
      IconButton button(String tooltip) => tester.widget<IconButton>(
        find.ancestor(
          of: find.byTooltip(tooltip),
          matching: find.byType(IconButton),
        ),
      );
      expect(button('From −1').onPressed, isNull);
      expect(button('To +1').onPressed, isNull);
    });
  });

  testWidgets('the Tips card opens the Tips page; back returns '
      '(doc/levels.md section 8)', (tester) async {
    await pumpPlayTab(tester, environmentWith(await _playedRepository()));
    await tester.scrollUntilVisible(find.text('Tips'), 100);
    await tester.tap(find.text('Tips'));
    await tester.pumpAndSettle();
    expect(find.text('Make 10 first, then add what is left.'), findsOneWidget);
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

  group('Weak spots card (Phase 4)', () {
    testWidgets('a new player: none due, inert', (tester) async {
      await pumpPlayTab(tester, environmentWith(InMemorySessionRepository()));
      expect(find.text('Practice'), findsOneWidget);
      expect(find.text('Weak spots'), findsOneWidget);
      expect(find.text('None due'), findsOneWidget);
      final card = tester.widget<AppCard>(find.byKey(weakSpotsCardKey));
      expect(card.onTap, isNull);
    });

    testWidgets('a missed fact: one due, the card opens a game', (
      tester,
    ) async {
      final repository = InMemorySessionRepository();
      final missed = PersistedSession(
        id: 'missed',
        playerId: 'test-player',
        seed: 1,
        enabledTypes: const {ExerciseType.multiplication},
        exerciseCount: 4,
        totalScore: 0,
        levels: {ExerciseType.multiplication: Level.zero},
        createdAt: DateTime.utc(2026, 11, 1),
      );
      await repository.recordSession(
        session: missed,
        answers: [
          PersistedAnswer(
            id: 'm-a',
            sessionId: 'missed',
            exerciseType: 'arithmetic',
            operationType: 'multiplication',
            operands: const {'operandA': 3, 'operandB': 4},
            submittedValue: 11,
            isCorrect: false,
            elapsedMs: 3000,
            createdAt: DateTime.utc(2026, 11, 1),
          ),
        ],
        levelUpdates: const {},
      );
      await pumpPlayTab(tester, environmentWith(repository));
      expect(find.text('1 due'), findsOneWidget);
      final card = tester.widget<AppCard>(find.byKey(weakSpotsCardKey));
      expect(card.onTap, isNotNull);
    });
  });
}
