import 'dart:math';

import 'package:math_core/leveling/level_rules.dart';
import 'package:math_core/leveling/rules_version.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/tiers/tier.dart';
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

  group('rules v4 (Patterns and Method commit 5)', () {
    test("v4's level update is v3's: the four targets still met", () {
      final v4 = LevelRules.of(RulesVersion.v4);
      expect(v4, same(LevelRules.v3));
      for (final t in targetsFor(v4)) {
        expect(t.met, isTrue, reason: '${t.target}: ${t.measured}');
      }
    });

    test('pattern questions served per tier: 2 in 5 of the questions drawn '
        'where families exist, reviews included (within 2 points)', () {
      for (final type in ExerciseType.values) {
        for (final tier in Tier.values) {
          final served = sharesServed(
            type,
            tier,
            rules: RulesVersion.v4,
            games: 400,
          ).patterns;
          expect(
            served,
            closeTo(
              patternShareExpected(type, tier, rules: RulesVersion.v4),
              0.02,
            ),
            reason: '${type.name} ${tier.label}',
          );
        }
      }
      // From the second tier with families on: ~40 %.
      expect(
        patternShareExpected(
          ExerciseType.multiplication,
          Tier.t5,
          rules: RulesVersion.v4,
        ),
        closeTo(0.4, 1e-9),
      );
      expect(
        patternShareExpected(
          ExerciseType.addition,
          Tier.t0,
          rules: RulesVersion.v4,
        ),
        0,
      );
    });
  });

  group('rules v5 and v6 (pattern questions sized by tier, no reviews)', () {
    test("v5's level update is v3's: the four targets still met", () {
      final v5 = LevelRules.of(RulesVersion.v5);
      expect(v5, same(LevelRules.v3));
      for (final t in targetsFor(v5)) {
        expect(t.met, isTrue, reason: '${t.target}: ${t.measured}');
      }
    });

    test('served per tier: 2 in 5 pattern questions wherever a family '
        'exists — its first tier included — and none from a lower tier', () {
      for (final type in ExerciseType.values) {
        for (final tier in Tier.values) {
          final served = sharesServed(
            type,
            tier,
            rules: RulesVersion.v6,
            games: 400,
          );
          final reason = '${type.name} ${tier.label}';
          expect(
            served.patterns,
            closeTo(
              patternShareExpected(type, tier, rules: RulesVersion.v6),
              0.02,
            ),
            reason: reason,
          );
          expect(served.lowerTier, 0, reason: reason);
        }
      }
      // The first tier with families (T1 for addition): 40 %, no longer
      // diluted by reviews from a tier without families.
      expect(
        patternShareExpected(
          ExerciseType.addition,
          Tier.t1,
          rules: RulesVersion.v6,
        ),
        closeTo(0.4, 1e-9),
      );
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

  group('rules v7 (Phase 4: weak spots in Levelling games)', () {
    test("v7's level update is v3's: the four targets still met", () {
      final v7 = LevelRules.of(RulesVersion.v7);
      expect(v7, same(LevelRules.v3));
      for (final t in targetsFor(v7)) {
        expect(t.met, isTrue, reason: '${t.target}: ${t.measured}');
      }
    });

    test('weak spots served: never above 20 % of a game, never off the '
        'current tier, and served where the tier has items', () {
      for (final type in ExerciseType.values) {
        for (final tier in Tier.values) {
          final w = weakSpotsServed(type, tier, games: 120);
          final reason = '${type.name} ${tier.label}';
          expect(w.offTier, 0, reason: reason);
          expect(w.maxInGame, lessThanOrEqualTo(0.2), reason: reason);
        }
      }
      // A 70 % player at T1 multiplication: misses come back.
      expect(
        weakSpotsServed(ExerciseType.multiplication, Tier.t1).weakSpots,
        greaterThan(0.1),
      );
    });
  });

  group('rules v9 (doc/levels.md v1.6, Phase 6b commit 1)', () {
    test("v9's level update is v3's: the four targets still met", () {
      final v9 = LevelRules.of(RulesVersion.v9);
      expect(v9, same(LevelRules.v3));
      for (final t in targetsFor(v9)) {
        expect(t.met, isTrue, reason: '${t.target}: ${t.measured}');
      }
    });

    test('pattern questions: about 2 in 5 where a family is drawn — less '
        'where the only family is small and used up (roots T3, integrals '
        'T1: the tier counts, not the source) — none where none is; never '
        'a lower tier', () {
      for (final type in ExerciseType.values) {
        for (final tier in Tier.values) {
          final served = sharesServed(
            type,
            tier,
            rules: RulesVersion.v9,
            games: 300,
          );
          final reason = '${type.name} ${tier.label}';
          if (patternShareExpected(type, tier, rules: RulesVersion.v9) == 0) {
            expect(served.patterns, 0, reason: reason);
          } else {
            expect(
              served.patterns,
              inInclusiveRange(0.25, 0.44),
              reason: reason,
            );
          }
          expect(served.lowerTier, 0, reason: reason);
        }
      }
    });

    test('weak spots: never above 20 % of an operation, never off the '
        'current tier', () {
      for (final type in ExerciseType.values) {
        for (final tier in Tier.values) {
          final w = weakSpotsServed(type, tier, games: 120);
          final reason = '${type.name} ${tier.label}';
          expect(w.offTier, 0, reason: reason);
          expect(w.maxInGame, lessThanOrEqualTo(0.2), reason: reason);
        }
      }
    });
  });

  // Review M4, `doc/levels.md` v1.6 "Quitting never pays" (Phase 6b
  // commit 2): a player who leaves each game at their first mistake.
  group('quitting at the first mistake', () {
    test('under v8 it paid: a 60 % player loses levels finishing, never '
        'quitting', () {
      final sixty = _player('60 %');
      expect(
        meanChangePerGame(
          sixty,
          rules: RulesVersion.v8,
          quitsAfterMistake: false,
        ),
        lessThan(0),
      );
      expect(
        meanChangePerGame(
          sixty,
          rules: RulesVersion.v8,
          quitsAfterMistake: true,
        ),
        greaterThanOrEqualTo(0),
      );
    });

    test('under v9 quitting costs more than finishing, at every accuracy '
        'below 100 %; a perfect player never quits, so nothing changes', () {
      for (final player in simulatedPlayers) {
        final finished = meanChangePerGame(
          player,
          rules: RulesVersion.v9,
          quitsAfterMistake: false,
          games: 4000,
        );
        final quit = meanChangePerGame(
          player,
          rules: RulesVersion.v9,
          quitsAfterMistake: true,
          games: 4000,
        );
        if (player.accuracy < 1) {
          expect(quit, lessThan(finished), reason: player.name);
          expect(quit, lessThan(0), reason: player.name);
        } else {
          expect(quit, finished, reason: player.name);
        }
      }
    });
  });
}
