import '../generation/operand_range.dart';
import 'level_interpolation.dart';

/// Only the exponent varies with the level (one axis at a time); the base
/// stays at the generator's default range, unchanged since step 3.
class PowerDifficulty {
  const PowerDifficulty({required this.exponentMaxAtLevel1, required this.exponentMaxAtLevel100});

  final int exponentMaxAtLevel1;
  final int exponentMaxAtLevel100;

  static const _exponentMin = 2;

  OperandRange exponentRangeFor(int level) => OperandRange(
    min: _exponentMin,
    max: interpolateLevel(level: level, atLevel1: exponentMaxAtLevel1, atLevel100: exponentMaxAtLevel100),
  );
}

/// Uncalibrated starting values — see `doc/decisions.md`.
const powerDifficulty = PowerDifficulty(exponentMaxAtLevel1: 2, exponentMaxAtLevel100: 5);
