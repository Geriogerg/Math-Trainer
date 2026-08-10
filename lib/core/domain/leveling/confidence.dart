import 'leveling_rules.dart';
import 'level_cache_entry.dart';

/// Décide quel [ConfidenceMultiplier] appliquer, à partir de l'état de
/// cache actuel d'une opération. `LevelUpdater`/`LevelingRules` ne portent
/// pas cette décision (voir `leveling_rules.dart`) : c'est à l'appelant, qui
/// a l'historique sous la main, de la prendre.
ConfidenceMultiplier confidenceFor({
  required LevelCacheEntry? entry,
  required DateTime now,
  required LevelingRules rules,
}) {
  if (entry == null || entry.sessionsPlayed < 3) {
    return ConfidenceMultiplier.calibration;
  }
  if (now.difference(entry.updatedAt).inDays >= rules.absenceDaysThreshold) {
    return ConfidenceMultiplier.returning;
  }
  return ConfidenceMultiplier.normal;
}
