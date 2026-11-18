import '../generation/operand_range.dart';
import 'level_interpolation.dart';

/// Only the `percent` range varies with the level (min and max both
/// widen); the multiplier building `base` stays at the generator's default
/// range, unchanged since step 3.
///
/// Replaces the discrete list {5, 10, 20, 25, 50} with a continuous range,
/// consistent with the linear interpolation of the six other axes — see
/// `doc/decisions.md`. Generation stays exact by construction whatever
/// percentage is drawn.
class PercentageDifficulty {
  const PercentageDifficulty({
    required this.percentMinAtLevel1,
    required this.percentMaxAtLevel1,
    required this.percentMinAtLevel100,
    required this.percentMaxAtLevel100,
  });

  final int percentMinAtLevel1;
  final int percentMaxAtLevel1;
  final int percentMinAtLevel100;
  final int percentMaxAtLevel100;

  OperandRange percentRangeFor(int level) => OperandRange(
    min: interpolateLevel(level: level, atLevel1: percentMinAtLevel1, atLevel100: percentMinAtLevel100),
    max: interpolateLevel(level: level, atLevel1: percentMaxAtLevel1, atLevel100: percentMaxAtLevel100),
  );
}

/// Uncalibrated starting values — see `doc/decisions.md`.
const percentageDifficulty = PercentageDifficulty(
  percentMinAtLevel1: 10,
  percentMaxAtLevel1: 50,
  percentMinAtLevel100: 1,
  percentMaxAtLevel100: 99,
);
