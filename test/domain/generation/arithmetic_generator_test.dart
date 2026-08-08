import 'dart:math';

import 'package:math_trainer/core/domain/generation/arithmetic_generator.dart';
import 'package:math_trainer/core/domain/generation/operand_range.dart';
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

    test('des seeds différentes produisent des séquences différentes', () {
      // Propriété constatée empiriquement sur cet échantillon, pas une
      // garantie mathématique : deux seeds distinctes pourraient en théorie
      // produire la même séquence par coïncidence.
      List<String> sequenceFor(int seed) {
        final generator = ArithmeticExerciseGenerator(operationTypes: OperationType.values);
        final random = Random(seed);
        return List.generate(20, (_) => generator.next(random).prompt);
      }

      final sequences = [1, 2, 3, 4].map(sequenceFor).toList();

      for (var i = 0; i < sequences.length; i++) {
        for (var j = i + 1; j < sequences.length; j++) {
          expect(sequences[i], isNot(equals(sequences[j])));
        }
      }
    });

    test('les opérandes générés respectent les bornes configurées', () {
      const range = OperandRange(min: 5, max: 8);
      final generator = ArithmeticExerciseGenerator(
        operationTypes: const [
          OperationType.addition,
          OperationType.subtraction,
          OperationType.multiplication,
        ],
        operandRange: range,
      );
      final random = Random(4);

      for (var i = 0; i < 50; i++) {
        final exercise = generator.next(random);
        expect(exercise.operandA, inInclusiveRange(range.min, range.max));
        expect(exercise.operandB, inInclusiveRange(range.min, range.max));
      }
    });

    test('refuse une plage autorisant un diviseur nul quand la division est activée', () {
      expect(
        () => ArithmeticExerciseGenerator(
          operationTypes: const [OperationType.division],
          operandRange: const OperandRange(min: 0, max: 5),
        ),
        throwsArgumentError,
      );
    });
  });
}
