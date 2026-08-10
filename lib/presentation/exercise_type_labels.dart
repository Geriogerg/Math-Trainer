import '../core/domain/models/exercise_type.dart';

String exerciseTypeLabel(ExerciseType type) => switch (type) {
  ExerciseType.addition => 'Addition',
  ExerciseType.subtraction => 'Soustraction',
  ExerciseType.multiplication => 'Multiplication',
  ExerciseType.division => 'Division',
  ExerciseType.power => 'Puissances',
  ExerciseType.squareRoot => 'Racines carrées',
  ExerciseType.percentage => 'Pourcentages',
};
