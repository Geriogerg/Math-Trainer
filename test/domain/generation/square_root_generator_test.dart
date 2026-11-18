import 'dart:math';

import 'package:math_trainer/core/domain/generation/operand_range.dart';
import 'package:math_trainer/core/domain/generation/square_root_generator.dart';
import 'package:test/test.dart';

void main() {
  group('SquareRootExerciseGenerator', () {
    final generator = SquareRootExerciseGenerator();

    test('the same seed always produces the same sequence', () {
      final randomA = Random(7);
      final randomB = Random(7);

      final sequenceA = List.generate(20, (_) => generator.next(randomA));
      final sequenceB = List.generate(20, (_) => generator.next(randomB));

      expect(sequenceA, equals(sequenceB));
    });

    test('the radicand is always a perfect square within the default bounds', () {
      final random = Random(1);

      for (var i = 0; i < 50; i++) {
        final exercise = generator.next(random);
        final root = exercise.correctAnswer;

        expect(root, inInclusiveRange(2, 12));
        expect(root * root, exercise.radicand);
      }
    });

    test('a custom rootRange restricts the draw', () {
      final narrowGenerator = SquareRootExerciseGenerator(rootRange: OperandRange(min: 7, max: 7));
      final random = Random(2);

      for (var i = 0; i < 20; i++) {
        final exercise = narrowGenerator.next(random);
        expect(exercise.correctAnswer, 7);
        expect(exercise.radicand, 49);
      }
    });
  });
}
