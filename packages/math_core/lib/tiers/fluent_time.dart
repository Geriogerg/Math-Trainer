import '../leveling/level.dart';
import '../models/exercise_type.dart';
import 'tier.dart';

/// Under rules v2, the time under which a correct answer earns full credit
/// (`doc/levels.md`, sections 3 and 5): set by the operation and the tier
/// of the level the game was played at — the same for every question of
/// that operation in the game, its review questions included.
int fluentTimeMs(ExerciseType type, Level level) =>
    _fluentSeconds(type)[Tier.of(level).index] * 1000;

/// Seconds per tier, T0 first (`doc/levels.md`, section 5; tunable).
List<int> _fluentSeconds(ExerciseType type) => switch (type) {
  ExerciseType.addition => const [4, 4, 5, 5, 6, 8, 9, 10, 12, 14],
  ExerciseType.subtraction => const [4, 4, 5, 5, 6, 8, 9, 10, 12, 14],
  ExerciseType.multiplication => const [4, 4, 6, 7, 8, 10, 12, 12, 15, 18],
  ExerciseType.division => const [4, 5, 6, 7, 8, 10, 12, 12, 15, 18],
  ExerciseType.power => const [4, 5, 6, 6, 8, 10, 12, 14, 16, 18],
  ExerciseType.squareRoot => const [4, 5, 6, 6, 8, 10, 12, 14, 16, 18],
  ExerciseType.percentage => const [4, 5, 6, 7, 8, 10, 10, 12, 12, 15],
  ExerciseType.integral => const [6, 8, 10, 12, 12, 14, 16, 16, 18, 20],
};
