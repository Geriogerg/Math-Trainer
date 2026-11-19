import '../generation/operand_range.dart';
import 'level_interpolation.dart';

/// Shared by the 4 arithmetic operations (same output type,
/// [OperandRange]): "seven level → bounds functions" in the sense of seven
/// entry points, not seven duplicated bodies.
///
/// Stores raw `int`s rather than [OperandRange]s to stay `const` —
/// `OperandRange` lost its `const` constructor when its `min <= max`
/// invariant became a `throw`.
class LinearOperandRangeDifficulty {
  const LinearOperandRangeDifficulty({
    required this.minAtLevel1,
    required this.maxAtLevel1,
    required this.minAtLevel100,
    required this.maxAtLevel100,
  });

  final int minAtLevel1;
  final int maxAtLevel1;
  final int minAtLevel100;
  final int maxAtLevel100;

  OperandRange operandRangeFor(int level) => OperandRange(
    min: interpolateLevel(
      level: level,
      atLevel1: minAtLevel1,
      atLevel100: minAtLevel100,
    ),
    max: interpolateLevel(
      level: level,
      atLevel1: maxAtLevel1,
      atLevel100: maxAtLevel100,
    ),
  );
}

/// Uncalibrated starting values — see `doc/decisions.md`.
const additionDifficulty = LinearOperandRangeDifficulty(
  minAtLevel1: 1,
  maxAtLevel1: 5,
  minAtLevel100: 1,
  maxAtLevel100: 999,
);

const subtractionDifficulty = LinearOperandRangeDifficulty(
  minAtLevel1: 1,
  maxAtLevel1: 5,
  minAtLevel100: 1,
  maxAtLevel100: 999,
);

const multiplicationDifficulty = LinearOperandRangeDifficulty(
  minAtLevel1: 1,
  maxAtLevel1: 5,
  minAtLevel100: 1,
  maxAtLevel100: 50,
);

const divisionDifficulty = LinearOperandRangeDifficulty(
  minAtLevel1: 1,
  maxAtLevel1: 5,
  minAtLevel100: 1,
  maxAtLevel100: 50,
);
