import 'dart:convert';

import 'package:math_core/leveling/level.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/models/input_device.dart';
import 'package:math_core/models/session_kind.dart';
import 'package:math_core/persistence/level_cache_entry.dart';
import 'package:math_core/persistence/persisted_answer.dart';
import 'package:math_core/persistence/persisted_session.dart';
import 'package:math_core/placement/placement.dart';
import 'package:math_core/sync/session_upload.dart';
import 'package:math_core/sync/session_upload_client.dart';
import 'package:test/test.dart';

void main() {
  final session = PersistedSession(
    id: 'session-1',
    playerId: 'player-1',
    seed: 1763510400123,
    enabledTypes: const {ExerciseType.division, ExerciseType.addition},
    exerciseCount: 2,
    totalScore: 77,
    levels: {
      ExerciseType.addition: Level.fromHundredths(3742),
      ExerciseType.division: Level.floor,
    },
    createdAt: DateTime.utc(2026, 11, 19, 10, 30),
    typeSequence: const [ExerciseType.division, ExerciseType.addition],
  );
  final answers = [
    PersistedAnswer(
      id: 'a-1',
      sessionId: 'session-1',
      exerciseType: 'arithmetic',
      operationType: 'division',
      operands: const {'operandA': 12, 'operandB': 3},
      submittedValue: 4,
      isCorrect: true,
      elapsedMs: 1830,
      createdAt: DateTime.utc(2026, 11, 19, 10, 29, 50),
    ),
    PersistedAnswer(
      id: 'a-2',
      sessionId: 'session-1',
      exerciseType: 'arithmetic',
      operationType: 'addition',
      operands: const {'operandA': 40, 'operandB': 2},
      submittedValue: -1,
      isCorrect: false,
      elapsedMs: 15000,
      createdAt: DateTime.utc(2026, 11, 19, 10, 30),
    ),
  ];

  Map<String, Object?> json() => jsonDecode(
    jsonEncode(SessionUpload(session: session, answers: answers).toJson()),
  );

  test('round-trips through JSON text, score and syncedAt left out', () {
    final back = SessionUpload.fromJson(json());
    expect(back.session.id, session.id);
    expect(back.session.seed, session.seed);
    expect(back.session.enabledTypes, session.enabledTypes);
    expect(back.session.levels, session.levels);
    expect(back.session.typeSequence, session.typeSequence);
    expect(back.session.createdAt, session.createdAt);
    expect(back.session.kind, SessionKind.game);
    expect(back.session.totalScore, 0);
    expect(back.answers, answers);
  });

  test('the payload is stable: types sorted whatever the set order', () {
    final j = json();
    expect((j['session'] as Map)['enabledTypes'], ['addition', 'division']);
  });

  group('refuses', () {
    void expectBad(void Function(Map<String, Object?> j) corrupt) {
      final j = json();
      corrupt(j);
      expect(() => SessionUpload.fromJson(j), throwsFormatException);
    }

    Map<String, Object?> s(Map<String, Object?> j) =>
        (j['session'] as Map).cast<String, Object?>();
    Map<String, Object?> a0(Map<String, Object?> j) =>
        ((j['answers'] as List).first as Map).cast<String, Object?>();

    test('an unknown format version', () {
      expectBad((j) => j['formatVersion'] = 2);
    });
    test('a missing or mistyped field', () {
      expectBad((j) => s(j).remove('seed'));
      expectBad((j) => s(j)['seed'] = '1');
      expectBad((j) => a0(j)['isCorrect'] = 1);
      expectBad((j) => a0(j)['operands'] = {'operandA': 1.5});
    });
    test('an unknown type or kind', () {
      expectBad((j) => s(j)['enabledTypes'] = ['cube']);
      expectBad((j) => s(j)['kind'] = 'duel');
    });
    test('a timestamp that is not UTC', () {
      expectBad((j) => s(j)['createdAt'] = '2026-11-19T10:30:00');
      expectBad((j) => a0(j)['answeredAt'] = 'yesterday');
    });
    test('a level out of range, a sequence of the wrong length', () {
      expectBad((j) => (s(j)['levels'] as Map)['addition'] = 0);
      expectBad((j) => s(j)['typeSequence'] = ['addition']);
    });
  });

  test('an answer of another session is refused at construction', () {
    expect(
      () => SessionUpload(
        session: session,
        answers: [
          PersistedAnswer(
            id: 'x',
            sessionId: 'other',
            exerciseType: 'arithmetic',
            operationType: 'addition',
            operands: const {},
            submittedValue: 1,
            isCorrect: true,
            elapsedMs: 1,
            createdAt: DateTime.utc(2026),
          ),
        ],
      ),
      throwsArgumentError,
    );
  });

  test('a placement stored without a sequence gets its rules\' order', () {
    final placement = PersistedSession(
      id: 'p',
      playerId: 'player-1',
      seed: 1,
      enabledTypes: placementTypes.toSet(),
      exerciseCount: placementRulesV1.questionCount,
      totalScore: 0,
      levels: {for (final t in placementTypes) t: Level.whole(35)},
      createdAt: DateTime.utc(2026, 11, 19),
      kind: SessionKind.placementV1,
    );
    final j = SessionUpload(session: placement, answers: const []).toJson();
    final back = SessionUpload.fromJson(jsonDecode(jsonEncode(j)));
    expect(back.session.typeSequence, placementTypeSequence(placementRulesV1));
  });

  group('app version and input device (after Phase 3a)', () {
    final recorded = PersistedSession(
      id: 'session-1',
      playerId: 'player-1',
      seed: 1,
      enabledTypes: const {ExerciseType.addition},
      exerciseCount: 3,
      totalScore: 0,
      levels: {ExerciseType.addition: Level.floor},
      createdAt: DateTime.utc(2026, 11, 20),
      typeSequence: const [
        ExerciseType.addition,
        ExerciseType.addition,
        ExerciseType.addition,
      ],
      appVersion: 'e9bd019',
    );
    PersistedAnswer answer(String id, InputDevice? device) => PersistedAnswer(
      id: id,
      sessionId: 'session-1',
      exerciseType: 'arithmetic',
      operationType: 'addition',
      operands: const {'operandA': 1, 'operandB': 2},
      submittedValue: 3,
      isCorrect: true,
      elapsedMs: 900,
      createdAt: DateTime.utc(2026, 11, 20),
      inputDevice: device,
    );
    Map<String, Object?> upload() => jsonDecode(
      jsonEncode(
        SessionUpload(
          session: recorded,
          answers: [
            answer('a', InputDevice.keypad),
            answer('b', InputDevice.keyboard),
            answer('c', null),
          ],
        ).toJson(),
      ),
    );

    test('round-trip; an unknown device stays absent', () {
      final j = upload();
      expect((j['session']! as Map)['appVersion'], 'e9bd019');
      final sent = (j['answers']! as List).cast<Map>();
      expect(sent.map((a) => a['inputDevice']), ['keypad', 'keyboard', null]);
      expect(sent[2].containsKey('inputDevice'), isFalse);
      final back = SessionUpload.fromJson(j);
      expect(back.session.appVersion, 'e9bd019');
      expect(back.answers.map((a) => a.inputDevice), [
        InputDevice.keypad,
        InputDevice.keyboard,
        null,
      ]);
    });

    test('a session stored before them uploads and parses as before', () {
      final j = json();
      expect((j['session']! as Map).containsKey('appVersion'), isFalse);
      final back = SessionUpload.fromJson(j);
      expect(back.session.appVersion, isNull);
      expect(back.answers.map((a) => a.inputDevice), everyElement(isNull));
    });

    test('refuses an unknown device or a malformed version', () {
      final badDevice = upload();
      ((badDevice['answers']! as List).first as Map)['inputDevice'] = 'mouse';
      expect(() => SessionUpload.fromJson(badDevice), throwsFormatException);
      for (final version in <Object>['', 42, 'x' * 41]) {
        final bad = upload();
        (bad['session']! as Map)['appVersion'] = version;
        expect(() => SessionUpload.fromJson(bad), throwsFormatException);
      }
    });
  });

  test('server levels round-trip', () {
    final levels = {
      ExerciseType.power: LevelCacheEntry(
        level: Level.fromHundredths(1234),
        sessionsPlayed: 3,
        updatedAt: DateTime.utc(2026, 11, 2),
      ),
    };
    final back = levelCacheFromJson(
      jsonDecode(jsonEncode(levelCacheToJson(levels))),
    );
    expect(back.keys, [ExerciseType.power]);
    expect(back[ExerciseType.power]!.level, Level.fromHundredths(1234));
    expect(back[ExerciseType.power]!.sessionsPlayed, 3);
    expect(back[ExerciseType.power]!.updatedAt, DateTime.utc(2026, 11, 2));
    expect(() => levelCacheFromJson({'power': {}}), throwsFormatException);
  });
}
