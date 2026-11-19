import 'package:math_core/leveling/level.dart';
import 'package:math_core/leveling/overall_level.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/persistence/level_cache_entry.dart';
import 'package:test/test.dart';

LevelCacheEntry _level(int hundredths) => LevelCacheEntry(
  level: Level.fromHundredths(hundredths),
  sessionsPlayed: 1,
  updatedAt: DateTime.utc(2026, 11, 17),
);

void main() {
  group('overallLevel', () {
    test('no type played: floor level 1', () {
      expect(overallLevel(const {}), 1);
    });

    test(
      'a type never played counts at the floor, not left out of the mean',
      () {
        // (43 + 6 × 1) / 7 = 7, not 43.
        expect(overallLevel({ExerciseType.addition: _level(4300)}), 7);
      },
    );

    test('mean over the 7 types when all are played', () {
      expect(
        overallLevel({
          for (final type in ExerciseType.values) type: _level(5000),
        }),
        50,
      );
    });

    test('continuous: hundredths reach the mean, in level units', () {
      // (37.42 + 6 × 1.00) / 7 = 43.42 / 7.
      expect(
        overallLevel({ExerciseType.addition: _level(3742)}),
        closeTo(43.42 / 7, 1e-12),
      );
    });
  });
}
