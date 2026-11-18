import 'package:math_trainer/core/domain/persistence/level_cache_entry.dart';
import 'package:test/test.dart';

void main() {
  group('LevelCacheEntry', () {
    test('accepts valid values', () {
      final entry = LevelCacheEntry(
        level: 50,
        sessionsPlayed: 3,
        updatedAt: DateTime.utc(2026, 8, 8),
      );

      expect(entry.level, 50);
      expect(entry.sessionsPlayed, 3);
    });

    test('rejects a level outside [1, 100]', () {
      expect(
        () => LevelCacheEntry(
          level: 0,
          sessionsPlayed: 0,
          updatedAt: DateTime.utc(2026, 8, 8),
        ),
        throwsArgumentError,
      );
      expect(
        () => LevelCacheEntry(
          level: 101,
          sessionsPlayed: 0,
          updatedAt: DateTime.utc(2026, 8, 8),
        ),
        throwsArgumentError,
      );
    });

    test('rejects a negative sessionsPlayed', () {
      expect(
        () => LevelCacheEntry(
          level: 50,
          sessionsPlayed: -1,
          updatedAt: DateTime.utc(2026, 8, 8),
        ),
        throwsArgumentError,
      );
    });

    test('rejects an updatedAt that is not UTC', () {
      expect(
        () => LevelCacheEntry(
          level: 50,
          sessionsPlayed: 0,
          updatedAt: DateTime(2026, 8, 8),
        ),
        throwsArgumentError,
      );
    });
  });
}
