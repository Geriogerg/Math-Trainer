import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:math_trainer/core/domain/generation/exercise_source.dart';
import 'package:math_trainer/core/domain/models/exercise.dart';
import 'package:math_trainer/core/domain/models/exercise_type.dart';
import 'package:math_trainer/core/domain/models/operation_type.dart';
import 'package:math_trainer/core/domain/models/session_config.dart';
import 'package:math_trainer/core/domain/persistence/in_memory_session_repository.dart';
import 'package:math_trainer/core/domain/persistence/level_cache_entry.dart';
import 'package:math_trainer/core/domain/persistence/persisted_answer.dart';
import 'package:math_trainer/core/domain/persistence/persisted_session.dart';
import 'package:math_trainer/core/domain/persistence/session_repository.dart';
import 'package:math_trainer/core/state/session_controller.dart';
import 'package:math_trainer/presentation/screens/result_screen.dart';
import 'package:math_trainer/presentation/theme/app_theme.dart';

/// Same double as the other controller/golden tests — no shared test
/// infrastructure for a single class of a few lines (project convention).
class _FixedExerciseSource implements ExerciseSource {
  _FixedExerciseSource(this._exercises);

  final List<Exercise> _exercises;
  int _index = 0;

  @override
  Exercise next() => _exercises[_index++];
}

class _RecordFailureRepository extends InMemorySessionRepository {
  /// Setting it back to `false` simulates storage coming back.
  bool failing = true;

  @override
  Future<void> recordSession({
    required PersistedSession session,
    required List<PersistedAnswer> answers,
    required Map<ExerciseType, LevelCacheEntry> levelUpdates,
  }) async {
    if (failing) throw Exception('storage unavailable (simulated)');
    await super.recordSession(
      session: session,
      answers: answers,
      levelUpdates: levelUpdates,
    );
  }
}

void main() {
  List<Exercise> additionExercises(int count) => List.generate(
    count,
    (i) => ArithmeticExercise(
      operandA: i,
      operandB: 0,
      operationType: OperationType.addition,
    ),
  );

  SessionController finishedController({SessionRepository? repository}) {
    final controller = SessionController(
      config: SessionConfig(
        seed: 1,
        enabledTypes: const {ExerciseType.addition},
        exerciseCount: 4,
        levels: const {ExerciseType.addition: 50},
      ),
      exerciseSource: _FixedExerciseSource(additionExercises(4)),
      repository: repository ?? InMemorySessionRepository(),
      playerId: 'test-player',
      clock: () => DateTime(2024),
      createTimer: (duration, callback) => _InertTimer(),
    );
    controller.start();
    for (var i = 0; i < 4; i++) {
      controller.submitAnswer(i); // always right
    }
    return controller;
  }

  Future<void> pumpResultScreen(
    WidgetTester tester,
    SessionController controller, {
    VoidCallback? onPlayAgain,
    VoidCallback? onExitToSelection,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(
          body: ResultScreen(
            controller: controller,
            onPlayAgain: onPlayAgain ?? () {},
            onExitToSelection: onExitToSelection ?? () {},
            isRestarting: false,
            restartError: null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('finished session: level change, score breakdown, counts, meta', (
    tester,
  ) async {
    final controller = finishedController();
    addTearDown(controller.dispose);
    await controller.pendingPersistence;

    await pumpResultScreen(tester, controller);

    expect(find.textContaining('Addition — level'), findsOneWidget);
    expect(find.textContaining('Score: '), findsOneWidget);
    expect(find.textContaining('Base: '), findsOneWidget);
    expect(find.textContaining('Speed bonus: '), findsOneWidget);
    expect(find.textContaining('Streak bonus: '), findsOneWidget);
    expect(find.textContaining('Difficulty bonus: '), findsOneWidget);
    expect(
      find.textContaining('4 right · 0 wrong · 0 timed out'),
      findsOneWidget,
    );
    expect(find.textContaining('Average time: '), findsOneWidget);
    expect(find.textContaining('Best streak: 4'), findsOneWidget);
    expect(find.textContaining('Types played: Addition'), findsOneWidget);
    // Never a percentage presented as progress (`doc/design.md`).
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('Difficulty bonus hidden when it is 0 (level 1, no multiplier)', (
    tester,
  ) async {
    final controller = SessionController(
      config: SessionConfig(
        seed: 1,
        enabledTypes: const {ExerciseType.addition},
        exerciseCount: 4,
        levels: const {ExerciseType.addition: 1},
      ),
      exerciseSource: _FixedExerciseSource(additionExercises(4)),
      repository: InMemorySessionRepository(),
      playerId: 'test-player',
      clock: () => DateTime(2024),
      createTimer: (duration, callback) => _InertTimer(),
    );
    addTearDown(controller.dispose);
    controller.start();
    for (var i = 0; i < 4; i++) {
      controller.submitAnswer(i);
    }
    await controller.pendingPersistence;

    await pumpResultScreen(tester, controller);

    expect(find.textContaining('Difficulty bonus'), findsNothing);
  });

  testWidgets(
    'a type left under n_min this session is told apart from an unchanged level',
    (tester) async {
      // Two types enabled, but the exercise source only produces addition:
      // subtraction stays at 0 answers, so under n_min — computeUpdates
      // creates no entry for it (see level_cache_orchestrator.dart).
      final controller = SessionController(
        config: SessionConfig(
          seed: 1,
          enabledTypes: const {ExerciseType.addition, ExerciseType.subtraction},
          exerciseCount: 4,
          levels: const {
            ExerciseType.addition: 50,
            ExerciseType.subtraction: 50,
          },
        ),
        exerciseSource: _FixedExerciseSource(additionExercises(4)),
        repository: InMemorySessionRepository(),
        playerId: 'test-player',
        clock: () => DateTime(2024),
        createTimer: (duration, callback) => _InertTimer(),
      );
      addTearDown(controller.dispose);
      controller.start();
      for (var i = 0; i < 4; i++) {
        controller.submitAnswer(i);
      }
      await controller.pendingPersistence;

      await pumpResultScreen(tester, controller);

      expect(
        find.text('Subtraction — level 50 (not enough answers to count)'),
        findsOneWidget,
      );
      // Addition was evaluated: not that text for it.
      expect(
        find.textContaining('Addition — level 50 (not enough'),
        findsNothing,
      );
    },
  );

  testWidgets('interrupted session: no level change block', (tester) async {
    final controller = SessionController(
      config: SessionConfig(
        seed: 1,
        enabledTypes: const {ExerciseType.addition},
        exerciseCount: 4,
        levels: const {ExerciseType.addition: 50},
      ),
      exerciseSource: _FixedExerciseSource(additionExercises(4)),
      repository: InMemorySessionRepository(),
      playerId: 'test-player',
      clock: () => DateTime(2024),
      createTimer: (duration, callback) => _InertTimer(),
    );
    addTearDown(controller.dispose);
    controller.start();
    controller.submitAnswer(0);
    controller.abandon();
    await controller.pendingPersistence;

    await pumpResultScreen(tester, controller);

    expect(find.text('Session interrupted'), findsOneWidget);
    expect(find.textContaining('Addition — level'), findsNothing);
  });

  testWidgets('Play again and New selection trigger their own callbacks', (
    tester,
  ) async {
    final controller = finishedController();
    addTearDown(controller.dispose);
    await controller.pendingPersistence;

    var playAgainTapped = false;
    var exitTapped = false;
    await pumpResultScreen(
      tester,
      controller,
      onPlayAgain: () => playAgainTapped = true,
      onExitToSelection: () => exitTapped = true,
    );

    await tester.tap(find.text('Play again'));
    expect(playAgainTapped, isTrue);

    await tester.tap(find.text('New selection'));
    expect(exitTapped, isTrue);
  });

  testWidgets('failed save: the game is reported as not counted', (
    tester,
  ) async {
    final controller = finishedController(
      repository: _RecordFailureRepository(),
    );
    addTearDown(controller.dispose);
    await controller.pendingPersistence;

    await pumpResultScreen(tester, controller);

    expect(find.textContaining('Game not saved'), findsOneWidget);
  });

  testWidgets('successful save: no warning', (tester) async {
    final controller = finishedController();
    addTearDown(controller.dispose);
    await controller.pendingPersistence;

    await pumpResultScreen(tester, controller);

    expect(find.textContaining('Game not saved'), findsNothing);
    expect(find.text('Retry saving'), findsNothing);
  });

  testWidgets('"Retry saving" stores the game and removes the warning', (
    tester,
  ) async {
    final repository = _RecordFailureRepository();
    final controller = finishedController(repository: repository);
    addTearDown(controller.dispose);
    await controller.pendingPersistence;
    // As in `SessionFlowScreen`: its `ListenableBuilder` rebuilds the result
    // screen when the controller notifies.
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(
          body: ListenableBuilder(
            listenable: controller,
            builder: (context, _) => ResultScreen(
              controller: controller,
              onPlayAgain: () {},
              onExitToSelection: () {},
              isRestarting: false,
              restartError: null,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    repository.failing = false;
    await tester.tap(find.text('Retry saving'));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('Game not saved'), findsNothing);
    expect(find.text('Retry saving'), findsNothing);
    expect(await repository.recentSessions('test-player'), hasLength(1));
  });
}

class _InertTimer implements Timer {
  @override
  void cancel() {}

  @override
  bool get isActive => false;

  @override
  int get tick => 0;
}
