import 'package:math_trainer/core/domain/leveling/level_cache_entry.dart';
import 'package:test/test.dart';

void main() {
  group('LevelCacheEntry', () {
    test('accepte des valeurs valides', () {
      final entry = LevelCacheEntry(level: 50, sessionsPlayed: 3, updatedAt: DateTime.utc(2026, 8, 8));

      expect(entry.level, 50);
      expect(entry.sessionsPlayed, 3);
    });

    test('refuse un niveau hors [1, 100]', () {
      expect(
        () => LevelCacheEntry(level: 0, sessionsPlayed: 0, updatedAt: DateTime.utc(2026, 8, 8)),
        throwsArgumentError,
      );
      expect(
        () => LevelCacheEntry(level: 101, sessionsPlayed: 0, updatedAt: DateTime.utc(2026, 8, 8)),
        throwsArgumentError,
      );
    });

    test('refuse un sessionsPlayed négatif', () {
      expect(
        () => LevelCacheEntry(level: 50, sessionsPlayed: -1, updatedAt: DateTime.utc(2026, 8, 8)),
        throwsArgumentError,
      );
    });

    test('refuse un updatedAt qui n\'est pas en UTC', () {
      expect(
        () => LevelCacheEntry(level: 50, sessionsPlayed: 0, updatedAt: DateTime(2026, 8, 8)),
        throwsArgumentError,
      );
    });
  });
}
