import '../models/exercise_type.dart';

/// See [PersistedAnswer] for why this sentinel exists.
const _unset = Object();

class PersistedSession {
  PersistedSession({
    required this.id,
    required this.playerId,
    required this.seed,
    required this.enabledTypes,
    required this.exerciseCount,
    required this.totalScore,
    required this.levels,
    required this.createdAt,
    this.overallLevelAfter,
    this.syncedAt,
  }) {
    final overall = overallLevelAfter;
    if (overall != null && (overall < 1 || overall > 100)) {
      throw ArgumentError.value(overall, 'overallLevelAfter', 'must be in [1, 100].');
    }
    if (!createdAt.isUtc) {
      throw ArgumentError.value(createdAt, 'createdAt', 'must be UTC (DateTime.toUtc()).');
    }
    if (syncedAt != null && !syncedAt!.isUtc) {
      throw ArgumentError.value(syncedAt, 'syncedAt', 'must be UTC (DateTime.toUtc()).');
    }
  }

  final String id;
  final String playerId;
  final int seed;
  final Set<ExerciseType> enabledTypes;
  final int exerciseCount;
  final int totalScore;

  /// Per-operation levels frozen when this session was generated — never
  /// recomputed afterwards. May cover only a subset of `ExerciseType` (the
  /// types enabled that session); empty for sessions older than step 4.
  final Map<ExerciseType, int> levels;

  final DateTime createdAt;

  /// The player's overall level (`overallLevel`, 7 types) right after this
  /// session, updated level cache included — what the Profile curve plots.
  /// Unlike [levels] (entry levels, only the session's types), two
  /// successive values are always comparable, and their gap is exactly the
  /// session's effect. `null` for sessions older than schema v3, or if the
  /// cache could not be read when recording.
  final double? overallLevelAfter;

  final DateTime? syncedAt;

  PersistedSession copyWith({String? playerId, Object? syncedAt = _unset}) {
    return PersistedSession(
      id: id,
      playerId: playerId ?? this.playerId,
      seed: seed,
      enabledTypes: enabledTypes,
      exerciseCount: exerciseCount,
      totalScore: totalScore,
      levels: levels,
      createdAt: createdAt,
      overallLevelAfter: overallLevelAfter,
      syncedAt: identical(syncedAt, _unset) ? this.syncedAt : syncedAt as DateTime?,
    );
  }

  /// A `Set` has no stable order to compare positionally — two sets built
  /// by different insertion orders must stay equal (same pitfall as
  /// `CompositeExerciseGenerator`, here on persistence).
  bool _enabledTypesEqual(Set<ExerciseType> other) {
    if (other.length != enabledTypes.length) return false;
    return enabledTypes.every(other.contains);
  }

  /// Same pitfall as `enabledTypes`, for a `Map`: iteration order must not
  /// affect equality.
  bool _levelsEqual(Map<ExerciseType, int> other) {
    if (other.length != levels.length) return false;
    for (final entry in levels.entries) {
      if (other[entry.key] != entry.value) return false;
    }
    return true;
  }

  @override
  bool operator ==(Object other) =>
      other is PersistedSession &&
      other.id == id &&
      other.playerId == playerId &&
      other.seed == seed &&
      other._enabledTypesEqual(enabledTypes) &&
      other.exerciseCount == exerciseCount &&
      other.totalScore == totalScore &&
      other._levelsEqual(levels) &&
      other.createdAt == createdAt &&
      other.overallLevelAfter == overallLevelAfter &&
      other.syncedAt == syncedAt;

  @override
  int get hashCode => Object.hash(
    id,
    playerId,
    seed,
    // Object.hashAllUnordered: the hash must not depend on the Set/Map
    // iteration order, to stay consistent with equality.
    Object.hashAllUnordered(enabledTypes),
    exerciseCount,
    totalScore,
    Object.hashAllUnordered(levels.entries.map((e) => Object.hash(e.key, e.value))),
    createdAt,
    overallLevelAfter,
    syncedAt,
  );
}
