import 'dart:math';

import '../models/exercise.dart';
import 'exercise_generator.dart';
import 'operand_range.dart';

/// Choisit `percent` puis construit `base` comme un multiple du pas requis
/// pour que `percent * base` soit exactement divisible par 100 (règle 10) :
/// jamais de tirage suivi d'une vérification de divisibilité.
class PercentageExerciseGenerator implements ExerciseGenerator {
  PercentageExerciseGenerator({OperandRange? percentRange, OperandRange? multiplierRange})
    : percentRange = percentRange ?? OperandRange(min: 5, max: 50),
      multiplierRange = multiplierRange ?? OperandRange(min: 1, max: 10);

  final OperandRange percentRange;
  final OperandRange multiplierRange;

  @override
  PercentageExercise next(Random random) {
    final percent = percentRange.min + random.nextInt(percentRange.max - percentRange.min + 1);
    final step = 100 ~/ _gcd(percent, 100);
    final multiplier =
        multiplierRange.min + random.nextInt(multiplierRange.max - multiplierRange.min + 1);
    return PercentageExercise(percent: percent, base: step * multiplier);
  }

  int _gcd(int a, int b) => b == 0 ? a : _gcd(b, a % b);
}
