import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// Même double que `session_screen_golden_test.dart` — pas d'infrastructure
/// de test partagée pour une seule classe de quelques lignes.
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
  testWidgets(
    'la série n\'apparaît qu\'à partir de la première bonne réponse (commit F)',
    (tester) async {
      const exercises = [
        ArithmeticExercise(operandA: 1, operandB: 1, operationType: OperationType.addition),
        ArithmeticExercise(operandA: 2, operandB: 2, operationType: OperationType.addition),
        ArithmeticExercise(operandA: 3, operandB: 3, operationType: OperationType.addition),
      ];
      final controller = SessionController(
        config: SessionConfig(
          seed: 1,
          enabledTypes: const {ExerciseType.addition},
          exerciseCount: exercises.length,
          levels: const {ExerciseType.addition: 12},
        ),
        exerciseSource: _FixedExerciseSource(exercises),
        repository: InMemorySessionRepository(),
        playerId: 'test-player',
        clock: () => DateTime(2026),
        createTimer: (duration, callback) => _InertTimer(),
      )..start();
      addTearDown(controller.dispose);

      // ListenableBuilder : dans l'app réelle, c'est SessionFlowScreen qui
      // reconstruit SessionScreen à chaque notifyListeners() (commit A).
      // Sans lui ici, submitAnswer() ne provoquerait aucun rebuild.
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: Scaffold(
            body: ListenableBuilder(
              listenable: controller,
              builder: (context, _) => SessionScreen(controller: controller),
            ),
          ),
        ),
      );
      await tester.pump();

      // Première question : aucune série encore.
      expect(find.textContaining('série'), findsNothing);
      expect(find.text('Addition · niveau 12'), findsOneWidget);

      controller.submitAnswer(2); // 1 + 1, correct
      await tester.pump();

      expect(find.text('Addition · niveau 12 · série 1'), findsOneWidget);

      controller.submitAnswer(4); // 2 + 2, correct
      await tester.pump();

      expect(find.text('Addition · niveau 12 · série 2'), findsOneWidget);

      controller.submitAnswer(0); // 3 + 3, faux : la série retombe
      await tester.pump();

      // Session terminée (3/3 réponses) : SessionScreen ne montre plus rien
      // (EmptyState) — la série finale est visible sur ResultScreen, pas ici.
      expect(controller.state.status.name, 'finished');
    },
  );

  group('clavier physique', () {
    Future<SessionController> pumpSession(WidgetTester tester) async {
      const exercises = [
        ArithmeticExercise(operandA: 6, operandB: 6, operationType: OperationType.addition),
        ArithmeticExercise(operandA: 1, operandB: 1, operationType: OperationType.addition),
      ];
      final controller = SessionController(
        config: SessionConfig(
          seed: 1,
          enabledTypes: const {ExerciseType.addition},
          exerciseCount: exercises.length,
          levels: const {ExerciseType.addition: 1},
        ),
        exerciseSource: _FixedExerciseSource(exercises),
        repository: InMemorySessionRepository(),
        playerId: 'test-player',
        clock: () => DateTime(2026),
        createTimer: (duration, callback) => _InertTimer(),
      )..start();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: Scaffold(
            body: ListenableBuilder(
              listenable: controller,
              builder: (context, _) => SessionScreen(controller: controller),
            ),
          ),
        ),
      );
      await tester.pump();
      return controller;
    }

    testWidgets('chiffres, retour arrière et Entrée valident une réponse', (tester) async {
      final controller = await pumpSession(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
      await tester.pump();
      expect(find.text('12'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(controller.state.outcomes.single.submittedValue, 12);
      expect(controller.state.outcomes.single.isCorrect, isTrue);
    });

    testWidgets('pavé numérique du clavier', (tester) async {
      final controller = await pumpSession(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.numpad1);
      await tester.sendKeyEvent(LogicalKeyboardKey.numpad2);
      await tester.sendKeyEvent(LogicalKeyboardKey.numpadEnter);
      await tester.pump();

      expect(controller.state.outcomes.single.submittedValue, 12);
    });

    testWidgets('la saisie est plafonnée à 7 chiffres', (tester) async {
      await pumpSession(tester);

      for (var i = 0; i < 10; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.digit9);
      }
      await tester.pump();

      expect(find.text('9999999'), findsOneWidget);
    });
  });
}
