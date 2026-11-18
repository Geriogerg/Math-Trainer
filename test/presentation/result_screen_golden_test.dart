import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:math_trainer/core/domain/generation/exercise_source.dart';
import 'package:math_trainer/core/domain/models/exercise.dart';
import 'package:math_trainer/core/domain/models/exercise_type.dart';
import 'package:math_trainer/core/domain/models/operation_type.dart';
import 'package:math_trainer/core/domain/models/session_config.dart';
import 'package:math_trainer/core/domain/persistence/in_memory_session_repository.dart';
import 'package:math_trainer/core/state/session_controller.dart';
import 'package:math_trainer/presentation/screens/result_screen.dart';
import 'package:math_trainer/presentation/theme/app_theme.dart';

import 'golden_test_utils.dart';

/// Same double as the other goldens — no shared test infrastructure for a
/// single class of a few lines.
class _FixedExerciseSource implements ExerciseSource {
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
        levels: const {ExerciseType.addition: 12},
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

  for (final mode in [
    (name: 'light', theme: buildLightTheme()),
    (name: 'dark', theme: buildDarkTheme()),
  ]) {
    testWidgets('result screen — ${mode.name}', (tester) async {
      await setGoldenSurfaceSize(tester);
      final controller = await buildFinishedController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
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
      // Lets the level animation (600 ms) reach its final value — without it
      // the capture would depend on real elapsed time, not reproducible.
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(ResultScreen),
        matchesGoldenFile('goldens/result_screen_${mode.name}.png'),
      );
    });
  }
}
