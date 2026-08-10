import '../generation/operand_range.dart';
import 'level_interpolation.dart';

/// Seule la plage de `percent` varie avec le niveau (min et max s'écartent
/// tous deux) ; le multiplicateur de construction de `base` reste à la
/// plage par défaut du générateur, inchangée depuis l'étape 3.
///
/// Remplace la liste discrète {5, 10, 20, 25, 50} par une plage continue,
/// pour rester cohérent avec le mécanisme d'interpolation linéaire des six
/// autres axes — voir `doc/decisions.md`. L'exactitude de la génération
/// reste garantie par construction quel que soit le pourcentage tiré.
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

/// Valeurs de départ non calibrées — voir `doc/decisions.md`.
const percentageDifficulty = PercentageDifficulty(
  percentMinAtLevel1: 10,
  percentMaxAtLevel1: 50,
  percentMinAtLevel100: 1,
  percentMaxAtLevel100: 99,
);
