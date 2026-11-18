import 'package:math_trainer/core/domain/leveling/overall_level.dart';
import 'package:math_trainer/core/domain/models/exercise_type.dart';
import 'package:math_trainer/core/domain/persistence/level_cache_entry.dart';
import 'package:test/test.dart';

LevelCacheEntry _level(int level) =>
    LevelCacheEntry(level: level, sessionsPlayed: 1, updatedAt: DateTime.utc(2026, 11, 17));

void main() {
  group('overallLevel', () {
    test('no type played: floor level 1', () {
      expect(overallLevel(const {}), 1);
    });

    test('a type never played counts at the floor, not left out of the mean', () {
      // (43 + 6 × 1) / 7 = 7, not 43.
      expect(overallLevel({ExerciseType.addition: _level(43)}), 7);
    });

    test('mean over the 7 types when all are played', () {
      expect(overallLevel({for (final type in ExerciseType.values) type: _level(50)}), 50);
    });
  });
}
