import 'dart:math';

import 'package:math_core/generation/composite_exercise_generator.dart';
import 'package:math_core/leveling/level.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/models/input_device.dart';
import 'package:math_core/persistence/exercise_codec.dart';
import 'package:math_core/persistence/persisted_answer.dart';
import 'package:math_core/persistence/persisted_session.dart';
import 'package:math_core/sync/session_upload.dart';
import 'package:test/test.dart';

/// Phase 3a commit 8: what Phase 3b calibrates from must be in every
/// uploaded answer. The same requirements as the SQL view
/// `owner_dashboard.data_check` — six, then the input device and the app
/// version (owner decision after Phase 3a) — checked here on the format
/// itself, for all seven operations, so a change to the upload cannot drop
/// one.
void main() {
  const expectedOperands = {
    ExerciseType.addition: {'operandA', 'operandB'},
    ExerciseType.subtraction: {'operandA', 'operandB'},
    ExerciseType.multiplication: {'operandA', 'operandB'},
    ExerciseType.division: {'operandA', 'operandB'},
    ExerciseType.power: {'base', 'exponent'},
    ExerciseType.squareRoot: {'radicand'},
    ExerciseType.percentage: {'percent', 'base'},
    ExerciseType.integral: {'lower', 'upper', 'c0', 'c1', 'c2', 'c3'},
  };

  test('every operation uploads operation, level, time, correctness, '
      'structure, time answered, input device and app version', () {
    final at = DateTime.utc(2026, 11, 21, 10);
    final random = Random(3);
    final types = ExerciseType.values.toList();
    final answers = <PersistedAnswer>[
      for (final (i, type) in types.indexed)
        () {
          final q = exerciseGeneratorFor(type, 40).next(random);
          final d = describeExerciseForStorage(q);
          return PersistedAnswer(
            id: 'a$i',
            sessionId: 's',
            exerciseType: d.exerciseType,
            operationType: d.operationType,
            operands: d.operands,
            submittedValue: q.correctAnswer,
            isCorrect: true,
            elapsedMs: 1000 + i,
            createdAt: at,
            inputDevice: InputDevice.values[i % InputDevice.values.length],
          );
        }(),
    ];
    final json = SessionUpload(
      session: PersistedSession(
        id: 's',
        playerId: 'p',
        seed: 1,
        enabledTypes: types.toSet(),
        exerciseCount: types.length,
        totalScore: 0,
        levels: {for (final t in types) t: Level.whole(40)},
        createdAt: at,
        typeSequence: types,
        appVersion: 'e9bd019',
      ),
      answers: answers,
    ).toJson();

    final session = json['session']! as Map<String, Object?>;
    final levels = session['levels']! as Map<String, Object?>;
    for (final (i, a) in (json['answers']! as List).cast<Map>().indexed) {
      final type = types[i];
      expect(a['operationType'], type.name, reason: 'operation');
      expect(levels[a['operationType']], isA<int>(), reason: 'level');
      expect(a['elapsedMs'], isA<int>(), reason: 'time');
      expect(a['isCorrect'], isA<bool>(), reason: 'correctness');
      expect(a['submittedValue'], isA<int>(), reason: 'typed value');
      final operands = a['operands']! as Map;
      expect(operands.keys.toSet(), expectedOperands[type], reason: type.name);
      expect(operands.values, everyElement(isA<int>()), reason: 'integers');
      expect(
        DateTime.tryParse(a['answeredAt']! as String),
        isNotNull,
        reason: 'time answered',
      );
      expect(
        InputDevice.values.map((d) => d.name),
        contains(a['inputDevice']),
        reason: 'input device',
      );
    }
    expect(session['appVersion'], 'e9bd019', reason: 'app version');
    // A placement's level is replayed from these.
    expect(session['seed'], isA<int>());
    expect(session['typeSequence'], hasLength(session['exerciseCount']));
  });
}
