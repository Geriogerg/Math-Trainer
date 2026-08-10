/// État persisté du cache de niveau pour une opération : cache recalculable,
/// pas une entité synchronisable (voir `doc/decisions.md`) — c'est pourquoi
/// le stockage sous-jacent utilise une clé composite plutôt qu'un UUID.
class LevelCacheEntry {
  LevelCacheEntry({required this.level, required this.sessionsPlayed, required this.updatedAt}) {
    if (level < 1 || level > 100) {
      throw ArgumentError.value(level, 'level', 'doit être compris entre 1 et 100.');
    }
    if (sessionsPlayed < 0) {
      throw ArgumentError.value(sessionsPlayed, 'sessionsPlayed', 'ne doit pas être négatif.');
    }
    if (!updatedAt.isUtc) {
      throw ArgumentError.value(updatedAt, 'updatedAt', 'doit être en UTC (DateTime.toUtc()).');
    }
  }

  final int level;
  final int sessionsPlayed;
  final DateTime updatedAt;
}
