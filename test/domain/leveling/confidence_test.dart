import 'package:math_trainer/core/domain/leveling/level.dart';
import 'package:math_trainer/core/domain/leveling/confidence.dart';
import 'package:math_trainer/core/domain/persistence/level_cache_entry.dart';
import 'package:math_trainer/core/domain/leveling/leveling_rules.dart';
import 'package:test/test.dart';

void main() {
  group('confidenceFor', () {
    final rules = LevelingRules();
    final now = DateTime.utc(2026, 8, 8);

    test('calibration when the operation was never played', () {
      expect(
        confidenceFor(entry: null, now: now, rules: rules),
        ConfidenceMultiplier.calibration,
      );
    });

    test("calibration during an operation's first 3 sessions", () {
      for (final sessionsPlayed in [0, 1, 2]) {
        final entry = LevelCacheEntry(
          level: Level.whole(50),
          sessionsPlayed: sessionsPlayed,
          updatedAt: now,
        );
        expect(
          confidenceFor(entry: entry, now: now, rules: rules),
          ConfidenceMultiplier.calibration,
        );
      }
    });

    test('normal after 3 sessions and no long absence', () {
      final entry = LevelCacheEntry(
        level: Level.whole(50),
        sessionsPlayed: 5,
        updatedAt: now,
      );

      expect(
        confidenceFor(entry: entry, now: now, rules: rules),
        ConfidenceMultiplier.normal,
      );
    });

    test('returning after an absence of absenceDaysThreshold days or more', () {
      final lastPlayed = now.subtract(
        Duration(days: rules.absenceDaysThreshold),
      );
      final entry = LevelCacheEntry(
        level: Level.whole(50),
        sessionsPlayed: 5,
        updatedAt: lastPlayed,
      );

      expect(
        confidenceFor(entry: entry, now: now, rules: rules),
        ConfidenceMultiplier.returning,
      );
    });

    test('normal just under the absence threshold', () {
      final lastPlayed = now.subtract(
        Duration(days: rules.absenceDaysThreshold - 1),
      );
      final entry = LevelCacheEntry(
        level: Level.whole(50),
        sessionsPlayed: 5,
        updatedAt: lastPlayed,
      );

      expect(
        confidenceFor(entry: entry, now: now, rules: rules),
        ConfidenceMultiplier.normal,
      );
    });
  });
}
