import 'package:math_trainer/core/domain/leveling/overall_level.dart';
import 'package:math_trainer/core/domain/models/exercise_type.dart';
import 'package:math_trainer/core/domain/persistence/level_cache_entry.dart';
import 'package:test/test.dart';

LevelCacheEntry _level(int level) =>
    LevelCacheEntry(level: level, sessionsPlayed: 1, updatedAt: DateTime.utc(2026, 11, 17));

void main() {
  group('overallLevel', () {
    test('aucun type joué : niveau plancher 1', () {
      expect(overallLevel(const {}), 1);
    });

    test('un type jamais joué compte au plancher, pas absent de la moyenne', () {
      // (43 + 6 × 1) / 7 = 7, pas 43.
      expect(overallLevel({ExerciseType.addition: _level(43)}), 7);
    });

    test('moyenne sur les 7 types quand tous sont joués', () {
      expect(overallLevel({for (final type in ExerciseType.values) type: _level(50)}), 50);
    });
  });
}
