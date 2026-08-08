import 'exercise_type.dart';

class SessionConfig {
  const SessionConfig({
    required this.seed,
    required this.enabledTypes,
    required this.exerciseCount,
  });

  final int seed;
  final Set<ExerciseType> enabledTypes;
  final int exerciseCount;
}
