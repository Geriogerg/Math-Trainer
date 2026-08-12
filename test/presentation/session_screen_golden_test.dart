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
import 'package:math_trainer/presentation/screens/session_screen.dart';
import 'package:math_trainer/presentation/theme/app_theme.dart';

import 'golden_test_utils.dart';

/// Même double que `test/state/session_controller_test.dart` — pas
/// d'infrastructure de test partagée pour une seule classe de quelques
/// lignes (convention du projet).
class _FixedExerciseSource implements ExerciseSource {
  _FixedExerciseSource(this._exercises);

  final List<Exercise> _exercises;
  int _index = 0;

  @override
  Exercise next() => _exercises[_index++];
}

/// Un vrai `Timer(Duration(seconds: 15), ...)` resterait en attente à la fin
/// du test (`flutter_test` échoue dessus) ; ce golden n'a besoin ni de le
/// déclencher ni de l'annuler explicitement, juste qu'il n'existe pas.
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

  SessionController buildController() {
    const exercises = [
      ArithmeticExercise(operandA: 47, operandB: 18, operationType: OperationType.addition),
    ];
    return SessionController(
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
    )..start();
  }

  for (final mode in [
    (name: 'light', theme: buildLightTheme()),
    (name: 'dark', theme: buildDarkTheme()),
  ]) {
    testWidgets('écran de session — ${mode.name}', (tester) async {
      await setGoldenSurfaceSize(tester);
      final controller = buildController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: mode.theme,
          home: Scaffold(body: SessionScreen(controller: controller)),
        ),
      );
      // Un seul pump, sans avancer le temps : le chrono (5 s) doit rester au
      // même point à chaque exécution pour un golden reproductible.
      await tester.pump();

      await expectLater(
        find.byType(SessionScreen),
        matchesGoldenFile('goldens/session_screen_${mode.name}.png'),
      );
    });
  }
}
