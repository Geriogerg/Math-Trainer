import '../models/operation_type.dart';

/// Voir [PersistedAnswer] pour la raison d'être de ce sentinel.
const _unset = Object();

class PersistedSession {
  PersistedSession({
    required this.id,
    required this.playerId,
    required this.seed,
    required this.operationTypes,
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
  final List<OperationType> operationTypes;
  final int exerciseCount;
  final int totalScore;
  final DateTime createdAt;
  final DateTime? syncedAt;

  PersistedSession copyWith({Object? syncedAt = _unset}) {
    return PersistedSession(
      id: id,
      playerId: playerId,
      seed: seed,
      operationTypes: operationTypes,
      exerciseCount: exerciseCount,
      totalScore: totalScore,
      createdAt: createdAt,
      syncedAt: identical(syncedAt, _unset) ? this.syncedAt : syncedAt as DateTime?,
    );
  }

  bool _operationTypesEqual(List<OperationType> other) {
    if (other.length != operationTypes.length) return false;
    for (var i = 0; i < operationTypes.length; i++) {
      if (other[i] != operationTypes[i]) return false;
    }
    return true;
  }

  @override
  bool operator ==(Object other) =>
      other is PersistedSession &&
      other.id == id &&
      other.playerId == playerId &&
      other.seed == seed &&
      other._operationTypesEqual(operationTypes) &&
      other.exerciseCount == exerciseCount &&
      other.totalScore == totalScore &&
      other.createdAt == createdAt &&
      other.syncedAt == syncedAt;

  @override
  int get hashCode => Object.hash(
    id,
    playerId,
    seed,
    Object.hashAll(operationTypes),
    exerciseCount,
    totalScore,
    createdAt,
    syncedAt,
  );
}
