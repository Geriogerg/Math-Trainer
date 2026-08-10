import 'dart:math';

import 'package:math_trainer/core/domain/generation/operand_range.dart';
import 'package:math_trainer/core/domain/generation/percentage_generator.dart';
import 'package:test/test.dart';

void main() {
  group('PercentageExerciseGenerator', () {
    final generator = PercentageExerciseGenerator();

    test('la même seed produit toujours la même séquence', () {
      final randomA = Random(7);
      final randomB = Random(7);

      final sequenceA = List.generate(20, (_) => generator.next(randomA));
      final sequenceB = List.generate(20, (_) => generator.next(randomB));

      expect(sequenceA, equals(sequenceB));
    });

    test('percent vient de la plage par défaut et le pourcentage est toujours exact', () {
      final random = Random(1);

      for (var i = 0; i < 50; i++) {
        final exercise = generator.next(random);

        expect(exercise.percent, inInclusiveRange(5, 50));
        expect((exercise.percent * exercise.base) % 100, 0);
      }
    });

    test('percentRange personnalisée restreint le tirage', () {
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
