import 'dart:math';

import 'package:math_core/generation/question_plan.dart';
import 'package:math_core/leveling/level.dart';
import 'package:math_core/models/exercise.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/tiers/tier.dart';
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
    final generator = TieredGameGenerator(sequence: sequence, levels: levels);
    final random = Random(seed);
    final drawn = <ExerciseType, List<Tier>>{};
    for (final type in sequence) {
      final question = generator.next(random);
      expect(question.type, type);
      drawn.putIfAbsent(type, () => []).add(generator.lastTier!);
    }
    return drawn;
  }

  test('every game, every operation: exactly 70 % from its tier and 30 % '
      'from the one below', () {
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
      final generator = TieredGameGenerator(sequence: sequence, levels: levels);
      final random = Random(42);
      return [for (final _ in sequence) generator.next(random)];
    }

    final first = run();
    expect(run(), first);
    expect(first.toSet().length, greaterThan(10));
  });

  test('invalid configurations throw (rule 13)', () {
    expect(
      () => TieredGameGenerator(sequence: const [], levels: const {}),
      throwsArgumentError,
    );
    expect(
      () => TieredGameGenerator(
        sequence: const [ExerciseType.addition],
        levels: const {},
      ),
      throwsArgumentError,
    );
    final generator = TieredGameGenerator(
      sequence: const [ExerciseType.addition],
      levels: {ExerciseType.addition: Level.zero},
    );
    final random = Random(1);
    generator.next(random);
    expect(() => generator.next(random), throwsStateError);
  });
}
