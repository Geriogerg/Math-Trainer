import 'dart:math';

import '../models/exercise.dart';
import 'exercise_generator.dart';
import 'operand_range.dart';

/// Tire la racine `r` et présente `r²` (règle 10) : jamais de tirage sur
/// `radicand` suivi d'une vérification « est-ce un carré parfait ? ».
class SquareRootExerciseGenerator implements ExerciseGenerator {
  SquareRootExerciseGenerator({OperandRange? rootRange})
    : rootRange = rootRange ?? OperandRange(min: 2, max: 12);

  final OperandRange rootRange;

  @override
  SquareRootExercise next(Random random) {
    final root = rootRange.min + random.nextInt(rootRange.max - rootRange.min + 1);
    return SquareRootExercise(radicand: root * root);
  }
}
