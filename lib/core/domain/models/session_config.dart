import 'exercise_type.dart';

class SessionConfig {
  const SessionConfig({
    required this.seed,
    required this.enabledTypes,
    required this.exerciseCount,
    required this.levels,
  });

  final int seed;
  final Set<ExerciseType> enabledTypes;
  final int exerciseCount;

  /// Per-operation levels frozen at the start of the session — never
  /// recomputed along the way (otherwise duels cannot be revalidated
  /// server-side, see `doc/decisions.md`).
  final Map<ExerciseType, int> levels;
}
