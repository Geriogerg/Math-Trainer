import '../persistence/level_cache_entry.dart';
import 'leveling_rules.dart';

/// Decides which [ConfidenceMultiplier] to apply, from an operation's
/// current cache state. `LevelUpdater`/`LevelingRules` do not own this
/// decision (see `leveling_rules.dart`): it belongs to the caller, who has
/// the history at hand.
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
