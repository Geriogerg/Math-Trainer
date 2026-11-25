import 'package:math_core/duel/duel_mode.dart';
import 'package:math_core/duel/duel_rating.dart';
import 'package:math_core/leveling/level.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:test/test.dart';

void main() {
  test('starting ratings from levels (plan v3.7)', () {
    // Nothing played: 900, 900, 1300.
    expect(startingDuelRating(DuelMode.basics, const {}), 900);
    expect(startingDuelRating(DuelMode.advanced, const {}), 900);
    expect(startingDuelRating(DuelMode.count, const {}), 1300);

    final levels = {
      ExerciseType.addition: Level.fromHundredths(4000),
      ExerciseType.subtraction: Level.fromHundredths(4000),
      ExerciseType.multiplication: Level.fromHundredths(4000),
      // division unplayed: 0 in the main level, as everywhere.
      ExerciseType.power: Level.fromHundredths(6000),
      ExerciseType.squareRoot: Level.fromHundredths(2000),
      ExerciseType.percentage: Level.fromHundredths(5050),
      ExerciseType.integral: Level.fromHundredths(1000),
    };
    // Main level 30 → 900 + 450.
    expect(startingDuelRating(DuelMode.basics, levels), 1350);
    // Advanced mean (60 + 20 + 50.5 + 10) / 4 = 35.125 → 1426.875.
    expect(startingDuelRating(DuelMode.advanced, levels), 1426.875);
    // Get the count ignores levels.
    expect(startingDuelRating(DuelMode.count, levels), 1300);
    // Level 100 everywhere: 2400, tier 9.
    final top = {for (final t in ExerciseType.values) t: Level.whole(100)};
    expect(startingDuelRating(DuelMode.basics, top), 2400);
  });

  test('provisional for the first 10 rated duels; points rounded', () {
    expect(isProvisionalRating(0), isTrue);
    expect(isProvisionalRating(9), isTrue);
    expect(isProvisionalRating(10), isFalse);
    expect(ratingPoints(1541.5), 1542);
    expect(ratingPoints(1541.49), 1541);
  });
}
