import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:math_core/challenges/challenge_stats.dart';
import 'package:math_core/challenges/count.dart';
import 'package:math_trainer/core/state/count_controller.dart';
import 'package:math_trainer/presentation/screens/count_screen.dart';
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

/// Seed 1 (pinned in the core): 100 9 6 2 8 2 → 817; the solver's way:
/// 100 × 8 = 800, + 2, + 6, + 9.
void main() {
  setUpAll(loadInterFontForGoldens);

  late List<_Timer> timers;
  late _Stats stats;
  var now = DateTime(2026);

  CountController controller() => CountController(
    seed: 1,
    statsStore: stats,
    clock: () => now,
    createTimer: (duration, callback) {
      final timer = _Timer(callback);
      timers.add(timer);
      return timer;
    },
  );

  void tick() => timers.last.callback();

  setUp(() {
    timers = [];
    stats = _Stats();
    now = DateTime(2026);
  });

  /// Plays the solver's own solution, tile by tile.
  void solve(CountController c) {
    void move(int a, CountOperator op, int b) {
      c.tapTile(a);
      c.tapOperator(op);
      c.tapTile(b);
    }

    // Tiles: 0:100 1:9 2:6 3:2 4:8 5:2; a result takes the second's id+.
    move(0, CountOperator.multiply, 4); // 800, id 6 in place 4
    move(6, CountOperator.add, 3); // 802, id 7 in place 3
    move(7, CountOperator.add, 2); // 808, id 8 in place 2
    move(8, CountOperator.add, 1); // 817, id 9 in place 1
  }

  group('CountController', () {
    test('playing the solution solves the round, with its time', () async {
      final c = controller()..start();
      now = now.add(const Duration(seconds: 12));
      solve(c);
      expect(c.solved, isTrue);
      expect(c.ended, isTrue);
      expect(c.elapsedMs, 12000);
      await c.pendingStats;
      expect(
        stats.saved[Challenge.getTheCount],
        const ChallengeStats(games: 1, solved: 1, bestTimeMs: 12000),
      );
    });

    test('45 seconds, then the round ends unsolved', () async {
      final c = controller()..start();
      for (var i = 0; i < 44; i++) {
        tick();
      }
      expect((c.ended, c.remainingSeconds), (false, 1));
      tick();
      expect((c.ended, c.solved), (true, false));
      await c.pendingStats;
      expect(stats.saved[Challenge.getTheCount]!.games, 1);
      expect(stats.saved[Challenge.getTheCount]!.solved, 0);
    });

    test('a forbidden move drops the operator, keeps the first tile', () {
      final c = controller()..start();
      c.tapTile(1); // 9
      c.tapOperator(CountOperator.divide);
      c.tapTile(4); // 9 ÷ 8: inexact
      expect(c.first, 1);
      expect(c.operator, isNull);
      expect(c.board.canUndo, isFalse);
    });

    test('undo and reset', () {
      final c = controller()..start();
      c.tapTile(0);
      c.tapOperator(CountOperator.multiply);
      c.tapTile(4);
      expect(c.board.canUndo, isTrue);
      c.undo();
      expect(c.board.tiles.every((t) => !t.used), isTrue);
      solve(c);
    });
  });

  Future<CountController> pumpScreen(
    WidgetTester tester,
    ThemeData theme,
  ) async {
    await setGoldenSurfaceSize(tester);
    final c = controller()..start();
    addTearDown(c.dispose);
    await tester.pumpWidget(
      MaterialApp(
        locale: testLocale,
        supportedLocales: testLocales,
        localizationsDelegates: testLocalizations,
        debugShowCheckedModeBanner: false,
        theme: theme,
        home: Scaffold(
          body: SafeArea(
            child: ListenableBuilder(
              listenable: c,
              builder: (context, _) => CountScreen(
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

  testWidgets('taps on tiles and operators play the round', (tester) async {
    await pumpScreen(tester, buildDarkTheme());
    expect(find.text('817'), findsOneWidget);
    expect(find.text('0:45'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('count-tile-0')));
    await tester.pump();
    await tester.tap(find.text('×'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('count-tile-4')));
    await tester.pump();
    expect(find.text('800'), findsOneWidget);
  });

  for (final (name, theme) in [
    ('light', buildLightTheme()),
    ('dark', buildDarkTheme()),
  ]) {
    testWidgets('get the count golden — $name', (tester) async {
      final c = await pumpScreen(tester, theme);
      for (var i = 0; i < 14; i++) {
        tick();
      }
      c.tapTile(0);
      c.tapOperator(CountOperator.multiply);
      c.tapTile(4);
      c.tapTile(6); // 800, picked
      await tester.pump();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/count_$name.png'),
      );
    });

    testWidgets('get the count correction golden — $name', (tester) async {
      await pumpScreen(tester, theme);
      for (var i = 0; i < 45; i++) {
        tick();
      }
      await tester.pump();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/count_correction_$name.png'),
      );
    });
  }

  testWidgets('get the count — French, 360 px', (tester) async {
    useFrench();
    final c = await pumpScreen(tester, buildLightTheme());
    for (var i = 0; i < 14; i++) {
      tick();
    }
    c.tapTile(0);
    c.tapOperator(CountOperator.multiply);
    c.tapTile(4);
    c.tapTile(6);
    await expectFrenchAt360(tester, 'count', settle: false);
  });

  testWidgets('get the count correction — French, 360 px', (tester) async {
    useFrench();
    await pumpScreen(tester, buildLightTheme());
    for (var i = 0; i < 45; i++) {
      tick();
    }
    await expectFrenchAt360(tester, 'count_correction', settle: false);
  });
}
