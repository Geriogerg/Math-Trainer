import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:math_core/generation/exercise_source.dart';
import 'package:math_core/leveling/level.dart';
import 'package:math_core/models/exercise.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/models/operation_type.dart';
import 'package:math_core/models/session_config.dart';
import 'package:math_core/persistence/in_memory_session_repository.dart';
import 'package:math_trainer/core/state/session_controller.dart';
import 'package:math_trainer/presentation/screens/result_screen.dart';
import 'package:math_trainer/presentation/theme/app_theme.dart';

import 'golden_test_utils.dart';

/// Same double as the other goldens — no shared test infrastructure for a
/// single class of a few lines.
class _FixedExerciseSource extends ExerciseSource {
  _FixedExerciseSource(this._exercises);

  final List<Exercise> _exercises;
  int _index = 0;

  @override
  Exercise next() => _exercises[_index++];
}

class _InertTimer implements Timer {
  @override
  void cancel() {}

  @override
  bool get isActive => false;

  @override
  int get tick => 0;
}

void main() {
  setUpAll(loadInterFontForGoldens);

  Future<SessionController> buildFinishedController() async {
    final exercises = List.generate(
      4,
      (i) => ArithmeticExercise(
        operandA: i,
        operandB: 0,
        operationType: OperationType.addition,
      ),
    );
    final controller = SessionController(
      config: SessionConfig(
        seed: 1,
        enabledTypes: const {ExerciseType.addition},
        exerciseCount: exercises.length,
        levels: {ExerciseType.addition: Level.whole(12)},
      ),
      exerciseSource: _FixedExerciseSource(exercises),
      repository: InMemorySessionRepository(),
      playerId: 'golden-player',
      clock: () => DateTime(2026),
      createTimer: (duration, callback) => _InertTimer(),
    );
    controller.start();
    for (var i = 0; i < 4; i++) {
      controller.submitAnswer(i); // i + 0 = i: always right
    }
    // lastLevelUpdates must be resolved before the capture, otherwise the
    // golden freezes the transient "level before only" state rather than the
    // animation's final result (`doc/design.md`, AppMotion.levelUp).
    await controller.pendingPersistence;
    return controller;
  }

  /// Two mistakes (a wrong answer, a timeout) for the mistakes review
  /// (Phase 0, commit 9), the raised exponent included.
  Future<SessionController> buildControllerWithMistakes() async {
    final exercises = <Exercise>[
      ArithmeticExercise(
        operandA: 7,
        operandB: 8,
        operationType: OperationType.multiplication,
      ),
      ArithmeticExercise(
        operandA: 12,
        operandB: 9,
        operationType: OperationType.addition,
      ),
      PowerExercise(base: 3, exponent: 4),
      PercentageExercise(percent: 25, base: 80),
    ];
    void Function()? timeout;
    final controller = SessionController(
      config: SessionConfig(
        seed: 1,
        enabledTypes: const {
          ExerciseType.addition,
          ExerciseType.multiplication,
          ExerciseType.power,
          ExerciseType.percentage,
        },
        exerciseCount: exercises.length,
        levels: {
          ExerciseType.addition: Level.whole(12),
          ExerciseType.multiplication: Level.whole(12),
          ExerciseType.power: Level.whole(12),
          ExerciseType.percentage: Level.whole(12),
        },
      ),
      exerciseSource: _FixedExerciseSource(exercises),
      repository: InMemorySessionRepository(),
      playerId: 'golden-player',
      clock: () => DateTime(2026),
      createTimer: (duration, callback) {
        timeout = callback;
        return _InertTimer();
      },
    );
    controller.start();
    controller.submitAnswer(54); // 7 × 8 = 56: wrong
    controller.submitAnswer(21); // right
    timeout!(); // 3⁴: timed out
    controller.submitAnswer(20); // 25% of 80: right
    await controller.pendingPersistence;
    return controller;
  }

  for (final (scenario, build) in [
    ('', buildFinishedController),
    ('_mistakes', buildControllerWithMistakes),
  ]) {
    for (final mode in [
      (name: 'light', theme: buildLightTheme()),
      (name: 'dark', theme: buildDarkTheme()),
    ]) {
      testWidgets('result screen$scenario — ${mode.name}', (tester) async {
        await setGoldenSurfaceSize(tester);
        final controller = await build();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            locale: testLocale,
            supportedLocales: testLocales,
            localizationsDelegates: testLocalizations,
            theme: mode.theme,
            home: Scaffold(
              body: ResultScreen(
                controller: controller,
                onPlayAgain: () {},
                onExitToSelection: () {},
                isRestarting: false,
                restartError: null,
              ),
            ),
          ),
        );
        // Lets the level animation (600 ms) reach its final value — without
        // it the capture would depend on real elapsed time, not reproducible.
        await tester.pumpAndSettle();

        await expectLater(
          find.byType(ResultScreen),
          matchesGoldenFile(
            'goldens/result_screen${scenario}_${mode.name}.png',
          ),
        );
      });
    }
  }

  for (final (scenario, build) in [
    ('', buildFinishedController),
    ('_mistakes', buildControllerWithMistakes),
  ]) {
    testWidgets('result screen$scenario — French, 360 px', (tester) async {
      useFrench();
      final controller = await build();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          locale: testLocale,
          supportedLocales: testLocales,
          localizationsDelegates: testLocalizations,
          theme: buildLightTheme(),
          home: Scaffold(
            body: ResultScreen(
              controller: controller,
              onPlayAgain: () {},
              onExitToSelection: () {},
              isRestarting: false,
              restartError: null,
            ),
          ),
        ),
      );
      await expectFrenchAt360(tester, 'result$scenario', height: 1400);
    });
  }
}
