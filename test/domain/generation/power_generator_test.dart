import 'dart:math';

import 'package:math_trainer/core/domain/generation/operand_range.dart';
import 'package:math_trainer/core/domain/generation/power_generator.dart';
import 'package:test/test.dart';

void main() {
  group('PowerExerciseGenerator', () {
    final generator = PowerExerciseGenerator();

    test('la même seed produit toujours la même séquence', () {
      final randomA = Random(7);
      final randomB = Random(7);

      final sequenceA = List.generate(20, (_) => generator.next(randomA));
      final sequenceB = List.generate(20, (_) => generator.next(randomB));

      expect(sequenceA, equals(sequenceB));
    });

    test('base et exposant respectent les bornes par défaut', () {
      final random = Random(1);

      for (var i = 0; i < 50; i++) {
        final exercise = generator.next(random);
        expect(exercise.base, inInclusiveRange(2, 10));
        expect(exercise.exponent, anyOf(2, 3));
      }
    });

    test('exponentRange personnalisée restreint le tirage', () {
      final narrowGenerator = PowerExerciseGenerator(
        exponentRange: OperandRange(min: 4, max: 4),
      );
      final random = Random(2);

      for (var i = 0; i < 20; i++) {
        expect(narrowGenerator.next(random).exponent, 4);
      }
    });
  });
}
