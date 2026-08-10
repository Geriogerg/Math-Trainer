import 'package:math_trainer/core/domain/difficulty/level_interpolation.dart';
import 'package:test/test.dart';

void main() {
  group('interpolateLevel', () {
    test('retourne la valeur de départ au niveau 1 et d\'arrivée au niveau 100', () {
      expect(interpolateLevel(level: 1, atLevel1: 5, atLevel100: 50), 5);
      expect(interpolateLevel(level: 100, atLevel1: 5, atLevel100: 50), 50);
    });

    test('interpole de façon monotone entre les deux bornes', () {
      final values = [
        for (final level in [1, 25, 50, 75, 100])
          interpolateLevel(level: level, atLevel1: 5, atLevel100: 999),
      ];

      for (var i = 1; i < values.length; i++) {
        expect(values[i], greaterThanOrEqualTo(values[i - 1]));
      }
    });

    test('fonctionne aussi quand la valeur décroît avec le niveau', () {
      final values = [
        for (final level in [1, 25, 50, 75, 100])
          interpolateLevel(level: level, atLevel1: 50, atLevel100: 1),
      ];

      for (var i = 1; i < values.length; i++) {
        expect(values[i], lessThanOrEqualTo(values[i - 1]));
      }
    });

    test('refuse un niveau hors [1, 100]', () {
      expect(() => interpolateLevel(level: 0, atLevel1: 1, atLevel100: 10), throwsArgumentError);
      expect(() => interpolateLevel(level: 101, atLevel1: 1, atLevel100: 10), throwsArgumentError);
    });
  });
}
