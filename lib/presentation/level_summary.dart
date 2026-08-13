import '../core/domain/models/exercise_type.dart';
import '../core/domain/persistence/level_cache_entry.dart';

/// Moyenne brute d'un ensemble de niveaux, types non communiqués exclus —
/// sert aux comparaisons entre deux instantanés de session de même échelle
/// (courbe d'évolution, variation entre deux sessions, ventilation par
/// opération). `null` si aucun niveau communiqué. Pour le « niveau global »
/// affiché sur l'écran de sélection et l'écran de progression, voir
/// [overallLevel] : la moyenne simple gonflerait ce chiffre en ignorant les
/// types jamais joués.
double? averageLevel(Iterable<int> levels) {
  final values = levels.toList();
  if (values.isEmpty) return null;
  return values.reduce((a, b) => a + b) / values.length;
}

/// Niveau global : moyenne sur les 7 types d'exercice, un type jamais joué
/// comptant au niveau plancher (1 — hors du domaine [1, 100], 0 n'existe
/// pas) plutôt qu'absent de la moyenne. Sans ce plancher, un joueur qui n'a
/// joué qu'à deux types sur sept affiche un niveau global gonflé par
/// l'absence des cinq autres.
double overallLevel(Map<ExerciseType, LevelCacheEntry> levels) {
  final allLevels = [for (final type in ExerciseType.values) levels[type]?.level ?? 1];
  return allLevels.reduce((a, b) => a + b) / allLevels.length;
}
