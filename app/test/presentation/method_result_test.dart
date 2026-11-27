import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:math_core/generation/exercise_source.dart';
import 'package:math_core/leveling/level.dart';
import 'package:math_core/models/exercise.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/models/operation_type.dart';
import 'package:math_core/patterns/pattern_family.dart';
import 'package:math_core/models/session_config.dart';
import 'package:math_core/persistence/in_memory_session_repository.dart';
import 'package:math_core/strategies/strategy.dart';
import 'package:math_trainer/core/state/session_controller.dart';
import 'package:math_trainer/presentation/screens/result_screen.dart';
import 'package:math_trainer/presentation/screens/tips_view.dart';
import 'package:math_trainer/presentation/theme/app_theme.dart';
import 'package:math_trainer/presentation/strings/tips.dart';
import 'package:math_trainer/presentation/strings/strings.dart';

import 'golden_test_utils.dart';

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

/// A finished game: 17 × 23 answered wrong, 12 + 9 right, 3⁴ timed out.
Future<SessionController> _finished() async {
  final exercises = <Exercise>[
    ArithmeticExercise(
      operandA: 17,
      operandB: 23,
      operationType: OperationType.multiplication,
    ),
    ArithmeticExercise(
      operandA: 12,
      operandB: 9,
      operationType: OperationType.addition,
    ),
    PowerExercise(base: 3, exponent: 4),
  ];
  void Function()? timeout;
  final controller = SessionController(
    config: SessionConfig(
      seed: 1,
      enabledTypes: const {
        ExerciseType.addition,
        ExerciseType.multiplication,
        ExerciseType.power,
      },
      exerciseCount: exercises.length,
      levels: {
        ExerciseType.addition: Level.whole(52),
        ExerciseType.multiplication: Level.whole(52),
        ExerciseType.power: Level.whole(52),
      },
    ),
    exerciseSource: _FixedExerciseSource(exercises),
    repository: InMemorySessionRepository(),
    playerId: 'method-player',
    clock: () => DateTime(2026),
    createTimer: (duration, callback) {
      timeout = callback;
      return _InertTimer();
    },
  );
  controller.start();
  controller.submitAnswer(381); // 17 × 23 = 391: wrong
  controller.submitAnswer(21); // right
  timeout!(); // 3⁴: timed out
  await controller.pendingPersistence;
  return controller;
}

/// Scrolls [finder] into view, then taps it.
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _pump(
  WidgetTester tester,
  SessionController controller, {
  bool showMethods = true,
  void Function(ExerciseType type, Tip? tip)? onMoreTips,
  ThemeData? theme,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: testLocale,
      supportedLocales: testLocales,
      localizationsDelegates: testLocalizations,
      theme: theme ?? buildLightTheme(),
      home: Scaffold(
        body: ResultScreen(
          controller: controller,
          onPlayAgain: () {},
          onExitToSelection: () {},
          isRestarting: false,
          restartError: null,
          showMethods: showMethods,
          onMoreTips: onMoreTips,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The panel's text, lines included, as one string per Text.rich.
List<String> _texts(WidgetTester tester) => [
  for (final t in tester.widgetList<Text>(find.byType(Text)))
    t.textSpan?.toPlainText(includePlaceholders: false) ?? t.data ?? '',
];

void main() {
  setUpAll(loadInterFontForGoldens);

  testWidgets('a Method button under each wrong answer and timeout; none '
      'under a right answer', (tester) async {
    final controller = await _finished();
    addTearDown(controller.dispose);
    await _pump(tester, controller);
    expect(find.text('Method'), findsNWidgets(2));
  });

  testWidgets('a missed 17 × 23 opens in place on (20 − 3)(20 + 3), the '
      "strategy's name first; More tips names the operation", (tester) async {
    final controller = await _finished();
    addTearDown(controller.dispose);
    ExerciseType? tipsFor;
    Tip? tip;
    await _pump(
      tester,
      controller,
      onMoreTips: (t, linked) {
        tipsFor = t;
        tip = linked;
      },
    );
    await _tap(tester, find.text('Method').first);
    expect(find.text('Difference of squares'), findsOneWidget);
    expect(find.text('Hide method'), findsOneWidget);
    final texts = _texts(tester);
    expect(texts, contains('= (20 − 3)(20 + 3)'));
    expect(texts, contains('= 400 − 9'));
    expect(texts, contains('= 391'));
    await _tap(tester, find.text('More tips'));
    expect(tipsFor, ExerciseType.multiplication);
    expect(tip?.strategy, Strategy.differenceOfSquares);
    await _tap(tester, find.text('Hide method'));
    expect(find.text('Difference of squares'), findsNothing);
  });

  testWidgets('without Methods (Tables mode): no button', (tester) async {
    final controller = await _finished();
    addTearDown(controller.dispose);
    await _pump(tester, controller, showMethods: false);
    expect(find.text('Method'), findsNothing);
  });

  testWidgets('the Tips page opens at the tip a Method followed, marked', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final tip = tips.firstWhere(
      (t) => t.families.contains(PatternFamily.twoXDifferenceOfSquares),
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: testLocale,
        supportedLocales: testLocales,
        localizationsDelegates: testLocalizations,
        theme: buildLightTheme(),
        home: Scaffold(
          body: TipsView(
            focus: ExerciseType.integral,
            focusTip: tip,
            levelOf: (_) => Level.zero,
            onBack: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final at = tester.getTopLeft(find.text(tip.text));
    expect(at.dy, inInclusiveRange(0, 640));
    // The Back button's arrow and the mark's.
    expect(find.byIcon(Icons.arrow_back), findsNWidgets(2));
  });

  testWidgets('the Tips page opens at the section asked for', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        locale: testLocale,
        supportedLocales: testLocales,
        localizationsDelegates: testLocalizations,
        theme: buildLightTheme(),
        home: Scaffold(
          body: TipsView(
            focus: ExerciseType.integral,
            levelOf: (_) => Level.zero,
            onBack: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final heading = tester.getTopLeft(find.text('Integrals'));
    expect(heading.dy, inInclusiveRange(0, 200));
  });

  for (final mode in [
    (name: 'light', theme: buildLightTheme()),
    (name: 'dark', theme: buildDarkTheme()),
  ]) {
    testWidgets('result screen with a Method open — ${mode.name}', (
      tester,
    ) async {
      await setGoldenSurfaceSize(tester);
      final controller = await _finished();
      addTearDown(controller.dispose);
      await _pump(tester, controller, theme: mode.theme, onMoreTips: (_, _) {});
      await _tap(tester, find.text('Method').first);
      await expectLater(
        find.byType(ResultScreen),
        matchesGoldenFile('goldens/result_screen_method_${mode.name}.png'),
      );
    });
  }

  testWidgets('result screen with a Method open — French, 360 px', (
    tester,
  ) async {
    useFrench();
    final controller = await _finished();
    addTearDown(controller.dispose);
    await _pump(tester, controller, onMoreTips: (_, _) {});
    await _tap(tester, find.text(strings.game.method).first);
    await expectFrenchAt360(tester, 'result_method', height: 1400);
  });
}
