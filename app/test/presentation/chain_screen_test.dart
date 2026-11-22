import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:math_core/challenges/chain.dart';
import 'package:math_core/challenges/challenge_stats.dart';
import 'package:math_trainer/core/state/chain_controller.dart';
import 'package:math_trainer/presentation/kit/numeric_keypad.dart';
import 'package:math_trainer/presentation/screens/chain_screen.dart';
import 'package:math_trainer/presentation/theme/app_theme.dart';

import 'golden_test_utils.dart';

class _Stats implements ChallengeStatsStore {
  final saved = <Challenge, ChallengeStats>{};

  @override
  Future<ChallengeStats> load(Challenge c) async =>
      saved[c] ?? ChallengeStats.none;

  @override
  Future<void> save(Challenge c, ChallengeStats stats) async =>
      saved[c] = stats;
}

class _Timer implements Timer {
  _Timer(this.callback);
  final void Function() callback;
  bool cancelled = false;
  @override
  void cancel() => cancelled = true;
  @override
  bool get isActive => !cancelled;
  @override
  int get tick => 0;
}

/// 19 + 1 − 7 × 9 − 8 − 7 = 102 (pinned in the core).
final _chain = generateChain(seed: 42, operations: 5);

void main() {
  setUpAll(loadInterFontForGoldens);

  late List<_Timer> timers;
  late _Stats stats;
  var now = DateTime(2026);

  ChainController controller() => ChainController(
    chain: _chain,
    secondsPerScreen: 2,
    statsStore: stats,
    clock: () => now,
    createTimer: (duration, callback) {
      final timer = _Timer(callback);
      timers.add(timer);
      return timer;
    },
  );

  /// Fires the latest timer: the end of a screen or of a blank.
  void fire() => timers.last.callback();

  setUp(() {
    timers = [];
    stats = _Stats();
    now = DateTime(2026);
  });

  group('ChainController', () {
    test('screen, blank, screen … then the keypad', () {
      final c = controller()..start();
      expect((c.phase, c.screen), (ChainPhase.showing, 0));
      fire();
      expect(c.phase, ChainPhase.blank);
      fire();
      expect((c.phase, c.screen), (ChainPhase.showing, 1));
      for (var i = 0; i < 8; i++) {
        fire();
      }
      expect((c.phase, c.screen), (ChainPhase.showing, 5));
      fire();
      expect(c.phase, ChainPhase.answering);
    });

    test('the answer: solved, its time, and the stats', () async {
      final c = controller()..start();
      for (var i = 0; i < 11; i++) {
        fire();
      }
      now = now.add(const Duration(milliseconds: 3200));
      c.submit(102);
      await c.pendingStats;
      expect(c.solved, isTrue);
      expect(c.elapsedMs, 3200);
      expect(
        stats.saved[Challenge.chainOperations],
        const ChallengeStats(games: 1, solved: 1, bestTimeMs: 3200),
      );
    });

    test('keys before the keypad are ignored', () {
      final c = controller()..start();
      c.submit(102);
      expect(c.phase, ChainPhase.showing);
    });

    test('seconds per screen outside the choices throw', () {
      expect(
        () => ChainController(
          chain: _chain,
          secondsPerScreen: 4,
          statsStore: stats,
        ),
        throwsArgumentError,
      );
    });
  });

  Future<ChainController> pumpScreen(
    WidgetTester tester,
    ThemeData theme,
  ) async {
    await setGoldenSurfaceSize(tester);
    final c = controller()..start();
    addTearDown(c.dispose);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        home: Scaffold(
          body: SafeArea(
            child: ListenableBuilder(
              listenable: c,
              builder: (context, _) => ChainScreen(
                controller: c,
                onQuit: () {},
                onPlayAgain: () {},
                onHome: () {},
              ),
            ),
          ),
        ),
      ),
    );
    return c;
  }

  testWidgets('one operation per screen, then the keypad, then the chain', (
    tester,
  ) async {
    await pumpScreen(tester, buildDarkTheme());
    expect(find.text('19'), findsOneWidget);
    expect(find.text('0 / 5'), findsOneWidget);
    fire(); // blank
    await tester.pump();
    expect(find.text('19'), findsNothing);
    fire();
    await tester.pump();
    expect(find.text('+ 1'), findsOneWidget);
    expect(find.text('1 / 5'), findsOneWidget);
    for (var i = 0; i < 9; i++) {
      fire();
    }
    await tester.pump();
    expect(find.byKey(keypadKeyKey('submit')), findsOneWidget);

    for (final d in ['1', '0', '2']) {
      await tester.tap(find.byKey(keypadKeyKey(d)));
    }
    await tester.tap(find.byKey(keypadKeyKey('submit')));
    await tester.pump();
    // The correction: the answer and every line of the chain.
    expect(find.text('102'), findsOneWidget);
    expect(find.text('× 9 = 117'), findsOneWidget);
    expect(find.text('Play again'), findsOneWidget);
  });

  for (final (name, theme) in [
    ('light', buildLightTheme()),
    ('dark', buildDarkTheme()),
  ]) {
    testWidgets('chain golden — $name', (tester) async {
      await pumpScreen(tester, theme);
      for (var i = 0; i < 8; i++) {
        fire();
      }
      await tester.pump();
      // Screen 4 of 5: "− 8".
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/chain_$name.png'),
      );
    });

    testWidgets('chain correction golden — $name', (tester) async {
      final c = await pumpScreen(tester, theme);
      for (var i = 0; i < 11; i++) {
        fire();
      }
      c.submit(98);
      await tester.pump();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/chain_correction_$name.png'),
      );
    });
  }
}
