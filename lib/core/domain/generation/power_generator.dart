import 'dart:math';

import '../models/exercise.dart';
import 'exercise_generator.dart';

/// Bornes internes, non réglables (étape 4 : difficulté paramétrable).
class PowerExerciseGenerator implements ExerciseGenerator {
  const PowerExerciseGenerator();

  static const _baseMin = 2;
  static const _baseMax = 10;
  static const _exponents = [2, 3];

  @override
  PowerExercise next(Random random) {
    final base = _baseMin + random.nextInt(_baseMax - _baseMin + 1);
    final exponent = _exponents[random.nextInt(_exponents.length)];
    return PowerExercise(base: base, exponent: exponent);
  }
}
