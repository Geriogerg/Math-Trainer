import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:math_core/generation/exercise_source.dart';
import 'package:math_core/leveling/level.dart';
import 'package:math_core/leveling/level_cache_orchestrator.dart';
import 'package:math_core/models/answer_result.dart';
import 'package:math_core/models/exercise.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/models/input_device.dart';
import 'package:math_core/models/operation_type.dart';
import 'package:math_core/models/session_config.dart';
import 'package:math_core/persistence/in_memory_session_repository.dart';
import 'package:math_core/persistence/level_cache_entry.dart';
import 'package:math_core/persistence/session_repository.dart';
import 'package:math_trainer/core/effects/session_effects.dart';
import 'package:math_trainer/core/state/session_controller.dart';
import 'package:math_trainer/presentation/screens/result_screen.dart';
import 'package:math_trainer/presentation/screens/session_screen.dart';
import 'package:math_trainer/presentation/streak_tier.dart';
import 'package:math_trainer/presentation/theme/app_theme.dart';

/// Phase 5 commit 6: the streak intensifies at 5, 10, 20; the level-up
/// has its moment; reduced motion is respected.
class _Ones extends ExerciseSource {
  @override
  Exercise next() => const ArithmeticExercise(
    operandA: 1,
    operandB: 1,
    operationType: OperationType.addition,
  );
}

class _InertTimer implements Timer {
  @override
  void cancel() {}

  @override
  bool get isActive => false;

  @override
  int get tick => 0;
}

/// Raises addition to [to], whatever the answers.
class _RaisedLevels implements SessionLevelUpdates {
  _RaisedLevels(this.to);

  final Level to;

  @override
  Future<Map<ExerciseType, LevelCacheEntry>> computeUpdates({
    required List<AnswerResult> outcomes,
    required Map<ExerciseType, Level> frozenLevels,
    required SessionRepository repository,
    required String playerId,
    required DateTime now,
  }) async => {
    ExerciseType.addition: LevelCacheEntry(
      level: to,
      sessionsPlayed: 4,
      updatedAt: now,
    ),
  };
}

class _CountingEffects implements SessionEffects {
  int levelUps = 0;

  @override
  void keyPressed(InputDevice device) {}

  @override
  void answered({required bool correct, required int streak}) {}

  @override
  void timedOut() {}

  @override
  void levelUp() => levelUps++;
}

SessionController _controller({int count = 30, SessionLevelUpdates? levels}) =>
    SessionController(
      config: SessionConfig(
        seed: 1,
        enabledTypes: const {ExerciseType.addition},
        exerciseCount: count,
        levels: {ExerciseType.addition: Level.whole(12)},
      ),
      exerciseSource: _Ones(),
      repository: InMemorySessionRepository(),
      playerId: 'test-player',
      clock: () => DateTime(2026),
      createTimer: (duration, callback) => _InertTimer(),
      levelCacheOrchestrator: levels,
    )..start();

Widget _app(Widget child, {bool reducedMotion = false}) => MaterialApp(
  theme: buildDarkTheme(),
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reducedMotion),
    child: Scaffold(body: child),
  ),
);

void main() {
  test('tiers start at 5, 10 and 20 in a row', () {
    expect([0, 4, 5, 9, 10, 19, 20, 99].map(streakTier), [
      0, 0, 1, 1, 2, 2, 3, 3, //
    ]);
  });

  test('each tier changes the colours, both themes', () {
    for (final theme in [buildDarkTheme(), buildLightTheme()]) {
      final bars = {for (var t = 0; t <= 3; t++) timerBarColor(theme, t)};
      final words = {for (var t = 0; t <= 2; t++) streakTextColor(theme, t)};
      expect(bars, hasLength(4));
      expect(words, hasLength(3));
      expect(timerBarColor(theme, 0), theme.colorScheme.primary);
    }
  });

  Future<SessionController> pumpSession(
    WidgetTester tester, {
    bool reducedMotion = false,
  }) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _app(
        ListenableBuilder(
          listenable: controller,
          builder: (context, _) => SessionScreen(controller: controller),
        ),
        reducedMotion: reducedMotion,
      ),
    );
    return controller;
  }

  double streakScale(WidgetTester tester) => tester
      .widget<ScaleTransition>(
        find.ancestor(
          of: find.byKey(sessionStreakLineKey),
          matching: find.byType(ScaleTransition),
        ),
      )
      .scale
      .value;

  testWidgets('the fifth right answer in a row: the streak steps up its '
      'colour and pulses once', (tester) async {
    final controller = await pumpSession(tester);
    for (var i = 0; i < 4; i++) {
      controller.submitAnswer(2);
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(streakScale(tester), 1);

    controller.submitAnswer(2);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(streakScale(tester), greaterThan(1.05));
    await tester.pumpAndSettle();
    expect(streakScale(tester), 1);

    final line = tester.widget<Text>(find.byKey(sessionStreakLineKey));
    final streakSpan = (line.textSpan! as TextSpan).children!.last as TextSpan;
    expect(streakSpan.text, ' · streak 5');
    expect(streakSpan.style!.color, streakTextColor(buildDarkTheme(), 1));
  });

  testWidgets('reduced motion: the colour still steps, no pulse', (
    tester,
  ) async {
    final controller = await pumpSession(tester, reducedMotion: true);
    for (var i = 0; i < 5; i++) {
      controller.submitAnswer(2);
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 120));
    expect(streakScale(tester), 1);
    final line = tester.widget<Text>(find.byKey(sessionStreakLineKey));
    final streakSpan = (line.textSpan! as TextSpan).children!.last as TextSpan;
    expect(streakSpan.style!.color, streakTextColor(buildDarkTheme(), 1));
  });

  test('leveledUp: only a whole level gained counts', () {
    final before = {ExerciseType.addition: Level.fromHundredths(1290)};
    LevelCacheEntry at(int hundredths) => LevelCacheEntry(
      level: Level.fromHundredths(hundredths),
      sessionsPlayed: 1,
      updatedAt: DateTime.utc(2026),
    );
    expect(leveledUp(before, null), isFalse);
    expect(leveledUp(before, {ExerciseType.addition: at(1299)}), isFalse);
    expect(leveledUp(before, {ExerciseType.addition: at(1300)}), isTrue);
    expect(leveledUp(before, {ExerciseType.addition: at(1100)}), isFalse);
  });

  Future<_CountingEffects> pumpResult(
    WidgetTester tester, {
    required Level to,
    bool reducedMotion = false,
  }) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _controller(count: 1, levels: _RaisedLevels(to));
    addTearDown(controller.dispose);
    controller.submitAnswer(2);
    await tester.runAsync(() => controller.pendingPersistence);
    final effects = _CountingEffects();
    await tester.pumpWidget(
      _app(
        ListenableBuilder(
          listenable: controller,
          builder: (context, _) => ResultScreen(
            controller: controller,
            onPlayAgain: () {},
            onExitToSelection: () {},
            isRestarting: false,
            restartError: null,
            effects: effects,
          ),
        ),
        reducedMotion: reducedMotion,
      ),
    );
    return effects;
  }

  testWidgets('a level gained: the count-up, "Level up", its sound once', (
    tester,
  ) async {
    final effects = await pumpResult(tester, to: Level.whole(13));
    expect(effects.levelUps, 1);
    expect(find.text('▲ Level up'), findsNothing); // still counting up
    await tester.pumpAndSettle();
    expect(find.text('Addition — level 13'), findsOneWidget);
    expect(find.text('▲ Level up'), findsOneWidget);
    // Rebuilds never replay it.
    await tester.pump(const Duration(seconds: 1));
    expect(effects.levelUps, 1);
  });

  testWidgets('no whole level gained: no mark, no sound', (tester) async {
    final effects = await pumpResult(tester, to: Level.fromHundredths(1250));
    await tester.pumpAndSettle();
    expect(find.text('▲ Level up'), findsNothing);
    expect(effects.levelUps, 0);
  });

  testWidgets('reduced motion: the final level at once', (tester) async {
    await pumpResult(tester, to: Level.whole(13), reducedMotion: true);
    await tester.pump();
    expect(find.text('Addition — level 13'), findsOneWidget);
    expect(find.text('▲ Level up'), findsOneWidget);
  });
}
