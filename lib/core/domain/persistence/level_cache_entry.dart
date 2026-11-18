/// Persisted state of the level cache for one operation: a recomputable
/// cache, not a syncable entity (see `doc/decisions.md`) — which is why the
/// underlying storage uses a composite key rather than a UUID, and why this
/// type is not named `PersistedLevel` like `PersistedSession`/
/// `PersistedAnswer`: unlike them, it has no identity to
/// sync.
class LevelCacheEntry {
  LevelCacheEntry({required this.level, required this.sessionsPlayed, required this.updatedAt}) {
    if (level < 1 || level > 100) {
      throw ArgumentError.value(level, 'level', 'must be between 1 and 100.');
    }
    if (sessionsPlayed < 0) {
      throw ArgumentError.value(sessionsPlayed, 'sessionsPlayed', 'must not be negative.');
    }
    if (!updatedAt.isUtc) {
      throw ArgumentError.value(updatedAt, 'updatedAt', 'must be UTC (DateTime.toUtc()).');
    }
  }

  final int level;
  final int sessionsPlayed;
  final DateTime updatedAt;
}
