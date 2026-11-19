import 'dart:math';

import 'package:math_core/generation/operand_range.dart';
import 'package:math_core/generation/percentage_generator.dart';
import 'package:test/test.dart';

void main() {
  group('PercentageExerciseGenerator', () {
    final generator = PercentageExerciseGenerator();

    test('the same seed always produces the same sequence', () {
      final randomA = Random(7);
      final randomB = Random(7);

      final sequenceA = List.generate(20, (_) => generator.next(randomA));
      final sequenceB = List.generate(20, (_) => generator.next(randomB));

      expect(sequenceA, equals(sequenceB));
    });

    test(
      'percent comes from the default range and the percentage is always exact',
      () {
        final random = Random(1);

        for (var i = 0; i < 50; i++) {
          final exercise = generator.next(random);

          expect(exercise.percent, inInclusiveRange(5, 50));
          expect((exercise.percent * exercise.base) % 100, 0);
        }
      },
    );

    test('a custom percentRange restricts the draw', () {
      final narrowGenerator = PercentageExerciseGenerator(
        percentRange: OperandRange(min: 30, max: 30),
      );
      final random = Random(2);

      for (var i = 0; i < 20; i++) {
        expect(narrowGenerator.next(random).percent, 30);
      }
    });
  });
}
