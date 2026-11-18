import '../models/exercise_type.dart';
import '../persistence/level_cache_entry.dart';

/// Overall level: mean over the 7 exercise types, a type never played
/// counting at the floor level (1 — the domain is [1, 100], 0 does not
/// exist) rather than left out of the mean. Without this floor, a player
/// who has played only two types out of seven shows an overall level
/// inflated by the absence of the other five.
///
/// In the domain, not the presentation: it is also the value stored with
/// each session (`PersistedSession.overallLevelAfter`), hence a data rule —
/// changing it would make the Profile curve's points incomparable.
double overallLevel(Map<ExerciseType, LevelCacheEntry> levels) {
  final allLevels = [for (final type in ExerciseType.values) levels[type]?.level ?? 1];
  return allLevels.reduce((a, b) => a + b) / allLevels.length;
}
