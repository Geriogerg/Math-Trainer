import 'dart:math';

import '../models/exercise.dart';
import 'exercise_generator.dart';
import 'operand_range.dart';

class PowerExerciseGenerator implements ExerciseGenerator {
  PowerExerciseGenerator({OperandRange? baseRange, OperandRange? exponentRange})
    : baseRange = baseRange ?? OperandRange(min: 2, max: 10),
      exponentRange = exponentRange ?? OperandRange(min: 2, max: 3);

  final OperandRange baseRange;
  final OperandRange exponentRange;

  @override
  PowerExercise next(Random random) {
    final base = baseRange.min + random.nextInt(baseRange.max - baseRange.min + 1);
    final exponent = exponentRange.min + random.nextInt(exponentRange.max - exponentRange.min + 1);
    return PowerExercise(base: base, exponent: exponent);
  }
}
