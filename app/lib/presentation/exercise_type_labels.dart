import 'package:math_core/models/exercise_type.dart';

String exerciseTypeLabel(ExerciseType type) => switch (type) {
  ExerciseType.addition => 'Addition',
  ExerciseType.subtraction => 'Subtraction',
  ExerciseType.multiplication => 'Multiplication',
  ExerciseType.division => 'Division',
  ExerciseType.power => 'Powers',
  ExerciseType.squareRoot => 'Square roots',
  ExerciseType.percentage => 'Percentages',
  ExerciseType.integral => 'Integrals',
};
