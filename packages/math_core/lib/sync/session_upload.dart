import '../leveling/level.dart';
import '../models/exercise_type.dart';
import '../models/input_device.dart';
import '../models/session_kind.dart';
import '../persistence/persisted_answer.dart';
import '../persistence/persisted_session.dart';
import '../placement/placement.dart';

/// One stored session as the app uploads it and the server replays it
/// (plan, Phase 2 commit 5): the session's stored fields and its answers in
/// the order given. The same codec on both sides — a field cannot drift.
///
/// Optional, added after Phase 3a without a new [formatVersion]: the app
/// version and each answer's input device — absent from sessions stored
/// before (schema v8), ignored by an older server.
///
/// Not uploaded: the score and the overall level after (the server
/// computes what counts), `syncedAt` (the server's to set).
class SessionUpload {
  SessionUpload({required this.session, required List<PersistedAnswer> answers})
    : answers = List.unmodifiable(answers) {
    for (final answer in answers) {
      if (answer.sessionId != session.id) {
        throw ArgumentError.value(
          answer.sessionId,
          'answers',
          'an answer of another session (expected ${session.id}).',
        );
      }
    }
  }

  /// Bumped on any incompatible change; the server refuses what it does not
  /// know.
  static const formatVersion = 1;

  final PersistedSession session;
  final List<PersistedAnswer> answers;

  Map<String, Object?> toJson() => {
    'formatVersion': formatVersion,
    'session': {
      'id': session.id,
      'playerId': session.playerId,
      'seed': session.seed,
      'kind': session.kind.name,
      // Sorted: a set has no order, the payload must be stable.
      'enabledTypes': [
        for (final t in ExerciseType.values)
          if (session.enabledTypes.contains(t)) t.name,
      ],
      'exerciseCount': session.exerciseCount,
      'levels': {
        for (final t in ExerciseType.values)
          if (session.levels[t] case final level?) t.name: level.hundredths,
      },
      'typeSequence': [for (final t in _typeSequenceOf(session)) t.name],
      'createdAt': session.createdAt.toIso8601String(),
      'appVersion': ?session.appVersion,
    },
    'answers': [
      for (final a in answers)
        {
          'id': a.id,
          'exerciseType': a.exerciseType,
          'operationType': a.operationType,
          'operands': a.operands,
          'submittedValue': a.submittedValue,
          'isCorrect': a.isCorrect,
          'elapsedMs': a.elapsedMs,
          'answeredAt': a.createdAt.toIso8601String(),
          'inputDevice': ?a.inputDevice?.name,
        },
    ],
  };

  /// Strict: any missing or mistyped field throws [FormatException] — the
  /// server answers 400, never guesses. Every invariant of the models still
  /// applies (UTC timestamps, level range, one type per planned question).
  factory SessionUpload.fromJson(Object? json) {
    final root = _map(json, 'upload');
    if (root['formatVersion'] != formatVersion) {
      throw FormatException('unknown formatVersion ${root['formatVersion']}');
    }
    final s = _map(root['session'], 'session');
    final id = _string(s, 'id');
    try {
      final session = PersistedSession(
        id: id,
        playerId: _string(s, 'playerId'),
        seed: _int(s, 'seed'),
        enabledTypes: {
          for (final name in _list(s, 'enabledTypes')) _type(name),
        },
        exerciseCount: _int(s, 'exerciseCount'),
        // Not uploaded: the server never reads it.
        totalScore: 0,
        levels: {
          for (final MapEntry(:key, :value) in _map(
            s['levels'],
            'levels',
          ).entries)
            _type(key): Level.fromHundredths(_asInt(value, 'levels.$key')),
        },
        createdAt: _utc(s, 'createdAt'),
        kind: _kind(_string(s, 'kind')),
        typeSequence: [
          for (final name in _list(s, 'typeSequence')) _type(name),
        ],
        appVersion: _optionalString(s, 'appVersion'),
      );
      final answers = [
        for (final (i, raw) in _list(root, 'answers').indexed)
          _answer(_map(raw, 'answers[$i]'), id),
      ];
      return SessionUpload(session: session, answers: answers);
    } on ArgumentError catch (e) {
      // A model invariant (range, UTC, sequence length): bad input too.
      throw FormatException('invalid upload: ${e.message}');
    }
  }
}

/// A placement stored before schema v6 has no sequence, but its order is
/// fixed by its rules: exact. A game without one is never uploaded
/// (`SessionUploadQueue`).
List<ExerciseType> _typeSequenceOf(PersistedSession session) =>
    session.typeSequence ??
    (session.kind.isPlacement
        ? placementTypeSequence(placementRulesFor(session.kind))
        : const []);

PersistedAnswer _answer(Map<String, Object?> a, String sessionId) {
  final operands = _map(a['operands'], 'operands');
  for (final MapEntry(:key, :value) in operands.entries) {
    if (value is! int) throw FormatException('operand $key is not an int');
  }
  return PersistedAnswer(
    id: _string(a, 'id'),
    sessionId: sessionId,
    exerciseType: _string(a, 'exerciseType'),
    operationType: _string(a, 'operationType'),
    operands: operands,
    submittedValue: _int(a, 'submittedValue'),
    isCorrect: _bool(a, 'isCorrect'),
    elapsedMs: _int(a, 'elapsedMs'),
    createdAt: _utc(a, 'answeredAt'),
    inputDevice: switch (_optionalString(a, 'inputDevice')) {
      null => null,
      final name => _inputDevice(name),
    },
  );
}

Map<String, Object?> _map(Object? v, String what) {
  if (v is! Map) throw FormatException('$what is not an object');
  return v.cast<String, Object?>();
}

List<Object?> _list(Map<String, Object?> m, String key) {
  final v = m[key];
  if (v is! List) throw FormatException('$key is not a list');
  return v;
}

String _string(Map<String, Object?> m, String key) {
  final v = m[key];
  if (v is! String || v.isEmpty) throw FormatException('$key is not a string');
  return v;
}

/// Absent or `null`: not known (stored before the field existed).
String? _optionalString(Map<String, Object?> m, String key) =>
    m[key] == null ? null : _string(m, key);

int _int(Map<String, Object?> m, String key) => _asInt(m[key], key);

int _asInt(Object? v, String key) {
  if (v is! int) throw FormatException('$key is not an integer');
  return v;
}

bool _bool(Map<String, Object?> m, String key) {
  final v = m[key];
  if (v is! bool) throw FormatException('$key is not a boolean');
  return v;
}

DateTime _utc(Map<String, Object?> m, String key) {
  final parsed = DateTime.tryParse(_string(m, key));
  if (parsed == null || !parsed.isUtc) {
    throw FormatException('$key is not a UTC timestamp');
  }
  return parsed;
}

ExerciseType _type(Object? name) {
  for (final t in ExerciseType.values) {
    if (t.name == name) return t;
  }
  throw FormatException('unknown exercise type $name');
}

SessionKind _kind(String name) {
  for (final k in SessionKind.values) {
    if (k.name == name) return k;
  }
  throw FormatException('unknown session kind $name');
}

InputDevice _inputDevice(String name) {
  for (final d in InputDevice.values) {
    if (d.name == name) return d;
  }
  throw FormatException('unknown input device $name');
}
