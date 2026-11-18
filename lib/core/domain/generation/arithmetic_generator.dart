import 'dart:math';

import '../models/exercise.dart';
import '../models/operation_type.dart';
import 'exercise_generator.dart';
import 'operand_range.dart';

class ArithmeticExerciseGenerator implements ExerciseGenerator {
  ArithmeticExerciseGenerator({required this.operationTypes, OperandRange? operandRange})
    : operandRange = operandRange ?? OperandRange(min: 1, max: 10) {
    // Rule 13: an `assert` disappears in release — an empty list would
    // crash further on in a `nextInt(0)` with no explanation.
    if (operationTypes.isEmpty) {
      throw ArgumentError.value(
        operationTypes,
        'operationTypes',
        'must contain at least one operation type.',
      );
    }
    if (operationTypes.contains(OperationType.division) && this.operandRange.min < 1) {
      throw ArgumentError.value(
        this.operandRange,
        'operandRange',
        'Division needs a non-zero divisor (operandRange.min >= 1).',
      );
    }
  }

  final List<OperationType> operationTypes;
  final OperandRange operandRange;

  @override
  ArithmeticExercise next(Random random) {
    final operationType = operationTypes[random.nextInt(operationTypes.length)];
    return switch (operationType) {
      OperationType.addition ||
      OperationType.multiplication => _twoRandomOperands(random, operationType),
      OperationType.subtraction => _subtraction(random),
      OperationType.division => _division(random),
    };
  }

  int _randomOperand(Random random) =>
      operandRange.min + random.nextInt(operandRange.max - operandRange.min + 1);

  ArithmeticExercise _twoRandomOperands(Random random, OperationType operationType) {
    return ArithmeticExercise(
      operandA: _randomOperand(random),
      operandB: _randomOperand(random),
      operationType: operationType,
    );
  }

  ArithmeticExercise _subtraction(Random random) {
    final a = _randomOperand(random);
    final b = _randomOperand(random);
    return ArithmeticExercise(
      operandA: a >= b ? a : b,
      operandB: a >= b ? b : a,
      operationType: OperationType.subtraction,
    );
  }

  ArithmeticExercise _division(Random random) {
    final divisor = _randomOperand(random);
    final quotient = _randomOperand(random);
    return ArithmeticExercise(
      operandA: divisor * quotient,
      operandB: divisor,
      operationType: OperationType.division,
    );
  }
}
