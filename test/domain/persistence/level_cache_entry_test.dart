import 'package:math_trainer/core/domain/leveling/level.dart';
import 'package:math_trainer/core/domain/persistence/level_cache_entry.dart';
import 'package:test/test.dart';

void main() {
  group('LevelCacheEntry', () {
    test('accepts valid values', () {
      final entry = LevelCacheEntry(
        level: Level.fromHundredths(5037),
        sessionsPlayed: 3,
        updatedAt: DateTime.utc(2026, 8, 8),
      );

      expect(entry.level.hundredths, 5037);
      expect(entry.sessionsPlayed, 3);
    });

    test('rejects a negative sessionsPlayed', () {
      expect(
        () => LevelCacheEntry(
          level: Level.whole(50),
          sessionsPlayed: -1,
          updatedAt: DateTime.utc(2026, 8, 8),
        ),
        throwsArgumentError,
      );
    });

    test('rejects an updatedAt that is not UTC', () {
      expect(
        () => LevelCacheEntry(
          level: Level.whole(50),
          sessionsPlayed: 0,
          updatedAt: DateTime(2026, 8, 8),
        ),
        throwsArgumentError,
      );
    });
  });
}
