import 'dart:math';

import '../models/exercise.dart';

/// Une implémentation par famille d'exercice (arithmétique, puis plus tard
/// fraction/puissance/racine). `random` est fourni par l'appelant pour que
/// plusieurs générateurs puissent partager le même flux seedé et rester
/// déterministes ensemble.
abstract class ExerciseGenerator {
  Exercise next(Random random);
}
