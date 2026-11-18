import 'dart:math';

import 'package:math_trainer/core/domain/generation/arithmetic_generator.dart';
import 'package:math_trainer/core/domain/generation/operand_range.dart';
import 'package:math_trainer/core/domain/models/exercise.dart';
import 'package:math_trainer/core/domain/models/operation_type.dart';
import 'package:test/test.dart';

void main() {
  group('ArithmeticExerciseGenerator', () {
    test('the same seed always produces the same sequence', () {
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

    test('divisions always have an exact integer result', () {
      final generator = ArithmeticExerciseGenerator(
        operationTypes: const [OperationType.division],
      );
      final random = Random(1);

      for (var i = 0; i < 50; i++) {
        final exercise = generator.next(random);
        expect(exercise.operandA % exercise.operandB, 0);
      }
    });

    test('subtractions never produce a negative result', () {
      final generator = ArithmeticExerciseGenerator(
        operationTypes: const [OperationType.subtraction],
      );
      final random = Random(2);

      for (var i = 0; i < 50; i++) {
        final exercise = generator.next(random);
        expect(exercise.correctAnswer, greaterThanOrEqualTo(0));
      }
    });

    test('only generates the configured operation types', () {
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

    test('different seeds produce different sequences', () {
      // A property observed empirically on this sample, not a mathematical
      // guarantee: two distinct seeds could in theory produce the same
      // sequence by coincidence.
      List<ArithmeticExercise> sequenceFor(int seed) {
        final generator = ArithmeticExerciseGenerator(operationTypes: OperationType.values);
        final random = Random(seed);
        return List.generate(20, (_) => generator.next(random));
      }

      final sequences = [1, 2, 3, 4].map(sequenceFor).toList();

      for (var i = 0; i < sequences.length; i++) {
        for (var j = i + 1; j < sequences.length; j++) {
          expect(sequences[i], isNot(equals(sequences[j])));
        }
      }
    });

    test('generated operands respect the configured bounds', () {
      final range = OperandRange(min: 5, max: 8);
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

    test('rejects an empty list of operation types', () {
      expect(
        () => ArithmeticExerciseGenerator(operationTypes: const []),
        throwsArgumentError,
      );
    });

    test('rejects a range allowing a zero divisor when division is enabled', () {
      expect(
        () => ArithmeticExerciseGenerator(
          operationTypes: const [OperationType.division],
          operandRange: OperandRange(min: 0, max: 5),
        ),
        throwsArgumentError,
      );
    });
  });
}
