import 'dart:math';

import '../models/exercise.dart';
import 'exercise_generator.dart';
import 'exercise_source.dart';

class LocalExerciseSource extends ExerciseSource {
  LocalExerciseSource({required this.generator, required int seed})
    : _random = Random(seed);

  final ExerciseGenerator generator;
  final Random _random;

  @override
  Exercise next() => generator.next(_random);
}
