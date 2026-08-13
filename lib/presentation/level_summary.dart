/// Moyenne des niveaux d'une session/du cache courant, types non joués
/// exclus — sert de « niveau global » partout où on en a besoin (écran de
/// progression, repère sur l'écran de sélection). `null` si aucun niveau
/// communiqué.
double? averageLevel(Iterable<int> levels) {
  final values = levels.toList();
  if (values.isEmpty) return null;
  return values.reduce((a, b) => a + b) / values.length;
}
