import '../models/exercise_type.dart';
import '../persistence/level_cache_entry.dart';
import 'level.dart';

/// Overall level: mean over the 7 exercise types, a type never played
/// counting at the floor level (1 — the domain is [1, 100], 0 does not
/// exist) rather than left out of the mean. Without this floor, a player
/// who has played only two types out of seven shows an overall level
/// inflated by the absence of the other five.
///
/// In the domain, not the presentation: it is also the value stored with
/// each session (`PersistedSession.overallLevelAfter`), hence a data rule —
/// changing it would make the Profile curve's points incomparable.
///
/// In level units (37.42, not 3742), as stored before schema v4: points
/// recorded before and after continuous levels stay on one scale. Display
/// only — never a ranking value.
double overallLevel(Map<ExerciseType, LevelCacheEntry> levels) {
  var sum = 0;
  for (final type in ExerciseType.values) {
    sum += (levels[type]?.level ?? Level.floor).hundredths;
  }
  return sum / ExerciseType.values.length / 100;
}
