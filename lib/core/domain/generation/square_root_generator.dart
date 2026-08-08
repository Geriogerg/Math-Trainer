import 'dart:math';

import '../models/exercise.dart';
import 'exercise_generator.dart';

/// Tire la racine `r` et présente `r²` (règle 10) : jamais de tirage sur
/// `radicand` suivi d'une vérification « est-ce un carré parfait ? ».
/// Bornes internes, non réglables (étape 4 : difficulté paramétrable).
class SquareRootExerciseGenerator implements ExerciseGenerator {
  const SquareRootExerciseGenerator();

  static const _rootMin = 2;
  static const _rootMax = 12;

  @override
  SquareRootExercise next(Random random) {
    final root = _rootMin + random.nextInt(_rootMax - _rootMin + 1);
    return SquareRootExercise(radicand: root * root);
  }
}
