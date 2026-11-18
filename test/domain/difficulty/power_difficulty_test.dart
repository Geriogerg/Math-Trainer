import 'package:math_trainer/core/domain/difficulty/power_difficulty.dart';
import 'package:test/test.dart';

void main() {
  group('PowerDifficulty', () {
    test('exact values at levels 1 and 100', () {
      expect(powerDifficulty.exponentRangeFor(1).max, powerDifficulty.exponentMaxAtLevel1);
      expect(powerDifficulty.exponentRangeFor(100).max, powerDifficulty.exponentMaxAtLevel100);
    });

    test('the exponent lower bound stays fixed at every level (one axis)', () {
      for (final level in [1, 25, 50, 75, 100]) {
        expect(powerDifficulty.exponentRangeFor(level).min, 2);
      }
    });

    test('monotonic over the anchor points (1, 25, 50, 75, 100)', () {
      final maxValues = [
        for (final level in [1, 25, 50, 75, 100]) powerDifficulty.exponentRangeFor(level).max,
      ];

      for (var i = 1; i < maxValues.length; i++) {
        expect(maxValues[i], greaterThanOrEqualTo(maxValues[i - 1]));
      }
    });

    test('rejects a level outside [1, 100]', () {
      expect(() => powerDifficulty.exponentRangeFor(0), throwsArgumentError);
      expect(() => powerDifficulty.exponentRangeFor(101), throwsArgumentError);
    });
  });
}
