import '../leveling/level.dart';
import '../leveling/rules_version.dart';
import '../models/exercise_type.dart';
import '../models/session_kind.dart';

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
    this.kind = SessionKind.game,
    this.typeSequence,
    this.uploadRefused,
    this.appVersion,
    this.rulesVersion = RulesVersion.v1,
  }) {
    final version = appVersion;
    if (version != null &&
        (version.isEmpty || version.length > maxAppVersionLength)) {
      throw ArgumentError.value(
        version,
        'appVersion',
        'must be 1 to $maxAppVersionLength characters.',
      );
    }
    final sequence = typeSequence;
    if (sequence != null && sequence.length != exerciseCount) {
      throw ArgumentError.value(
        sequence.length,
        'typeSequence',
        'must hold one type per planned question ($exerciseCount).',
      );
    }
    final overall = overallLevelAfter;
    if (overall != null && (overall < 1 || overall > 100)) {
      throw ArgumentError.value(
        overall,
        'overallLevelAfter',
        'must be in [1, 100].',
      );
    }
    if (!createdAt.isUtc) {
      throw ArgumentError.value(
        createdAt,
        'createdAt',
        'must be UTC (DateTime.toUtc()).',
      );
    }
    if (syncedAt != null && !syncedAt!.isUtc) {
      throw ArgumentError.value(
        syncedAt,
        'syncedAt',
        'must be UTC (DateTime.toUtc()).',
      );
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
  /// In hundredths (schema v4 migrated older rows ×100).
  final Map<ExerciseType, Level> levels;

  final DateTime createdAt;

  /// The player's main level (`mainLevel`, the four basics; before schema
  /// v9 the mean of seven types, recomputed then) right after this
  /// session, updated level cache included — what the Profile curve plots.
  /// Unlike [levels] (entry levels, only the session's types), two
  /// successive values are always comparable, and their gap is exactly the
  /// session's effect. `null` for sessions older than schema v3, or if the
  /// cache could not be read when recording.
  final double? overallLevelAfter;

  final DateTime? syncedAt;

  /// Game or placement (schema v5; older rows are games).
  final SessionKind kind;

  /// The type of every planned question, in order (schema v6): with
  /// [seed], [levels] and [kind], all a replay needs. Rows from before v6
  /// were backfilled from their answers when complete; an older
  /// interrupted session has `null` and cannot be replayed.
  final List<ExerciseType>? typeSequence;

  /// Why the server refused this session (schema v7, `upload_refused`): a
  /// `RejectionReason` name, or `notReplayable` decided on the device.
  /// `null` while pending or once accepted. Set by
  /// `SessionRepository.markUploadRefused`, never when recording.
  final String? uploadRefused;

  /// The build that played it (schema v8): the commit's first 7 characters
  /// from CI, `dev` locally — to set aside games of a faulty build.
  /// `null` for sessions stored before v8.
  final String? appVersion;

  static const maxAppVersionLength = 40;

  /// The rules it was played under (schema v10, `doc/levels.md` section
  /// 4). Sessions stored before have none: [RulesVersion.v1].
  final RulesVersion rulesVersion;

  PersistedSession copyWith({
    String? playerId,
    Object? syncedAt = _unset,
    Object? uploadRefused = _unset,
  }) {
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
      syncedAt: identical(syncedAt, _unset)
          ? this.syncedAt
          : syncedAt as DateTime?,
      kind: kind,
      typeSequence: typeSequence,
      uploadRefused: identical(uploadRefused, _unset)
          ? this.uploadRefused
          : uploadRefused as String?,
      appVersion: appVersion,
      rulesVersion: rulesVersion,
    );
  }

  bool _typeSequenceEqual(List<ExerciseType>? other) {
    final mine = typeSequence;
    if (mine == null || other == null) return mine == other;
    if (mine.length != other.length) return false;
    for (var i = 0; i < mine.length; i++) {
      if (mine[i] != other[i]) return false;
    }
    return true;
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
  bool _levelsEqual(Map<ExerciseType, Level> other) {
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
      other.syncedAt == syncedAt &&
      other.kind == kind &&
      other._typeSequenceEqual(typeSequence) &&
      other.uploadRefused == uploadRefused &&
      other.appVersion == appVersion &&
      other.rulesVersion == rulesVersion;

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
    Object.hashAllUnordered(
      levels.entries.map((e) => Object.hash(e.key, e.value)),
    ),
    createdAt,
    overallLevelAfter,
    syncedAt,
    kind,
    typeSequence == null ? null : Object.hashAll(typeSequence!),
    uploadRefused,
    appVersion,
    rulesVersion,
  );
}
