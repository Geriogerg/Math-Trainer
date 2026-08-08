import 'dart:math';

import 'package:math_trainer/core/domain/generation/power_generator.dart';
import 'package:test/test.dart';

void main() {
  group('PowerExerciseGenerator', () {
    const generator = PowerExerciseGenerator();

    test('la même seed produit toujours la même séquence', () {
      final randomA = Random(7);
      final randomB = Random(7);

      final sequenceA = List.generate(20, (_) => generator.next(randomA));
      final sequenceB = List.generate(20, (_) => generator.next(randomB));

      expect(sequenceA, equals(sequenceB));
    });

    test('base et exposant respectent les bornes internes', () {
      final random = Random(1);

      for (var i = 0; i < 50; i++) {
        final exercise = generator.next(random);
        expect(exercise.base, inInclusiveRange(2, 10));
        expect(exercise.exponent, anyOf(2, 3));
      }
    });
  });
}
