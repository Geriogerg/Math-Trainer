/// Interpolation linéaire entre une valeur à niveau 1 et une valeur à
/// niveau 100 — le mécanisme partagé par les sept fonctions `niveau →
/// bornes`. Monotone et sans saut par construction.
int interpolateLevel({required int level, required int atLevel1, required int atLevel100}) {
  if (level < 1 || level > 100) {
    throw ArgumentError.value(level, 'level', 'doit être compris entre 1 et 100.');
  }
  final t = (level - 1) / 99;
  return (atLevel1 + (atLevel100 - atLevel1) * t).round();
}
