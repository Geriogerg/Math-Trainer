import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:math_trainer/core/domain/generation/exercise_source.dart';
import 'package:math_trainer/core/domain/leveling/level.dart';
import 'package:math_trainer/core/domain/models/exercise.dart';
import 'package:math_trainer/core/domain/models/exercise_type.dart';
import 'package:math_trainer/core/domain/models/operation_type.dart';
import 'package:math_trainer/core/domain/models/session_config.dart';
import 'package:math_trainer/core/domain/persistence/in_memory_session_repository.dart';
import 'package:math_trainer/core/state/session_controller.dart';
import 'package:math_trainer/presentation/screens/session_screen.dart';
import 'package:math_trainer/presentation/theme/app_theme.dart';

import 'golden_test_utils.dart';

/// Same double as `test/state/session_controller_test.dart` — no shared test
/// infrastructure for a single class of a few lines (project convention).
class _FixedExerciseSource implements ExerciseSource {
  _FixedExerciseSource(this._exercises);

  final List<Exercise> _exercises;
  int _index = 0;

  @override
  Exercise next() => _exercises[_index++];
}

/// A real `Timer(Duration(seconds: 15), ...)` would stay pending at the end
/// of the test (`flutter_test` fails on it); this golden needs neither to
/// fire nor to cancel it explicitly, only for it not to exist.
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

  /// [correcting]: answered 64 instead of 65, the correction pause showing
  /// (Phase 0, commit 9) — a second question so it is not the last one.
  SessionController buildController({bool correcting = false}) {
    const exercises = [
      ArithmeticExercise(
        operandA: 47,
        operandB: 18,
        operationType: OperationType.addition,
      ),
      ArithmeticExercise(
        operandA: 9,
        operandB: 6,
        operationType: OperationType.multiplication,
      ),
    ];
    final controller = SessionController(
      config: SessionConfig(
        seed: 1,
        enabledTypes: const {ExerciseType.addition},
        // One question in the plain golden (its "1 / 1" stays as recorded),
        // two when a correction must not be on the last question.
        exerciseCount: correcting ? 2 : 1,
        levels: {ExerciseType.addition: Level.whole(12)},
      ),
      exerciseSource: _FixedExerciseSource(exercises),
      repository: InMemorySessionRepository(),
      playerId: 'golden-player',
      clock: () => DateTime(2026),
      createTimer: (duration, callback) => _InertTimer(),
      correctionDelay: SessionController.defaultCorrectionDelay,
    )..start();
    if (correcting) controller.submitAnswer(64);
    return controller;
  }

  for (final (scenario, correcting) in [('', false), ('_correction', true)]) {
    for (final mode in [
      (name: 'light', theme: buildLightTheme()),
      (name: 'dark', theme: buildDarkTheme()),
    ]) {
      testWidgets('session screen$scenario — ${mode.name}', (tester) async {
        await setGoldenSurfaceSize(tester);
        final controller = buildController(correcting: correcting);
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            theme: mode.theme,
            home: Scaffold(body: SessionScreen(controller: controller)),
          ),
        );
        // A single pump, without advancing time: the timer (5 s) must stay at
        // the same point on every run for a reproducible golden.
        await tester.pump();

        await expectLater(
          find.byType(SessionScreen),
          matchesGoldenFile(
            'goldens/session_screen${scenario}_${mode.name}.png',
          ),
        );
      });
    }
  }
}
