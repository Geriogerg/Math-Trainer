import 'dart:math';

import '../models/exercise.dart';
import 'exercise_generator.dart';
import 'operand_range.dart';

/// Draws the root `r` and shows `r²` (rule 10): never a draw on `radicand`
/// followed by an "is it a perfect square?" check.
class SquareRootExerciseGenerator implements ExerciseGenerator {
  SquareRootExerciseGenerator({OperandRange? rootRange})
    : rootRange = rootRange ?? OperandRange(min: 2, max: 12);

  final OperandRange rootRange;

  @override
  SquareRootExercise next(Random random) {
    final root =
        rootRange.min + random.nextInt(rootRange.max - rootRange.min + 1);
    return SquareRootExercise(radicand: root * root);
  }
}
