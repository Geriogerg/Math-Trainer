/// Sentinel distinct de `null`, utilisé par [PersistedAnswer.copyWith] pour
/// distinguer « paramètre non fourni » de « paramètre explicitement mis à
/// `null` » — un simple `champ ?? this.champ` ne peut jamais remettre un
/// champ nullable à `null` volontairement.
const _unset = Object();

class PersistedAnswer {
  PersistedAnswer({
    required this.id,
    required this.sessionId,
    required this.exerciseType,
    required this.operationType,
    required this.operands,
    required this.submittedValue,
    required this.isCorrect,
    required this.elapsedMs,
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
  final String sessionId;
  final String exerciseType;
  final String operationType;
  final Map<String, Object?> operands;
  final num submittedValue;
  final bool isCorrect;
  final int elapsedMs;
  final DateTime createdAt;
  final DateTime? syncedAt;

  PersistedAnswer copyWith({Object? syncedAt = _unset}) {
    return PersistedAnswer(
      id: id,
      sessionId: sessionId,
      exerciseType: exerciseType,
      operationType: operationType,
      operands: operands,
      submittedValue: submittedValue,
      isCorrect: isCorrect,
      elapsedMs: elapsedMs,
      createdAt: createdAt,
      syncedAt: identical(syncedAt, _unset) ? this.syncedAt : syncedAt as DateTime?,
    );
  }

  bool _operandsEqual(Map<String, Object?> other) {
    if (other.length != operands.length) return false;
    for (final entry in operands.entries) {
      if (!other.containsKey(entry.key) || other[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }

  @override
  bool operator ==(Object other) =>
      other is PersistedAnswer &&
      other.id == id &&
      other.sessionId == sessionId &&
      other.exerciseType == exerciseType &&
      other.operationType == operationType &&
      other._operandsEqual(operands) &&
      other.submittedValue == submittedValue &&
      other.isCorrect == isCorrect &&
      other.elapsedMs == elapsedMs &&
      other.createdAt == createdAt &&
      other.syncedAt == syncedAt;

  @override
  int get hashCode => Object.hash(
    id,
    sessionId,
    exerciseType,
    operationType,
    submittedValue,
    isCorrect,
    elapsedMs,
    createdAt,
    syncedAt,
  );
}
