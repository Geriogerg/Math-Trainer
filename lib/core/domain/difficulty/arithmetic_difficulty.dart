import '../generation/operand_range.dart';
import 'level_interpolation.dart';

/// Partagée par les 4 opérations arithmétiques (même type de sortie,
/// [OperandRange]) : « sept fonctions niveau → bornes » au sens de sept
/// points d'entrée, pas sept corps de code dupliqués.
///
/// Stocke des `int` bruts plutôt que des [OperandRange] pour rester
/// `const` — `OperandRange` n'a plus de constructeur `const` depuis que
/// son invariant `min <= max` est défendu par un `throw`.
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
    min: interpolateLevel(level: level, atLevel1: minAtLevel1, atLevel100: minAtLevel100),
    max: interpolateLevel(level: level, atLevel1: maxAtLevel1, atLevel100: maxAtLevel100),
  );
}

/// Valeurs de départ non calibrées — voir `doc/decisions.md`.
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
