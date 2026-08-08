import 'dart:math';

import 'package:math_trainer/core/domain/generation/square_root_generator.dart';
import 'package:test/test.dart';

void main() {
  group('SquareRootExerciseGenerator', () {
    const generator = SquareRootExerciseGenerator();

    test('la même seed produit toujours la même séquence', () {
      final randomA = Random(7);
      final randomB = Random(7);

      final sequenceA = List.generate(20, (_) => generator.next(randomA));
      final sequenceB = List.generate(20, (_) => generator.next(randomB));

      expect(sequenceA, equals(sequenceB));
    });

    test('le radicande est toujours un carré parfait dans les bornes internes', () {
      final random = Random(1);

      for (var i = 0; i < 50; i++) {
        final exercise = generator.next(random);
        final root = exercise.correctAnswer;

        expect(root, inInclusiveRange(2, 12));
        expect(root * root, exercise.radicand);
      }
    });
  });
}
