import 'package:math_trainer/core/domain/difficulty/arithmetic_difficulty.dart';
import 'package:test/test.dart';

void main() {
  group('LinearOperandRangeDifficulty', () {
    final difficulties = {
      'addition': additionDifficulty,
      'subtraction': subtractionDifficulty,
      'multiplication': multiplicationDifficulty,
      'division': divisionDifficulty,
    };

    for (final entry in difficulties.entries) {
      group(entry.key, () {
        final difficulty = entry.value;

        test('valeurs exactes aux niveaux 1 et 100', () {
          final atLevel1 = difficulty.operandRangeFor(1);
          final atLevel100 = difficulty.operandRangeFor(100);

          expect(atLevel1.min, difficulty.minAtLevel1);
          expect(atLevel1.max, difficulty.maxAtLevel1);
          expect(atLevel100.min, difficulty.minAtLevel100);
          expect(atLevel100.max, difficulty.maxAtLevel100);
        });

        test('monotone sur les points d\'ancrage (1, 25, 50, 75, 100)', () {
          final maxValues = [
            for (final level in [1, 25, 50, 75, 100]) difficulty.operandRangeFor(level).max,
          ];

          for (var i = 1; i < maxValues.length; i++) {
            expect(maxValues[i], greaterThanOrEqualTo(maxValues[i - 1]));
          }
        });

        test('pas de saut brutal : chaque palier suit la proportion attendue', () {
          final anchors = [1, 25, 50, 75, 100];
          final totalSpan = difficulty.maxAtLevel100 - difficulty.maxAtLevel1;
          final maxValues = [for (final level in anchors) difficulty.operandRangeFor(level).max];

          for (var i = 1; i < maxValues.length; i++) {
            final levelGap = anchors[i] - anchors[i - 1];
            final expectedStep = totalSpan * levelGap / 99;
            final actualStep = maxValues[i] - maxValues[i - 1];
            expect((actualStep - expectedStep).abs(), lessThanOrEqualTo(1));
          }
        });

        test('refuse un niveau hors [1, 100]', () {
          expect(() => difficulty.operandRangeFor(0), throwsArgumentError);
          expect(() => difficulty.operandRangeFor(101), throwsArgumentError);
        });
      });
    }
  });
}
