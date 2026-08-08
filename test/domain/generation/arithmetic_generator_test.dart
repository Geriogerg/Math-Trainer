import 'dart:math';

import 'package:math_trainer/core/domain/generation/arithmetic_generator.dart';
import 'package:math_trainer/core/domain/models/operation_type.dart';
import 'package:test/test.dart';

void main() {
  group('ArithmeticExerciseGenerator', () {
    test('la même seed produit toujours la même séquence', () {
      final generatorA = ArithmeticExerciseGenerator(
        operationTypes: OperationType.values,
      );
      final generatorB = ArithmeticExerciseGenerator(
        operationTypes: OperationType.values,
      );

      final randomA = Random(42);
      final randomB = Random(42);

      final sequenceA = List.generate(20, (_) => generatorA.next(randomA));
      final sequenceB = List.generate(20, (_) => generatorB.next(randomB));

      expect(sequenceA, equals(sequenceB));
    });

    test('les divisions ont toujours un résultat entier exact', () {
      final generator = ArithmeticExerciseGenerator(
        operationTypes: const [OperationType.division],
      );
      final random = Random(1);

      for (var i = 0; i < 50; i++) {
        final exercise = generator.next(random);
        expect(exercise.operandA % exercise.operandB, 0);
      }
    });

    test('les soustractions ne produisent jamais de résultat négatif', () {
      final generator = ArithmeticExerciseGenerator(
        operationTypes: const [OperationType.subtraction],
      );
      final random = Random(2);

      for (var i = 0; i < 50; i++) {
        final exercise = generator.next(random);
        expect(exercise.correctAnswer, greaterThanOrEqualTo(0));
      }
    });

    test('ne génère que les types d\'opération configurés', () {
      final generator = ArithmeticExerciseGenerator(
        operationTypes: const [OperationType.addition, OperationType.multiplication],
      );
      final random = Random(3);

      for (var i = 0; i < 50; i++) {
        final exercise = generator.next(random);
        expect(
          exercise.operationType,
          anyOf(OperationType.addition, OperationType.multiplication),
        );
      }
    });
  });
}
