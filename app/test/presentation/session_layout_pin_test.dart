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
import 'package:math_trainer/core/effects/session_effects.dart';
import 'package:math_trainer/core/state/session_controller.dart';
import 'package:math_trainer/presentation/screens/session_screen.dart';
import 'package:math_trainer/presentation/theme/app_theme.dart';

import 'golden_test_utils.dart';

/// Phase 5 beta-safety rule (`doc/plan.md`, Phase 5): the calibration data
/// must stay comparable, so nothing may move the keypad's keys, the
/// question or the answer, nor delay the next question. These numbers were
/// measured on the session screen as the beta started (Phase 5 commit 0,
/// Inter loaded as in the app) and must never change: a restyling that
/// fails here changes how players answer.
///
/// Rects are logical pixels, `left, top, width, height`.
class _Source extends ExerciseSource {
  _Source(this._exercises);

  final List<Exercise> _exercises;
  int _index = 0;

  @override
  Exercise next() => _exercises[_index++ % _exercises.length];
}

class _InertTimer implements Timer {
  @override
  void cancel() {}

  @override
  bool get isActive => false;

  @override
  int get tick => 0;
}

const _addition = ArithmeticExercise(
  operandA: 47,
  operandB: 38,
  operationType: OperationType.addition,
);

SessionController _controller(
  List<Exercise> exercises, {
  Duration? correctionDelay,
}) => SessionController(
  config: SessionConfig(
    seed: 1,
    enabledTypes: const {ExerciseType.addition},
    exerciseCount: 10,
    levels: {ExerciseType.addition: Level.whole(12)},
  ),
  exerciseSource: _Source(exercises),
  repository: InMemorySessionRepository(),
  playerId: 'test-player',
  clock: () => DateTime(2026),
  createTimer: (duration, callback) => _InertTimer(),
  correctionDelay: correctionDelay,
)..start();

Future<SessionController> _pump(
  WidgetTester tester, {
  required Size size,
  required ThemeData theme,
  List<Exercise> exercises = const [_addition],
  SessionEffects effects = const NoSessionEffects(),
  Duration? correctionDelay,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  final controller = _controller(exercises, correctionDelay: correctionDelay);
  addTearDown(controller.dispose);
  // As in the app: the session screen sits in a Scaffold + SafeArea
  // (`SessionFlowScreen`).
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(
        body: SafeArea(
          child: ListenableBuilder(
            listenable: controller,
            builder: (context, _) =>
                SessionScreen(controller: controller, effects: effects),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

/// Every key: the cell that takes the tap, then the visible key inside it
/// (`left, top, width, height`). Rows of 75, cells of a third of the width,
/// a 4 px margin around each key.
final _keys = {
  Size(412, 915): {
    '1': (0.0, 615.0, 137.3),
    '2': (137.3, 615.0, 137.3),
    '3': (274.7, 615.0, 137.3),
    '4': (0.0, 690.0, 137.3),
    '5': (137.3, 690.0, 137.3),
    '6': (274.7, 690.0, 137.3),
    '7': (0.0, 765.0, 137.3),
    '8': (137.3, 765.0, 137.3),
    '9': (274.7, 765.0, 137.3),
    'backspace': (0.0, 840.0, 137.3),
    '0': (137.3, 840.0, 137.3),
    'submit': (274.7, 840.0, 137.3),
  },
  Size(360, 640): {
    '1': (0.0, 340.0, 120.0),
    '2': (120.0, 340.0, 120.0),
    '3': (240.0, 340.0, 120.0),
    '4': (0.0, 415.0, 120.0),
    '5': (120.0, 415.0, 120.0),
    '6': (240.0, 415.0, 120.0),
    '7': (0.0, 490.0, 120.0),
    '8': (120.0, 490.0, 120.0),
    '9': (240.0, 490.0, 120.0),
    'backspace': (0.0, 565.0, 120.0),
    '0': (120.0, 565.0, 120.0),
    'submit': (240.0, 565.0, 120.0),
  },
};
const _keyHeight = 75.0;
const _keyMargin = 4.0;

/// The question's centre, the same for every operation; the empty answer
/// field's top and height, per operation (a taller prompt — a root's bar,
/// a raised exponent — pushes it down by half a pixel or two).
final _questionCentre = {
  Size(412, 915): (206.0, 319.0),
  Size(360, 640): (180.0, 181.5),
};
final _answer = {
  Size(412, 915): {
    'addition': (206.0, 371.0),
    'power': (206.0, 371.5),
    'root': (206.0, 373.0),
    'percent': (206.0, 371.0),
  },
  Size(360, 640): {
    'addition': (180.0, 233.5),
    'power': (180.0, 234.0),
    'root': (180.0, 235.5),
    'percent': (180.0, 233.5),
  },
};
const _answerHeight = 41.0;

const _prompts = <String, Exercise>{
  'addition': _addition,
  'power': PowerExercise(base: 7, exponent: 2),
  'root': SquareRootExercise(radicand: 169),
  'percent': PercentageExercise(percent: 25, base: 80),
};

/// Measured to a tenth of a pixel; the tolerance only absorbs rounding.
Matcher _near(double v) => closeTo(v, 0.06);

/// Throws on every call, and notes what the controller already knew.
class _ThrowingEffects implements SessionEffects {
  final List<String> calls = [];
  late SessionController controller;

  void _note(String what) {
    calls.add('$what after ${controller.state.outcomes.length} answers');
    throw StateError('effect failed: $what');
  }

  @override
  void keyPressed() => _note('key');

  @override
  void answered({required bool correct, required int streak}) =>
      _note('answered');

  @override
  void timedOut() => _note('timeout');
}

void main() {
  setUpAll(loadInterFontForGoldens);

  for (final (themeName, theme) in [
    ('dark', buildDarkTheme()),
    ('light', buildLightTheme()),
  ]) {
    for (final size in _keys.keys) {
      testWidgets('keypad geometry, $themeName, ${size.width.toInt()}×'
          '${size.height.toInt()}', (tester) async {
        await _pump(tester, size: size, theme: theme);
        for (final MapEntry(key: name, value: (left, top, width))
            in _keys[size]!.entries) {
          final cell = tester.getRect(find.byKey(keypadKeyKey(name)));
          expect(cell.left, _near(left), reason: '$name left');
          expect(cell.top, _near(top), reason: '$name top');
          expect(cell.width, _near(width), reason: '$name width');
          expect(cell.height, _near(_keyHeight), reason: '$name height');
          final surface = tester.getRect(
            find
                .descendant(
                  of: find.byKey(keypadKeyKey(name)),
                  matching: find.byType(DecoratedBox),
                )
                .first,
          );
          expect(surface, cell.deflate(_keyMargin), reason: '$name surface');
        }
      });

      testWidgets('question and answer positions, $themeName, '
          '${size.width.toInt()}×${size.height.toInt()}', (tester) async {
        for (final MapEntry(key: name, value: exercise) in _prompts.entries) {
          await _pump(tester, size: size, theme: theme, exercises: [exercise]);
          final question = tester.getRect(find.byKey(sessionQuestionKey));
          final (cx, cy) = _questionCentre[size]!;
          expect(question.center.dx, _near(cx), reason: '$name question x');
          expect(question.center.dy, _near(cy), reason: '$name question y');
          final answer = tester.getRect(find.byKey(sessionAnswerKey));
          final (ax, atop) = _answer[size]![name]!;
          expect(answer.center.dx, _near(ax), reason: '$name answer x');
          expect(answer.top, _near(atop), reason: '$name answer top');
          expect(answer.height, _near(_answerHeight), reason: '$name answer h');
        }
      });
    }
  }

  testWidgets('effects never hold back the next question, even when they '
      'fail', (tester) async {
    const next = ArithmeticExercise(
      operandA: 2,
      operandB: 2,
      operationType: OperationType.addition,
    );
    final effects = _ThrowingEffects();
    final controller = await _pump(
      tester,
      size: const Size(412, 915),
      theme: buildDarkTheme(),
      exercises: const [_addition, next],
      effects: effects,
    );
    effects.controller = controller;

    await tester.tap(find.byKey(keypadKeyKey('8')));
    await tester.tap(find.byKey(keypadKeyKey('5')));
    await tester.tap(find.byKey(keypadKeyKey('submit')));
    // One frame: the next question is already there (the switch to it only
    // fades, `AppMotion.questionTransition`).
    await tester.pump();

    expect(controller.state.outcomes.single.isCorrect, isTrue);
    expect(controller.state.currentExercise, next);
    expect(find.byKey(const ValueKey<Exercise>(next)), findsOneWidget);
    // Every effect ran after the controller had recorded the answer, and
    // its failure changed nothing.
    expect(effects.calls, [
      'key after 0 answers',
      'key after 0 answers',
      'answered after 1 answers',
    ]);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<Exercise>(_addition)), findsNothing);
  });

  testWidgets('a wrong answer pauses exactly the correction delay, effects '
      'or not', (tester) async {
    final effects = _ThrowingEffects();
    final controller = await _pump(
      tester,
      size: const Size(412, 915),
      theme: buildDarkTheme(),
      exercises: const [_addition, _addition],
      effects: effects,
      correctionDelay: SessionController.defaultCorrectionDelay,
    );
    effects.controller = controller;

    await tester.tap(find.byKey(keypadKeyKey('1')));
    await tester.tap(find.byKey(keypadKeyKey('submit')));
    await tester.pump();

    expect(controller.state.isCorrecting, isTrue);
    expect(
      SessionController.defaultCorrectionDelay,
      const Duration(seconds: 1),
    );
    expect(
      SessionController.defaultQuestionTimeout,
      const Duration(seconds: 15),
    );
    expect(effects.calls.last, 'answered after 1 answers');
  });
}
