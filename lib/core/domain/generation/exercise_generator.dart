import 'dart:math';

import '../models/exercise.dart';

/// One implementation per exercise family (arithmetic, power, root,
/// percentage). `random` is provided by the caller so that several
/// generators can share the same seeded stream and stay deterministic
/// together.
abstract class ExerciseGenerator {
  Exercise next(Random random);
}
