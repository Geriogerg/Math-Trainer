import '../models/exercise_type.dart';
import '../persistence/level_cache_entry.dart';

/// Niveau global : moyenne sur les 7 types d'exercice, un type jamais joué
/// comptant au niveau plancher (1 — hors du domaine [1, 100], 0 n'existe
/// pas) plutôt qu'absent de la moyenne. Sans ce plancher, un joueur qui n'a
/// joué qu'à deux types sur sept affiche un niveau global gonflé par
/// l'absence des cinq autres.
///
/// Dans le domaine, pas dans la présentation : c'est aussi la valeur
/// enregistrée avec chaque session (`PersistedSession.overallLevelAfter`),
/// donc une règle de données — la changer rendrait les points de la courbe
/// du Profil incomparables entre eux.
double overallLevel(Map<ExerciseType, LevelCacheEntry> levels) {
  final allLevels = [for (final type in ExerciseType.values) levels[type]?.level ?? 1];
  return allLevels.reduce((a, b) => a + b) / allLevels.length;
}
