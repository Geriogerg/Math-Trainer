import 'dart:math';

import 'package:math_core/leveling/level_rules.dart';
import 'package:test/test.dart';

import '../../tool/src/levels_simulation.dart';

SimulatedPlayer _player(String name) =>
    simulatedPlayers.firstWhere((p) => p.name == name);

void main() {
  group('rules v3 meets the plan v3.2 targets (Levels close-out)', () {
    test('every target met: stall in 60–70 %, slow 4 ≥ +1.5, full caps, '
        'never below −3', () {
      final targets = targetsFor(LevelRules.v3);
      expect(targets, hasLength(4));
      for (final t in targets) {
        expect(t.met, isTrue, reason: '${t.target}: ${t.measured}');
      }
    });

    test('the stall, exactly: 65.3 / 63.8 / 64.0 / 64.2 % correct at '
        '4 / 5 / 10 / 20 questions (fluent players)', () {
      expect(
        [
          for (final n in questionCounts)
            stallAccuracyPercent(LevelRules.v3, questions: n),
        ],
        [65.3, 63.8, 64.0, 64.2],
      );
    });

    test('v2 missed it: the stall at ~54 %, slow 4 at +1.2 — the Levels '
        'outcome finding', () {
      final targets = targetsFor(LevelRules.v2);
      expect([for (final t in targets) t.met], [false, false, true, true]);
      expect(
        stallAccuracyPercent(LevelRules.v2, questions: 10),
        closeTo(54.4, 0.05),
      );
    });

    test('the expected change crosses zero once: down below the stall, up '
        'above', () {
      for (final n in questionCounts) {
        final stall = stallAccuracyPercent(LevelRules.v3, questions: n)!;
        double at(double p) =>
            expectedChange(LevelRules.v3, questions: n, accuracy: p);
        expect(at(stall / 100 - 0.02), lessThan(0));
        expect(at(stall / 100 + 0.02), greaterThan(0));
        expect(at(0), -3);
        expect(at(1), LevelRules.v3.capUpFor(n));
      }
    });
  });

  group('the grind, simulated under v3', () {
    test("a perfect player matches the spec's grind estimate: T2 (level 20) "
        'in 5 games, level 50 in 13', () {
      final reached = gamesToTiers(
        _player('perfect'),
        random: Random(1),
        rules: LevelRules.v3,
      );
      expect(reached[1], 5);
      expect(reached[4], 13);
    });

    test('a correct-but-slow player climbs, slower than a perfect one, '
        'faster than under v2', () {
      int? toT5(String name, LevelRules rules) =>
          gamesToTiers(_player(name), random: Random(1), rules: rules)[4];
      final perfect = toT5('perfect', LevelRules.v3)!;
      final slow = toT5('perfect, slow', LevelRules.v3)!;
      expect(slow, greaterThan(perfect));
      expect(slow, lessThan(toT5('perfect, slow', LevelRules.v2)!));
    });

    test('a 70 % player climbs; a 60 % player stays at 0 (median, 101 '
        'runs)', () {
      final seventy = medianGamesToTiers(
        _player('70 %'),
        rules: LevelRules.v3,
        runs: 101,
      );
      final sixty = medianGamesToTiers(
        _player('60 %'),
        rules: LevelRules.v3,
        runs: 101,
      );
      expect(seventy[4], isNotNull);
      expect(sixty[1], isNull);
    });
  });
}
