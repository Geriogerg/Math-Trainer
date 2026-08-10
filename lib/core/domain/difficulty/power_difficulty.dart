import '../generation/operand_range.dart';
import 'level_interpolation.dart';

/// Seul l'exposant varie avec le niveau (un seul axe à la fois) ; la base
/// reste à la plage par défaut du générateur, inchangée depuis l'étape 3.
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

/// Valeurs de départ non calibrées — voir `doc/decisions.md`.
const powerDifficulty = PowerDifficulty(exponentMaxAtLevel1: 2, exponentMaxAtLevel100: 5);
