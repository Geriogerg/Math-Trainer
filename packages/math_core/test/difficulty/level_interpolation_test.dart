import 'package:math_core/difficulty/level_interpolation.dart';
import 'package:test/test.dart';

void main() {
  group('interpolateLevel', () {
    test(
      'returns the start value at level 1 and the end value at level 100',
      () {
        expect(interpolateLevel(level: 1, atLevel1: 5, atLevel100: 50), 5);
        expect(interpolateLevel(level: 100, atLevel1: 5, atLevel100: 50), 50);
      },
    );

    test('interpolates monotonically between the two bounds', () {
      final values = [
        for (final level in [1, 25, 50, 75, 100])
          interpolateLevel(level: level, atLevel1: 5, atLevel100: 999),
      ];

      for (var i = 1; i < values.length; i++) {
        expect(values[i], greaterThanOrEqualTo(values[i - 1]));
      }
    });

    test('also works when the value decreases with the level', () {
      final values = [
        for (final level in [1, 25, 50, 75, 100])
          interpolateLevel(level: level, atLevel1: 50, atLevel100: 1),
      ];

      for (var i = 1; i < values.length; i++) {
        expect(values[i], lessThanOrEqualTo(values[i - 1]));
      }
    });

    test('rejects a level outside [1, 100]', () {
      expect(
        () => interpolateLevel(level: 0, atLevel1: 1, atLevel100: 10),
        throwsArgumentError,
      );
      expect(
        () => interpolateLevel(level: 101, atLevel1: 1, atLevel100: 10),
        throwsArgumentError,
      );
    });
  });
}
