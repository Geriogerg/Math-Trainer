import 'dart:math';

import 'package:math_core/duel/duel_config.dart';
import 'package:math_core/duel/duel_mode.dart';
import 'package:math_core/generation/game_generator.dart';
import 'package:math_core/leveling/level.dart';
import 'package:math_core/leveling/rules_version.dart';
import 'package:math_core/models/exercise.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/models/operation_type.dart';
import 'package:math_core/patterns/pattern_family.dart';
import 'package:math_core/patterns/pattern_spaces_v9.dart';
import 'package:math_core/tiers/game_draws.dart';
import 'package:math_core/tiers/question_space.dart';
import 'package:math_core/tiers/standard_v9.dart';
import 'package:math_core/tiers/tier.dart';
import 'package:math_core/tiers/tiered_game_generator.dart';
import 'package:math_core/weak_spots/item.dart';
import 'package:test/test.dart';

/// Rules v9 (`doc/levels.md` v1.6, section 5 "Drawing rules", section 5b),
/// Phase 6b commit 1 (review M10, m11, m20, m21).

/// A game of [n] questions of [type] at [tier] under v9.
TieredGameGenerator _game(
  ExerciseType type,
  Tier tier, {
  int n = 10,
  List<Item> weakSpots = const [],
}) =>
    gameExerciseGenerator(
          rulesVersion: RulesVersion.v9,
          enabledTypes: {type},
          levels: {type: Level.whole(10 * tier.index + 5)},
          typeSequence: List.filled(n, type),
          weakSpots: weakSpots,
        )
        as TieredGameGenerator;

/// Every question of a listed space (all v9 spaces but the long sums').
List<Exercise>? _listed(QuestionSpace space) =>
    space.approximateDistinct <= listLimit ? space.questions : null;

void main() {
  test('every tier offers at least 12 distinct standard questions per '
      'operation', () {
    for (final type in ExerciseType.values) {
      for (final tier in Tier.values) {
        expect(
          standardSpaceV9(type, tier).distinct,
          greaterThanOrEqualTo(12),
          reason: '${type.name} ${tier.label}',
        );
      }
    }
    // The thin tiers of the review (M10), now the spec's twelve.
    expect(standardSpaceV9(ExerciseType.squareRoot, Tier.t1).distinct, 12);
    expect(standardSpaceV9(ExerciseType.power, Tier.t1).distinct, 12);
    expect(standardSpaceV9(ExerciseType.integral, Tier.t4).distinct, 12);
  });

  test('no repeated question in a 10-question game at any tier (the exit '
      'test): 300 games of every operation at every tier', () {
    for (final type in ExerciseType.values) {
      for (final tier in Tier.values) {
        final random = Random(31 * type.index + tier.index);
        for (var g = 0; g < 300; g++) {
          final game = _game(type, tier);
          final asked = <Exercise>{};
          for (var i = 0; i < 10; i++) {
            final q = canonicalOf(game.next(random));
            expect(asked.add(q), isTrue, reason: '${type.name} $tier: $q');
          }
        }
      }
    }
  });

  test('a long game uses every question of a tier before any repeat, and '
      'never asks one twice in a row', () {
    // Powers at T0: 12 questions, a 40-question game.
    final random = Random(5);
    for (var g = 0; g < 50; g++) {
      final game = _game(ExerciseType.power, Tier.t0, n: 40);
      final asked = [
        for (var i = 0; i < 40; i++) canonicalOf(game.next(random)),
      ];
      expect(asked.take(12).toSet(), hasLength(12));
      expect(asked.toSet(), hasLength(12));
      for (var i = 1; i < asked.length; i++) {
        expect(asked[i], isNot(asked[i - 1]), reason: 'question $i');
      }
    }
  });

  test('uniform over distinct questions: 9 + 1 was 11 % of T0 addition, now '
      '1 in 25; 2⁵ was 25 % of T1 powers, now 1 in 12', () {
    double share(ExerciseType type, Tier tier, Exercise target) {
      final random = Random(9);
      var hits = 0;
      const games = 24000;
      for (var g = 0; g < games; g++) {
        if (canonicalOf(_game(type, tier, n: 1).next(random)) == target) {
          hits++;
        }
      }
      return hits / games;
    }

    final ninePlusOne = ArithmeticExercise(
      operandA: 1,
      operandB: 9,
      operationType: OperationType.addition,
    );
    expect(
      share(ExerciseType.addition, Tier.t0, ninePlusOne),
      closeTo(1 / 25, 0.006),
    );
    // T1 powers: no family left (powers of 2 skipped), 12 questions.
    expect(
      share(
        ExerciseType.power,
        Tier.t1,
        const PowerExercise(base: 2, exponent: 5),
      ),
      closeTo(1 / 12, 0.01),
    );
  });

  test('no trivial factor above T0: no exponent 1, no × 1, no ÷ 1, no 1 % or '
      '100 % but where a tier lists it (1 % at T4)', () {
    String? trivial(Exercise e) => switch (e) {
      PowerExercise(:final exponent) when exponent == 1 => 'exponent 1',
      ArithmeticExercise(:final operationType, :final operandA, :final operandB)
          when operationType == OperationType.multiplication &&
              (operandA == 1 || operandB == 1) =>
        '× 1',
      ArithmeticExercise(:final operationType, :final operandB)
          when operationType == OperationType.division && operandB == 1 =>
        '÷ 1',
      PercentageExercise(:final percent, :final tenths)
          when tenths == 0 && (percent == 1 || percent == 100) =>
        '$percent %',
      _ => null,
    };
    for (final type in ExerciseType.values) {
      for (final tier in Tier.values.skip(1)) {
        final questions = _listed(standardSpaceV9(type, tier));
        for (final q in questions ?? const <Exercise>[]) {
          final why = trivial(q);
          if (why == '1 %' &&
              type == ExerciseType.percentage &&
              tier.index == 4) {
            continue;
          }
          expect(why, isNull, reason: '${type.name} ${tier.label}: $q');
        }
      }
    }
    for (final family in PatternFamily.values) {
      for (final tier in Tier.values.skip(max(1, family.from.index))) {
        for (final q in _listed(familySpaceV9(family, tier)) ?? <Exercise>[]) {
          expect(trivial(q), isNull, reason: '${family.name} $tier: $q');
        }
      }
    }
  });

  test('"7- and 8-digit numbers": every combination, for both numbers '
      '(v8 never drew an 8-digit second number in subtraction, review '
      'm21)', () {
    for (final type in [ExerciseType.addition, ExerciseType.subtraction]) {
      final random = Random(17);
      final shapes = <String>{};
      for (var g = 0; g < 600; g++) {
        final q =
            standardSpaceV9(type, Tier.t8).draw(random, const {})
                as ArithmeticExercise;
        shapes.add('${'${q.operandA}'.length}+${'${q.operandB}'.length}');
      }
      expect(
        shapes,
        type == ExerciseType.addition
            ? containsAll(['7+7', '8+7', '8+8'])
            : unorderedEquals(['7+7', '8+7', '8+8']),
        reason: type.name,
      );
    }
  });

  test('a family with fewer than 4 questions at a tier is skipped there, '
      'and only there', () {
    final skipped = <String>[];
    for (final family in PatternFamily.values) {
      for (final tier in Tier.values.skip(family.from.index)) {
        final drawn = familiesAtV9(family.type, tier).contains(family);
        final distinct = familySpaceV9(family, tier).distinct;
        expect(drawn, distinct >= 4, reason: '${family.name} $tier');
        if (!drawn) skipped.add('${family.name} ${tier.label}');
      }
    }
    expect(skipped, [
      for (var t = 1; t <= 6; t++) 'powersOf2 T$t',
      'repunits T6',
      for (var t = 3; t <= 9; t++) 'rootsOfPowersOf2 T$t',
      'threeXSquaredFromZero T4',
      'threeXSquaredFromZero T5',
      for (var t = 7; t <= 9; t++) 'fourXCubedFromZero T$t',
    ]);
  });

  test('a skipped family is never drawn in a game; its share goes to the '
      'others', () {
    final random = Random(3);
    var patterns = 0;
    for (var g = 0; g < 200; g++) {
      final game = _game(ExerciseType.power, Tier.t3);
      for (var i = 0; i < 10; i++) {
        game.next(random);
        final family = game.lastFamily;
        if (family != null) patterns++;
        expect(family, isNot(PatternFamily.powersOf2));
      }
    }
    // Squares ending in 5 alone at T3: still about 2 in 5.
    expect(patterns / 2000, closeTo(0.4, 0.05));
  });

  test("a weak spot's fact is never drawn as another question of the "
      'game', () {
    final sevenEight = Item.parse('fact:multiplication:7,8');
    final key = factKey(sevenEight as FactItem);
    final random = Random(1);
    for (var g = 0; g < 300; g++) {
      final game = _game(
        ExerciseType.multiplication,
        Tier.t1,
        weakSpots: [sevenEight],
      );
      var asked = 0;
      for (var i = 0; i < 10; i++) {
        final q = canonicalOf(game.next(random));
        if (q == key) {
          asked++;
          expect(game.lastWeakSpot, sevenEight, reason: 'only as the spot');
        }
      }
      expect(asked, 1);
    }
  });

  test('pattern and standard questions never repeat each other: roots at '
      'T3, where every family question is also a standard one', () {
    final random = Random(8);
    for (var g = 0; g < 500; g++) {
      final game = _game(ExerciseType.squareRoot, Tier.t3, n: 17);
      final asked = [
        for (var i = 0; i < 17; i++) canonicalOf(game.next(random)),
      ];
      expect(asked.toSet(), hasLength(17), reason: '17 questions at T3');
    }
  });

  test('the same seed draws the same game (rule 2): two generators', () {
    for (final type in ExerciseType.values) {
      final a = _game(type, Tier.t3, n: 20);
      final b = _game(type, Tier.t3, n: 20);
      final ra = Random(42);
      final rb = Random(42);
      for (var i = 0; i < 20; i++) {
        expect(a.next(ra), b.next(rb));
      }
    }
  });

  test('a v9 duel never repeats a question: 2,000 duels of each mode at '
      'every tier', () {
    for (final mode in [DuelMode.basics, DuelMode.advanced]) {
      for (var tier = 0; tier <= 9; tier++) {
        for (var seed = 0; seed < 200; seed++) {
          final questions = DuelConfig(
            mode: mode,
            seed: seed,
            difficulty: tier,
          ).questions().map(canonicalOf).toList();
          expect(questions.toSet(), hasLength(8), reason: '$mode T$tier');
        }
      }
    }
  });
}
