import 'package:math_trainer/core/domain/leveling/leveling_rules.dart';
import 'package:test/test.dart';

void main() {
  group('LevelingRules', () {
    test('rejects tRapideMs >= tLentMs', () {
      expect(
        () => LevelingRules(tRapideMs: 8000, tLentMs: 2000),
        throwsArgumentError,
      );
      expect(
        () => LevelingRules(tRapideMs: 5000, tLentMs: 5000),
        throwsArgumentError,
      );
    });

    test('accepts the default values', () {
      expect(LevelingRules().tRapideMs, lessThan(LevelingRules().tLentMs));
    });

    test('rejects an absenceDaysThreshold <= 0', () {
      expect(() => LevelingRules(absenceDaysThreshold: 0), throwsArgumentError);
      expect(
        () => LevelingRules(absenceDaysThreshold: -1),
        throwsArgumentError,
      );
    });

    test('rejects an nMin <= 0', () {
      expect(() => LevelingRules(nMin: 0), throwsArgumentError);
      expect(() => LevelingRules(nMin: -1), throwsArgumentError);
    });
  });
}
