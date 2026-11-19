import '../leveling/level.dart';

/// Persisted state of the level cache for one operation: a recomputable
/// cache, not a syncable entity (see `doc/decisions.md`) — which is why the
/// underlying storage uses a composite key rather than a UUID, and why this
/// type is not named `PersistedLevel` like `PersistedSession`/
/// `PersistedAnswer`: unlike them, it has no identity to
/// sync.
class LevelCacheEntry {
  LevelCacheEntry({
    required this.level,
    required this.sessionsPlayed,
    required this.updatedAt,
  }) {
    if (sessionsPlayed < 0) {
      throw ArgumentError.value(
        sessionsPlayed,
        'sessionsPlayed',
        'must not be negative.',
      );
    }
    if (!updatedAt.isUtc) {
      throw ArgumentError.value(
        updatedAt,
        'updatedAt',
        'must be UTC (DateTime.toUtc()).',
      );
    }
  }

  /// In hundredths since schema v4; its range is checked by [Level].
  final Level level;
  final int sessionsPlayed;
  final DateTime updatedAt;
}
