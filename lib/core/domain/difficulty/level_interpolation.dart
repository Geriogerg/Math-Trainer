/// Linear interpolation between a value at level 1 and a value at level
/// 100 — the mechanism shared by the seven `level → bounds` functions.
/// Monotonic and jump-free by construction.
int interpolateLevel({required int level, required int atLevel1, required int atLevel100}) {
  if (level < 1 || level > 100) {
    throw ArgumentError.value(level, 'level', 'must be between 1 and 100.');
  }
  final t = (level - 1) / 99;
  return (atLevel1 + (atLevel100 - atLevel1) * t).round();
}
