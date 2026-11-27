import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:math_core/generation/exercise_source.dart';
import 'package:math_core/leveling/level.dart';
import 'package:math_core/models/exercise.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/models/operation_type.dart';
import 'package:math_core/models/session_config.dart';
import 'package:math_core/persistence/in_memory_session_repository.dart';
import 'package:math_trainer/core/state/session_controller.dart';
import 'package:math_trainer/presentation/exercise_prompt.dart';
import 'package:math_trainer/presentation/screens/session_screen.dart';
import 'package:math_trainer/presentation/strings/spoken_prompt.dart';
import 'package:math_trainer/presentation/theme/app_theme.dart';

/// A game a screen reader can play (Phase 6b commit 6, review M17): every
/// prompt has words, each question is a live region, right, wrong and the
/// time are said.
class _Fixed extends ExerciseSource {
  _Fixed(this._exercises);

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

ArithmeticExercise _times(int a, int b) => ArithmeticExercise(
  operandA: a,
  operandB: b,
  operationType: OperationType.multiplication,
);

const _digitKeys = [
  LogicalKeyboardKey.digit0,
  LogicalKeyboardKey.digit1,
  LogicalKeyboardKey.digit2,
  LogicalKeyboardKey.digit3,
  LogicalKeyboardKey.digit4,
  LogicalKeyboardKey.digit5,
  LogicalKeyboardKey.digit6,
  LogicalKeyboardKey.digit7,
  LogicalKeyboardKey.digit8,
  LogicalKeyboardKey.digit9,
];

void main() {
  group('spoken prompts', () {
    test('arithmetic: the signs as words, numbers ungrouped', () {
      expect(spokenPrompt(_times(47, 8)), '47 times 8');
      expect(
        spokenPrompt(
          ArithmeticExercise(
            operandA: 4789,
            operandB: 3657,
            operationType: OperationType.subtraction,
          ),
        ),
        '4789 minus 3657',
      );
      expect(
        spokenPrompt(
          ArithmeticExercise(
            operandA: 27,
            operandB: 46,
            operandC: 73,
            operationType: OperationType.addition,
          ),
        ),
        '27 plus 46 plus 73',
      );
      expect(
        spokenPrompt(
          ArithmeticExercise(
            operandA: 522,
            operandB: 6,
            operationType: OperationType.division,
          ),
        ),
        '522 divided by 6',
      );
    });

    test('powers, roots, percentages', () {
      expect(spokenPrompt(PowerExercise(base: 12, exponent: 2)), '12 squared');
      expect(spokenPrompt(PowerExercise(base: 5, exponent: 3)), '5 cubed');
      expect(
        spokenPrompt(PowerExercise(base: 2, exponent: 10)),
        '2 to the power 10',
      );
      expect(
        spokenPrompt(SquareRootExercise(radicand: 169)),
        'the square root of 169',
      );
      expect(
        spokenPrompt(SquareRootExercise(radicand: 27, index: 3)),
        'the cube root of 27',
      );
      expect(
        spokenPrompt(PercentageExercise(percent: 25, base: 80)),
        '25 percent of 80',
      );
      expect(
        spokenPrompt(PercentageExercise(percent: 37, tenths: 5, base: 64)),
        '37.5 percent of 64',
      );
    });

    test('integrals: the bounds, then the polynomial in words', () {
      expect(
        spokenPrompt(
          IntegralExercise(lower: 0, upper: 3, c0: 2, c1: 2, c2: 0, c3: 4),
        ),
        'the integral from 0 to 3 of 4 x cubed plus 2 x plus 2, d x',
      );
      expect(
        spokenPrompt(
          IntegralExercise(
            lower: 1,
            upper: 2,
            c0: 0,
            c1: 0,
            c2: -3,
            c3: 0,
            c4: 5,
          ),
        ),
        'the integral from 1 to 2 of 5 x to the power 4 minus 3 x squared, '
        'd x',
      );
    });

    testWidgets('every prompt carries its words', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: Scaffold(
            body: ExercisePrompt(
              exercise: PowerExercise(base: 12, exponent: 2),
            ),
          ),
        ),
      );
      expect(find.bySemanticsLabel('12 squared'), findsOneWidget);
      handle.dispose();
    });
  });

  group('the game screen', () {
    Future<SessionController> pumpGame(WidgetTester tester) async {
      final exercises = [_times(47, 8), _times(12, 12)];
      final controller = SessionController(
        config: SessionConfig(
          seed: 1,
          enabledTypes: const {ExerciseType.multiplication},
          exerciseCount: exercises.length,
          levels: {ExerciseType.multiplication: Level.whole(1)},
        ),
        exerciseSource: _Fixed(exercises),
        repository: InMemorySessionRepository(),
        playerId: 'p',
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

    Future<void> type(WidgetTester tester, String digits) async {
      for (final d in digits.split('')) {
        await tester.sendKeyEvent(_digitKeys[int.parse(d)]);
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
    }

    List<String> said(WidgetTester tester) => [
      for (final a in tester.takeAnnouncements()) a.message,
    ];

    testWidgets('the question is a live region, read as words', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpGame(tester);
      expect(
        tester.getSemantics(
          find.bySemanticsLabel('Question 1 of 2: 47 times 8'),
        ),
        isSemantics(isLiveRegion: true),
      );
      await type(tester, '376');
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.bySemanticsLabel('Question 2 of 2: 12 times 12'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('right and wrong are said, with the answer', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpGame(tester);
      await type(tester, '376');
      expect(said(tester), ['Right']);
      await tester.pump(const Duration(milliseconds: 300));
      await type(tester, '140');
      expect(said(tester), ['Wrong. 12 times 12 is 144.']);
      handle.dispose();
    });

    testWidgets('the time: its value, and "10 seconds left" once', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpGame(tester);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Time left')),
        isSemantics(value: '30 seconds'),
      );
      await tester.pump(const Duration(seconds: 19));
      expect(said(tester), isEmpty);
      await tester.pump(const Duration(seconds: 2));
      expect(said(tester), ['10 seconds left']);
      await tester.pump(const Duration(seconds: 5));
      expect(said(tester), isEmpty, reason: 'once');
      handle.dispose();
    });
  });
}
