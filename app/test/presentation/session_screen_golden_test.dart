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
import 'package:math_trainer/presentation/screens/session_screen.dart';
import 'package:math_trainer/presentation/theme/app_theme.dart';

import 'golden_test_utils.dart';

/// Same double as `test/state/session_controller_test.dart` — no shared test
/// infrastructure for a single class of a few lines (project convention).
class _FixedExerciseSource extends ExerciseSource {
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
  SessionController buildController({
    bool correcting = false,
    bool integral = false,
    bool stacked = false,
  }) {
    final exercises = [
      if (integral)
        IntegralExercise(lower: 0, upper: 3, c0: 0, c1: 2, c2: 0, c3: 0),
      // Too wide for one line on the golden's phone: two right-aligned
      // lines (Levels phase commit 5).
      if (stacked)
        const ArithmeticExercise(
          operandA: 4789,
          operandB: 3657,
          operationType: OperationType.multiplication,
        ),
      const ArithmeticExercise(
        operandA: 47,
        operandB: 18,
        operationType: OperationType.addition,
      ),
      const ArithmeticExercise(
        operandA: 9,
        operandB: 6,
        operationType: OperationType.multiplication,
      ),
    ];
    final controller = SessionController(
      config: SessionConfig(
        seed: 1,
        enabledTypes: const {ExerciseType.addition},
        // One question in the plain golden, two when a correction must not
        // be on the last question.
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

  // Mockups 3 and 4 (`doc/mockups/redesign.html`), the correction pause.
  for (final (scenario, correcting, integral, stacked) in [
    ('', false, false, false),
    ('_correction', true, false, false),
    ('_integral', false, true, false),
    ('_stacked', false, false, true),
  ]) {
    for (final mode in [
      (name: 'light', theme: buildLightTheme()),
      (name: 'dark', theme: buildDarkTheme()),
    ]) {
      testWidgets('session screen$scenario — ${mode.name}', (tester) async {
        // The stacked question on the small phone: on 412 px it fits one
        // line.
        await setGoldenSurfaceSize(
          tester,
          size: stacked ? const Size(360, 640) : const Size(412, 915),
        );
        final controller = buildController(
          correcting: correcting,
          integral: integral,
          stacked: stacked,
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            theme: mode.theme,
            home: Scaffold(
              body: SessionScreen(controller: controller, onQuit: () {}),
            ),
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
