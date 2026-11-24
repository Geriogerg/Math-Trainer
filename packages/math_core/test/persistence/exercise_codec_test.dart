import 'package:math_core/models/exercise.dart';
import 'package:math_core/models/operation_type.dart';
import 'package:math_core/persistence/exercise_codec.dart';
import 'dart:math';

import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/tiers/tier.dart';
import 'package:math_core/tiers/tier_content.dart';
import 'package:test/test.dart';

void main() {
  group('describeExerciseForStorage', () {
    test('describes an ArithmeticExercise with its operands', () {
      final exercise = ArithmeticExercise(
        operandA: 4,
        operandB: 3,
        operationType: OperationType.addition,
      );

      final described = describeExerciseForStorage(exercise);

      expect(described.exerciseType, 'arithmetic');
      expect(described.operationType, 'addition');
      expect(described.operands, {'operandA': 4, 'operandB': 3});
    });

    test('describes a PowerExercise with base and exponent', () {
      const exercise = PowerExercise(base: 3, exponent: 2);

      final described = describeExerciseForStorage(exercise);

      expect(described.exerciseType, 'power');
      expect(described.operationType, 'power');
      expect(described.operands, {'base': 3, 'exponent': 2});
    });

    test('describes a SquareRootExercise with the radicand', () {
      final exercise = SquareRootExercise(radicand: 16);

      final described = describeExerciseForStorage(exercise);

      expect(described.exerciseType, 'squareRoot');
      expect(described.operationType, 'squareRoot');
      expect(described.operands, {'radicand': 16});
    });

    test('describes a PercentageExercise with percent and base', () {
      final exercise = PercentageExercise(percent: 25, base: 80);

      final described = describeExerciseForStorage(exercise);

      expect(described.exerciseType, 'percentage');
      expect(described.operationType, 'percentage');
      expect(described.operands, {'percent': 25, 'base': 80});
    });

    test(
      'a third addend only when present: two-term sums keep their shape',
      () {
        expect(
          describeExerciseForStorage(
            ArithmeticExercise(
              operandA: 27,
              operandB: 46,
              operandC: 73,
              operationType: OperationType.addition,
            ),
          ).operands,
          {'operandA': 27, 'operandB': 46, 'operandC': 73},
        );
        expect(
          describeExerciseForStorage(
            ArithmeticExercise(
              operandA: 27,
              operandB: 46,
              operationType: OperationType.addition,
            ),
          ).operands.keys,
          ['operandA', 'operandB'],
        );
      },
    );
  });

  group('exerciseFromStorage', () {
    test('reads back every question a tier draws, pattern ones too', () {
      final random = Random(7);
      for (final type in ExerciseType.values) {
        for (final tier in Tier.values) {
          for (var i = 0; i < 200; i++) {
            final exercise = patternedContentV6(type, tier, random).exercise;
            final d = describeExerciseForStorage(exercise);
            expect(
              exerciseFromStorage(
                exerciseType: d.exerciseType,
                operationType: d.operationType,
                operands: d.operands,
              ),
              exercise,
            );
          }
        }
      }
    });

    test('a description no exercise has throws', () {
      for (final (type, op, operands) in [
        ('arithmetic', 'modulo', {'operandA': 1, 'operandB': 2}),
        ('arithmetic', 'addition', {'operandA': 1}),
        ('arithmetic', 'addition', {'operandA': 1, 'operandB': 'x'}),
        ('power', 'squareRoot', {'base': 1, 'exponent': 2}),
        ('cube', 'cube', {'base': 1}),
      ]) {
        expect(
          () => exerciseFromStorage(
            exerciseType: type,
            operationType: op,
            operands: operands,
          ),
          throwsFormatException,
          reason: '$type $op $operands',
        );
      }
      expect(
        () => exerciseFromStorage(
          exerciseType: 'squareRoot',
          operationType: 'squareRoot',
          operands: {'radicand': 8, 'index': 4},
        ),
        throwsArgumentError,
      );
    });
  });
}
