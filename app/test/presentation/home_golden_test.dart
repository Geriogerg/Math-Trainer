import 'package:flutter_test/flutter_test.dart';
import 'package:math_core/challenges/tables.dart';
import 'package:material_ui/material_ui.dart';
import 'package:math_core/leveling/level.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/models/game_setup.dart';
import 'package:math_core/persistence/in_memory_session_repository.dart';
import 'package:math_core/persistence/level_cache_entry.dart';
import 'package:math_core/persistence/persisted_answer.dart';
import 'package:math_core/persistence/persisted_session.dart';
import 'package:math_trainer/composition_root.dart';
import 'package:math_trainer/presentation/screens/app_shell.dart';
import 'package:math_trainer/presentation/screens/play_tab.dart';
import 'package:math_trainer/presentation/theme/app_theme.dart';

import '../fake_account_repository.dart';
import '../fake_profile_repository.dart';
import '../fake_stores.dart';
import 'golden_test_utils.dart';

/// Mockups 1 and 2 (`doc/mockups/redesign.html`), in both themes.
Future<AppEnvironment> _environment() async {
  final repository = InMemorySessionRepository();
  final at = DateTime.utc(2026, 11, 20);
  const levels = {
    ExerciseType.addition: 41,
    ExerciseType.subtraction: 36,
    ExerciseType.multiplication: 29,
    ExerciseType.division: 30,
    ExerciseType.power: 22,
    ExerciseType.squareRoot: 18,
    ExerciseType.percentage: 25,
  };
  await repository.recordSession(
    session: PersistedSession(
      id: 's',
      playerId: 'p',
      seed: 1,
      enabledTypes: const {ExerciseType.addition},
      exerciseCount: 1,
      totalScore: 0,
      levels: {ExerciseType.addition: Level.zero},
      createdAt: at,
    ),
    answers: [
      PersistedAnswer(
        id: 'a',
        sessionId: 's',
        exerciseType: 'arithmetic',
        operationType: 'addition',
        operands: const {'operandA': 1, 'operandB': 1},
        submittedValue: 2,
        isCorrect: true,
        elapsedMs: 900,
        createdAt: at,
      ),
    ],
    levelUpdates: {
      for (final MapEntry(:key, :value) in levels.entries)
        key: LevelCacheEntry(
          level: Level.whole(value),
          sessionsPlayed: 3,
          updatedAt: at,
        ),
    },
  );
  return AppEnvironment(
    repository: repository,
    playerId: 'p',
    accountRepository: FakeAccountRepository(),
    profileRepository: FakeProfileRepository(),
    typeSelectionStore: FakeTypeSelectionStore({
      ExerciseType.addition,
      ExerciseType.multiplication,
    }),
    gameSetupStore: FakeGameSetupStore(GameSetup(mode: GameMode.training)),
    tablesStore: FakeTablesStore(
      setup: TablesSetup(firstTable: 12, lastTable: 19),
    ),
  );
}

void main() {
  setUpAll(loadInterFontForGoldens);

  for (final (name, theme) in [
    ('light', buildLightTheme()),
    ('dark', buildDarkTheme()),
  ]) {
    Future<void> pumpShell(WidgetTester tester) async {
      await setGoldenSurfaceSize(tester);
      final environment = await tester.runAsync(_environment);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme,
          home: AppShell(environment: environment!),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('home — $name', (tester) async {
      await pumpShell(tester);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/home_$name.png'),
      );
    });

    testWidgets('game setup — $name', (tester) async {
      await pumpShell(tester);
      await tester.tap(find.byKey(playButtonKey(ExerciseFamily.basics)));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/game_setup_$name.png'),
      );
    });

    testWidgets('tables setup — $name', (tester) async {
      await pumpShell(tester);
      await tester.scrollUntilVisible(find.text('Tables'), 100);
      await tester.tap(find.text('Tables'));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/tables_setup_$name.png'),
      );
    });
  }
}
