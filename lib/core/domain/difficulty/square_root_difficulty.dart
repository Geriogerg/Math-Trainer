import '../generation/operand_range.dart';
import 'level_interpolation.dart';

/// Seule la taille de la racine tirée varie avec le niveau.
class SquareRootDifficulty {
  const SquareRootDifficulty({required this.rootMaxAtLevel1, required this.rootMaxAtLevel100});

  final int rootMaxAtLevel1;
  final int rootMaxAtLevel100;

  static const _rootMin = 2;

  OperandRange rootRangeFor(int level) => OperandRange(
    min: _rootMin,
    max: interpolateLevel(level: level, atLevel1: rootMaxAtLevel1, atLevel100: rootMaxAtLevel100),
  );
}

/// Valeurs de départ non calibrées — voir `doc/decisions.md`.
const squareRootDifficulty = SquareRootDifficulty(rootMaxAtLevel1: 4, rootMaxAtLevel100: 40);
