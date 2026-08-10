import 'package:math_trainer/core/domain/leveling/confidence.dart';
import 'package:math_trainer/core/domain/persistence/level_cache_entry.dart';
import 'package:math_trainer/core/domain/leveling/leveling_rules.dart';
import 'package:test/test.dart';

void main() {
  group('confidenceFor', () {
    final rules = LevelingRules();
    final now = DateTime.utc(2026, 8, 8);

    test('calibration quand l\'opération n\'a jamais été jouée', () {
      expect(
        confidenceFor(entry: null, now: now, rules: rules),
        ConfidenceMultiplier.calibration,
      );
    });

    test('calibration pendant les 3 premières sessions d\'une opération', () {
      for (final sessionsPlayed in [0, 1, 2]) {
        final entry = LevelCacheEntry(level: 50, sessionsPlayed: sessionsPlayed, updatedAt: now);
        expect(
          confidenceFor(entry: entry, now: now, rules: rules),
          ConfidenceMultiplier.calibration,
        );
      }
    });

    test('normal après 3 sessions et sans longue absence', () {
      final entry = LevelCacheEntry(level: 50, sessionsPlayed: 5, updatedAt: now);

      expect(confidenceFor(entry: entry, now: now, rules: rules), ConfidenceMultiplier.normal);
    });

    test('returning après une absence de absenceDaysThreshold jours ou plus', () {
      final lastPlayed = now.subtract(Duration(days: rules.absenceDaysThreshold));
      final entry = LevelCacheEntry(level: 50, sessionsPlayed: 5, updatedAt: lastPlayed);

      expect(confidenceFor(entry: entry, now: now, rules: rules), ConfidenceMultiplier.returning);
    });

    test('normal juste sous le seuil d\'absence', () {
      final lastPlayed = now.subtract(Duration(days: rules.absenceDaysThreshold - 1));
      final entry = LevelCacheEntry(level: 50, sessionsPlayed: 5, updatedAt: lastPlayed);

      expect(confidenceFor(entry: entry, now: now, rules: rules), ConfidenceMultiplier.normal);
    });
  });
}
