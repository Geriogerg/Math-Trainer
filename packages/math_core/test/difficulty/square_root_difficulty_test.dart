import 'package:math_core/difficulty/square_root_difficulty.dart';
import 'package:test/test.dart';

void main() {
  group('SquareRootDifficulty', () {
    test('exact values at levels 1 and 100', () {
      expect(
        squareRootDifficulty.rootRangeFor(1).max,
        squareRootDifficulty.rootMaxAtLevel1,
      );
      expect(
        squareRootDifficulty.rootRangeFor(100).max,
        squareRootDifficulty.rootMaxAtLevel100,
      );
    });

    test('the root lower bound stays fixed at every level (one axis)', () {
      for (final level in [1, 25, 50, 75, 100]) {
        expect(squareRootDifficulty.rootRangeFor(level).min, 2);
      }
    });

    test('monotonic over the anchor points (1, 25, 50, 75, 100)', () {
      final maxValues = [
        for (final level in [1, 25, 50, 75, 100])
          squareRootDifficulty.rootRangeFor(level).max,
      ];

      for (var i = 1; i < maxValues.length; i++) {
        expect(maxValues[i], greaterThanOrEqualTo(maxValues[i - 1]));
      }
    });

    test('rejects a level outside [1, 100]', () {
      expect(() => squareRootDifficulty.rootRangeFor(0), throwsArgumentError);
      expect(() => squareRootDifficulty.rootRangeFor(101), throwsArgumentError);
    });
  });
}
