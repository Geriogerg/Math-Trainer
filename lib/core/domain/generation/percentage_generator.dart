import 'dart:math';

import '../models/exercise.dart';
import 'exercise_generator.dart';

/// Choisit `percent` puis construit `base` comme un multiple du pas requis
/// pour que `percent * base` soit exactement divisible par 100 (règle 10) :
/// jamais de tirage suivi d'une vérification de divisibilité.
/// Bornes internes, non réglables (étape 4 : difficulté paramétrable).
class PercentageExerciseGenerator implements ExerciseGenerator {
  const PercentageExerciseGenerator();

  static const _percents = [5, 10, 20, 25, 50];
  static const _multiplierMin = 1;
  static const _multiplierMax = 10;

  @override
  PercentageExercise next(Random random) {
    final percent = _percents[random.nextInt(_percents.length)];
    final step = 100 ~/ _gcd(percent, 100);
    final multiplier = _multiplierMin + random.nextInt(_multiplierMax - _multiplierMin + 1);
    return PercentageExercise(percent: percent, base: step * multiplier);
  }

  int _gcd(int a, int b) => b == 0 ? a : _gcd(b, a % b);
}
