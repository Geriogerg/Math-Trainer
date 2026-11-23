import '../leveling/level.dart';
import '../leveling/rules_version.dart';
import '../models/exercise_type.dart';
import 'tier.dart';

/// The time under which a correct answer earns full credit
/// (`doc/levels.md`, sections 3 and 5): set by the operation and the tier
/// of the level the game was played at — the same for every question of
/// that operation in the game, its review and pattern questions included —
/// under the rules the game was played with. Throws for rules v1, retired.
int fluentTimeMs(ExerciseType type, Level level, RulesVersion rules) =>
    _fluentSeconds(type, rules)[Tier.of(level).index] * 1000;

/// Seconds per tier, T0 first (`doc/levels.md`, section 5; tunable).
List<int> _fluentSeconds(ExerciseType type, RulesVersion rules) {
  switch (rules) {
    case RulesVersion.v1:
      throw ArgumentError.value(rules, 'rules', 'is retired.');
    case RulesVersion.v2 || RulesVersion.v3:
      // Rules v2 and v3 timed their own, shorter addition and subtraction
      // tables (`arithmeticAt`); kept, so their games replay.
      if (type == ExerciseType.addition || type == ExerciseType.subtraction) {
        return const [4, 4, 5, 5, 6, 8, 9, 10, 12, 14];
      }
    case RulesVersion.v4:
      break;
  }
  return switch (type) {
    // The spec's section 5, up to 9 digits (`longArithmeticAt`).
    ExerciseType.addition => const [4, 5, 6, 8, 10, 12, 15, 18, 21, 25],
    ExerciseType.subtraction => const [4, 5, 6, 8, 10, 12, 15, 18, 21, 25],
    ExerciseType.multiplication => const [4, 4, 6, 7, 8, 10, 12, 12, 15, 18],
    ExerciseType.division => const [4, 5, 6, 7, 8, 10, 12, 12, 15, 18],
    ExerciseType.power => const [4, 5, 6, 6, 8, 10, 12, 14, 16, 18],
    ExerciseType.squareRoot => const [4, 5, 6, 6, 8, 10, 12, 14, 16, 18],
    ExerciseType.percentage => const [4, 5, 6, 7, 8, 10, 10, 12, 12, 15],
    ExerciseType.integral => const [6, 8, 10, 12, 12, 14, 16, 16, 18, 20],
  };
}
