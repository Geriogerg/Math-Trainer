import 'package:math_core/difficulty/percentage_difficulty.dart';
import 'package:test/test.dart';

void main() {
  group('PercentageDifficulty', () {
    test('exact values at levels 1 and 100', () {
      final atLevel1 = percentageDifficulty.percentRangeFor(1);
      final atLevel100 = percentageDifficulty.percentRangeFor(100);

      expect(atLevel1.min, percentageDifficulty.percentMinAtLevel1);
      expect(atLevel1.max, percentageDifficulty.percentMaxAtLevel1);
      expect(atLevel100.min, percentageDifficulty.percentMinAtLevel100);
      expect(atLevel100.max, percentageDifficulty.percentMaxAtLevel100);
    });

    test('the range widens on both sides as the level rises', () {
      final ranges = [
        for (final level in [1, 25, 50, 75, 100])
          percentageDifficulty.percentRangeFor(level),
      ];

      for (var i = 1; i < ranges.length; i++) {
        expect(ranges[i].min, lessThanOrEqualTo(ranges[i - 1].min));
        expect(ranges[i].max, greaterThanOrEqualTo(ranges[i - 1].max));
      }
    });

    test('rejects a level outside [1, 100]', () {
      expect(
        () => percentageDifficulty.percentRangeFor(0),
        throwsArgumentError,
      );
      expect(
        () => percentageDifficulty.percentRangeFor(101),
        throwsArgumentError,
      );
    });
  });
}
