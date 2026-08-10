import 'package:math_trainer/core/domain/difficulty/square_root_difficulty.dart';
import 'package:test/test.dart';

void main() {
  group('SquareRootDifficulty', () {
    test('valeurs exactes aux niveaux 1 et 100', () {
      expect(squareRootDifficulty.rootRangeFor(1).max, squareRootDifficulty.rootMaxAtLevel1);
      expect(squareRootDifficulty.rootRangeFor(100).max, squareRootDifficulty.rootMaxAtLevel100);
    });

    test('la borne min de la racine reste fixe à tous les niveaux (un seul axe)', () {
      for (final level in [1, 25, 50, 75, 100]) {
        expect(squareRootDifficulty.rootRangeFor(level).min, 2);
      }
    });

    test('monotone sur les points d\'ancrage (1, 25, 50, 75, 100)', () {
      final maxValues = [
        for (final level in [1, 25, 50, 75, 100]) squareRootDifficulty.rootRangeFor(level).max,
      ];

      for (var i = 1; i < maxValues.length; i++) {
        expect(maxValues[i], greaterThanOrEqualTo(maxValues[i - 1]));
      }
    });

    test('refuse un niveau hors [1, 100]', () {
      expect(() => squareRootDifficulty.rootRangeFor(0), throwsArgumentError);
      expect(() => squareRootDifficulty.rootRangeFor(101), throwsArgumentError);
    });
  });
}
