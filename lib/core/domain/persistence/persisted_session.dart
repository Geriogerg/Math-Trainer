import '../models/exercise_type.dart';

/// Voir [PersistedAnswer] pour la raison d'être de ce sentinel.
const _unset = Object();

class PersistedSession {
  PersistedSession({
    required this.id,
    required this.playerId,
    required this.seed,
    required this.enabledTypes,
    required this.exerciseCount,
    required this.totalScore,
    required this.createdAt,
    this.syncedAt,
  }) {
    if (!createdAt.isUtc) {
      throw ArgumentError.value(createdAt, 'createdAt', 'doit être en UTC (DateTime.toUtc()).');
    }
    if (syncedAt != null && !syncedAt!.isUtc) {
      throw ArgumentError.value(syncedAt, 'syncedAt', 'doit être en UTC (DateTime.toUtc()).');
    }
  }

  final String id;
  final String playerId;
  final int seed;
  final Set<ExerciseType> enabledTypes;
  final int exerciseCount;
  final int totalScore;
  final DateTime createdAt;
  final DateTime? syncedAt;

  PersistedSession copyWith({Object? syncedAt = _unset}) {
    return PersistedSession(
      id: id,
      playerId: playerId,
      seed: seed,
      enabledTypes: enabledTypes,
      exerciseCount: exerciseCount,
      totalScore: totalScore,
      createdAt: createdAt,
      syncedAt: identical(syncedAt, _unset) ? this.syncedAt : syncedAt as DateTime?,
    );
  }

  /// Un `Set` n'a pas d'ordre stable à comparer positionnellement — deux
  /// ensembles construits par insertion différente doivent rester égaux
  /// (même piège que `CompositeExerciseGenerator`, ici sur la persistance).
  bool _enabledTypesEqual(Set<ExerciseType> other) {
    if (other.length != enabledTypes.length) return false;
    return enabledTypes.every(other.contains);
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
      other.createdAt == createdAt &&
      other.syncedAt == syncedAt;

  @override
  int get hashCode => Object.hash(
    id,
    playerId,
    seed,
    // Object.hashAllUnordered : le hash ne doit pas dépendre de l'ordre
    // d'itération du Set, pour rester cohérent avec _enabledTypesEqual.
    Object.hashAllUnordered(enabledTypes),
    exerciseCount,
    totalScore,
    createdAt,
    syncedAt,
  );
}
