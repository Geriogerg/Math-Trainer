import 'dart:math';

import 'package:math_core/generation/game_generator.dart';
import 'package:math_core/generation/question_plan.dart';
import 'package:math_core/leveling/level.dart';
import 'package:math_core/leveling/rules_version.dart';
import 'package:math_core/models/exercise.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/models/game_setup.dart';
import 'package:math_core/tiers/tier.dart';
import 'package:math_core/tiers/tier_content.dart';
import 'package:math_core/tiers/tiered_game_generator.dart';
import 'package:test/test.dart';

void main() {
  test('tiers: ten bands of ten levels, 100 in T9', () {
    expect(Tier.of(Level.zero), Tier.t0);
    expect(Tier.of(Level.fromHundredths(999)), Tier.t0);
    expect(Tier.of(Level.whole(10)), Tier.t1);
    expect(Tier.of(Level.fromHundredths(4999)), Tier.t4);
    expect(Tier.of(Level.whole(90)), Tier.t9);
    expect(Tier.of(Level.whole(100)), Tier.t9);
    expect(Tier.t0.below, isNull);
    expect(Tier.t5.below, Tier.t4);
  });

  test('Training: Easy T1, Medium T4, Hard T7 (doc/levels.md, section 4)', () {
    expect(Tier.of(TrainingDifficulty.easy.level), Tier.t1);
    expect(Tier.of(TrainingDifficulty.medium.level), Tier.t4);
    expect(Tier.of(TrainingDifficulty.hard.level), Tier.t7);
  });

  test('review questions: 30 %, half up — 1 of 4, 2 of 5, 3 of 10, 6 of 20; '
      'none at T0', () {
    expect(
      [
        for (final n in [4, 5, 10, 20]) reviewQuestionCount(Tier.t3, n),
      ],
      [1, 2, 3, 6],
    );
    expect(reviewQuestionCount(Tier.t0, 20), 0);
  });

  /// The tiers a game draws, per operation, for [seed].
  Map<ExerciseType, List<Tier>> tiersOf(
    int seed,
    Map<ExerciseType, Level> levels,
    int perOperation,
  ) {
    final sequence = shuffledTypeSequence(
      types: levels.keys.toSet(),
      perOperation: perOperation,
      seed: seed,
    );
    final generator = TieredGameGenerator(
      sequence: sequence,
      levels: levels,
      content: standardContent,
      withReviews: true,
    );
    final random = Random(seed);
    final drawn = <ExerciseType, List<Tier>>{};
    for (final type in sequence) {
      final question = generator.next(random);
      expect(question.type, type);
      drawn.putIfAbsent(type, () => []).add(generator.lastTier!);
    }
    return drawn;
  }

  test('v2–v4: every game, every operation: exactly 70 % from its tier and '
      '30 % from the one below', () {
    final levels = {
      ExerciseType.addition: Level.whole(37),
      ExerciseType.division: Level.zero,
      ExerciseType.power: Level.whole(100),
      ExerciseType.integral: Level.fromHundredths(1050),
    };
    for (final n in questionsPerOperationChoices) {
      for (var seed = 0; seed < 300; seed++) {
        final drawn = tiersOf(seed, levels, n);
        for (final MapEntry(key: type, value: tiers) in drawn.entries) {
          final own = Tier.of(levels[type]!);
          final reviews = reviewQuestionCount(own, n);
          expect(tiers.where((t) => t == own), hasLength(n - reviews));
          expect(tiers.where((t) => t == own.below), hasLength(reviews));
        }
      }
    }
  });

  test('the reviews fall anywhere in the game', () {
    // Over many seeds, the first question of an operation is sometimes a
    // review and sometimes not.
    final first = <Tier>{};
    for (var seed = 0; seed < 200; seed++) {
      first.add(
        tiersOf(seed, {
          ExerciseType.addition: Level.whole(55),
        }, 10)[ExerciseType.addition]!.first,
      );
    }
    expect(first, {Tier.t5, Tier.t4});
  });

  test('same seed, same questions', () {
    final levels = {
      ExerciseType.subtraction: Level.whole(64),
      ExerciseType.percentage: Level.whole(71),
    };
    List<Exercise> run() {
      final sequence = shuffledTypeSequence(
        types: levels.keys.toSet(),
        perOperation: 10,
        seed: 42,
      );
      final generator = TieredGameGenerator(
        sequence: sequence,
        levels: levels,
        content: standardContent,
        withReviews: true,
      );
      final random = Random(42);
      return [for (final _ in sequence) generator.next(random)];
    }

    final first = run();
    expect(run(), first);
    expect(first.toSet().length, greaterThan(10));
  });

  test('invalid configurations throw (rule 13)', () {
    expect(
      () => TieredGameGenerator(
        sequence: const [],
        levels: const {},
        content: standardContent,
        withReviews: true,
      ),
      throwsArgumentError,
    );
    expect(
      () => TieredGameGenerator(
        sequence: const [ExerciseType.addition],
        levels: const {},
        content: standardContent,
        withReviews: true,
      ),
      throwsArgumentError,
    );
    final generator = TieredGameGenerator(
      sequence: const [ExerciseType.addition],
      levels: {ExerciseType.addition: Level.zero},
      content: standardContent,
      withReviews: true,
    );
    final random = Random(1);
    generator.next(random);
    expect(() => generator.next(random), throwsStateError);
  });
  group('rules v5 (doc/levels.md v1.4, section 2): no review questions', () {
    /// A game of [perOperation] questions of each of [levels]' operations
    /// under the current rules, from [seed]: each question with the tier it
    /// was drawn from.
    List<(Exercise, Tier)> game(
      int seed,
      Map<ExerciseType, Level> levels,
      int perOperation,
    ) {
      final sequence = shuffledTypeSequence(
        types: levels.keys.toSet(),
        perOperation: perOperation,
        seed: seed,
      );
      final generator =
          gameExerciseGenerator(
                rulesVersion: RulesVersion.current,
                enabledTypes: levels.keys.toSet(),
                levels: levels,
                typeSequence: sequence,
              )
              as TieredGameGenerator;
      final random = Random(seed);
      return [
        for (final _ in sequence) (generator.next(random), generator.lastTier!),
      ];
    }

    test('v5 is current and has no reviews', () {
      expect(RulesVersion.current, RulesVersion.v5);
      final generator =
          gameExerciseGenerator(
                rulesVersion: RulesVersion.v5,
                enabledTypes: {ExerciseType.addition},
                levels: {ExerciseType.addition: Level.whole(50)},
                typeSequence: const [ExerciseType.addition],
              )
              as TieredGameGenerator;
      expect(generator.withReviews, isFalse);
    });

    test('every question of every game comes from the tier of its '
        "operation's whole level: every level in steps of 0.37, every "
        'operation, every questions-per-operation choice', () {
      var questions = 0;
      for (var hundredths = 0; hundredths <= 10000; hundredths += 37) {
        final level = Level.fromHundredths(hundredths);
        for (final n in questionsPerOperationChoices) {
          final levels = {for (final t in ExerciseType.values) t: level};
          for (final (e, tier) in game(hundredths + n, levels, n)) {
            questions++;
            expect(tier, Tier.of(level), reason: '$hundredths: $e');
          }
        }
      }
      expect(questions, greaterThan(50000));
    });

    test('the whole level decides the tier: 19.99 draws T1, 20.00 T2', () {
      for (final (hundredths, tier) in [
        (1000, Tier.t1),
        (1999, Tier.t1),
        (2000, Tier.t2),
        (9999, Tier.t9),
      ]) {
        final levels = {
          for (final t in ExerciseType.values)
            t: Level.fromHundredths(hundredths),
        };
        for (final (_, drawn) in game(hundredths, levels, 20)) {
          expect(drawn, tier, reason: '$hundredths');
        }
      }
    });

    test("levels 10–19: no power above 2⁶, none above T1's largest (15² "
        '= 225) — every hundredth of the band, a game of 20 powers each', () {
      var powersOf2 = 0;
      for (var hundredths = 1000; hundredths < 2000; hundredths++) {
        final levels = {ExerciseType.power: Level.fromHundredths(hundredths)};
        for (final (e, _) in game(hundredths, levels, 20)) {
          final power = e as PowerExercise;
          if (power.base == 2) {
            powersOf2++;
            expect(power.exponent, lessThanOrEqualTo(6), reason: '$hundredths');
          }
          expect(
            power.correctAnswer,
            lessThanOrEqualTo(225),
            reason: '$hundredths: ${power.base}^${power.exponent}',
          );
        }
      }
      // The band does draw powers of 2 (standard 2¹–2⁶ and the family).
      expect(powersOf2, greaterThan(1000));
    });
  });
}
