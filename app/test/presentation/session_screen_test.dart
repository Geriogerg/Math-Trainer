import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:math_core/generation/exercise_source.dart';
import 'package:math_core/leveling/level.dart';
import 'package:math_core/models/exercise.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/models/input_device.dart';
import 'package:math_core/models/operation_type.dart';
import 'package:math_core/models/session_config.dart';
import 'package:math_core/persistence/in_memory_session_repository.dart';
import 'package:math_trainer/core/state/session_controller.dart';
import 'package:math_trainer/presentation/screens/session_screen.dart';
import 'package:math_trainer/presentation/theme/app_theme.dart';

/// Same double as `session_screen_golden_test.dart` — no shared test
/// infrastructure for a single class of a few lines.
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
  group('physical keyboard', () {
    Future<SessionController> pumpSession(WidgetTester tester) async {
      const exercises = [
        ArithmeticExercise(
          operandA: 6,
          operandB: 6,
          operationType: OperationType.addition,
        ),
        ArithmeticExercise(
          operandA: 1,
          operandB: 1,
          operationType: OperationType.addition,
        ),
      ];
      final controller = SessionController(
        config: SessionConfig(
          seed: 1,
          enabledTypes: const {ExerciseType.addition},
          exerciseCount: exercises.length,
          levels: {ExerciseType.addition: Level.whole(1)},
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

    testWidgets('digits, backspace and Enter submit an answer', (tester) async {
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

    testWidgets('keyboard numeric keypad', (tester) async {
      final controller = await pumpSession(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.numpad1);
      await tester.sendKeyEvent(LogicalKeyboardKey.numpad2);
      await tester.sendKeyEvent(LogicalKeyboardKey.numpadEnter);
      await tester.pump();

      expect(controller.state.outcomes.single.submittedValue, 12);
    });

    testWidgets('input is capped at 7 digits', (tester) async {
      await pumpSession(tester);

      for (var i = 0; i < 10; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.digit9);
      }
      await tester.pump();

      expect(find.text('9999999'), findsOneWidget);
    });

    testWidgets('each answer records which keys typed it', (tester) async {
      final controller = await pumpSession(tester);

      // 6 + 6 on the on-screen keypad.
      await tester.tap(find.text('1'));
      await tester.pump();
      await tester.tap(find.text('2'));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.check));
      await tester.pump();
      // 1 + 1 typed on the keyboard, submitted on the keypad.
      await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
      await tester.pump();
      await tester.tap(find.byIcon(Icons.check));
      await tester.pump();

      expect(controller.state.outcomes.map((o) => o.inputDevice), [
        InputDevice.keypad,
        InputDevice.mixed,
      ]);
    });

    testWidgets('keyboard only is recorded as keyboard', (tester) async {
      final controller = await pumpSession(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(
        controller.state.outcomes.single.inputDevice,
        InputDevice.keyboard,
      );
    });
  });

  group('correction pause (Phase 0, commit 9)', () {
    late List<void Function()> armed;

    Future<SessionController> pumpCorrecting(WidgetTester tester) async {
      armed = [];
      final controller = SessionController(
        config: SessionConfig(
          seed: 1,
          enabledTypes: const {ExerciseType.addition},
          exerciseCount: 3,
          levels: {ExerciseType.addition: Level.whole(12)},
        ),
        exerciseSource: _FixedExerciseSource(const [
          ArithmeticExercise(
            operandA: 7,
            operandB: 8,
            operationType: OperationType.multiplication,
          ),
          ArithmeticExercise(
            operandA: 2,
            operandB: 2,
            operationType: OperationType.addition,
          ),
          ArithmeticExercise(
            operandA: 3,
            operandB: 3,
            operationType: OperationType.addition,
          ),
        ]),
        repository: InMemorySessionRepository(),
        playerId: 'test-player',
        clock: () => DateTime(2026),
        // Fired by hand: the last armed callback is the running timer.
        createTimer: (duration, callback) {
          armed.add(callback);
          return _InertTimer();
        },
        correctionDelay: SessionController.defaultCorrectionDelay,
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

    testWidgets('a wrong answer shows the correct one and what was typed', (
      tester,
    ) async {
      await pumpCorrecting(tester);

      await tester.tap(find.text('5'));
      await tester.tap(find.text('4'));
      await tester.tap(find.byIcon(Icons.check));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('56'), findsOneWidget); // 7 × 8
      // What was typed, struck through — no words (Redesign phase).
      final given = tester.widget<Text>(find.text('54'));
      expect(given.style?.decoration, TextDecoration.lineThrough);
      expect(find.bySemanticsLabel(RegExp('Your answer 54')), findsOneWidget);
      expect(find.text('7 × 8'), findsOneWidget);
      expect(find.text('1 / 3'), findsOneWidget);
    });

    testWidgets('keys are ignored during the pause', (tester) async {
      final controller = await pumpCorrecting(tester);
      await tester.tap(find.text('1'));
      await tester.tap(find.byIcon(Icons.check));
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.text('9'));
      await tester.tap(find.byIcon(Icons.check));
      await tester.pump(const Duration(milliseconds: 200));

      expect(controller.state.outcomes, hasLength(1));
      expect(find.text('56'), findsOneWidget);
    });

    testWidgets('after the pause the next question comes, caption cleared', (
      tester,
    ) async {
      await pumpCorrecting(tester);
      await tester.tap(find.text('1'));
      await tester.tap(find.byIcon(Icons.check));
      await tester.pump(const Duration(milliseconds: 200));

      armed.last(); // end of the correction pause
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('2 + 2'), findsOneWidget);
      expect(find.text('2 / 3'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Your answer')), findsNothing);
      expect(find.text('56'), findsNothing);
    });

    testWidgets('a timeout shows an hourglass', (tester) async {
      await pumpCorrecting(tester);

      armed.last(); // the question's timeout
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byIcon(Icons.hourglass_empty), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp("Time's up")), findsOneWidget);
      expect(find.text('56'), findsOneWidget);
    });
  });

  testWidgets('no timeout (debug switch): the timer bar stays full', (
    tester,
  ) async {
    final controller = SessionController(
      config: SessionConfig(
        seed: 1,
        enabledTypes: const {ExerciseType.addition},
        exerciseCount: 2,
        levels: {ExerciseType.addition: Level.whole(12)},
      ),
      exerciseSource: _FixedExerciseSource(const [
        ArithmeticExercise(
          operandA: 1,
          operandB: 1,
          operationType: OperationType.addition,
        ),
        ArithmeticExercise(
          operandA: 2,
          operandB: 2,
          operationType: OperationType.addition,
        ),
      ]),
      repository: InMemorySessionRepository(),
      playerId: 'test-player',
      clock: () => DateTime(2026),
      questionTimeout: null,
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
    await tester.pump(const Duration(seconds: 20));

    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, 1);
    expect(controller.state.outcomes, isEmpty);
  });
}
