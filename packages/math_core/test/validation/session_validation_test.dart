import 'package:math_core/leveling/level.dart';
import 'package:math_core/leveling/level_updates.dart';
import 'package:math_core/leveling/rules_version.dart';
import 'package:math_core/models/game_setup.dart';
import 'package:math_core/models/answer_result.dart';
import 'package:math_core/models/exercise.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/persistence/exercise_codec.dart';
import 'package:math_core/persistence/level_cache_entry.dart';
import 'package:math_core/persistence/persisted_answer.dart';
import 'package:math_core/persistence/persisted_session.dart';
import 'package:math_core/models/session_kind.dart';
import 'package:math_core/replay/session_replay.dart';
import 'package:math_core/sync/session_upload.dart';
import 'package:math_core/validation/session_validation.dart';
import 'package:test/test.dart';

final _received = DateTime.utc(2026, 11, 20, 12);

/// An honest player's upload: the questions the app would have asked
/// (the same replay the server runs), answered by [answer].
SessionUpload honestGame({
  String id = 's1',
  String player = 'p1',
  DateTime? at,
  Map<ExerciseType, Level>? levels,
  int count = 8,
  int? answered,
  int seed = 777,
  SessionKind kind = SessionKind.game,
  RulesVersion rulesVersion = RulesVersion.current,
  ({int value, int ms}) Function(int i, Exercise q)? answer,
}) {
  final types = {ExerciseType.addition, ExerciseType.multiplication};
  final createdAt = at ?? DateTime.utc(2026, 11, 20, 11);
  final session = PersistedSession(
    id: id,
    playerId: player,
    seed: seed,
    enabledTypes: types,
    exerciseCount: count,
    totalScore: 0,
    levels: levels ?? {for (final t in types) t: Level.zero},
    createdAt: createdAt,
    kind: kind,
    typeSequence: [
      for (var i = 0; i < count; i++)
        i.isEven ? ExerciseType.addition : ExerciseType.multiplication,
    ],
    rulesVersion: rulesVersion,
  );
  final questions = replaySessionQuestions(session, answered ?? count);
  return SessionUpload(
    session: session,
    answers: [
      for (final (i, q) in questions.indexed)
        _answerOf(
          id,
          i,
          q,
          answer?.call(i, q) ?? (value: q.correctAnswer, ms: 1500 + 97 * i),
          createdAt,
        ),
    ],
  );
}

PersistedAnswer _answerOf(
  String sessionId,
  int i,
  Exercise q,
  ({int value, int ms}) given,
  DateTime at,
) {
  final d = describeExerciseForStorage(q);
  return PersistedAnswer(
    id: '$sessionId-$i',
    sessionId: sessionId,
    exerciseType: d.exerciseType,
    operationType: d.operationType,
    operands: d.operands,
    submittedValue: given.value,
    isCorrect: q.isCorrectAnswer(given.value),
    elapsedMs: given.ms,
    createdAt: at,
  );
}

ValidationResult validate(
  SessionUpload upload, {
  ServerPlayerState state = ServerPlayerState.empty,
  String caller = 'p1',
}) => validateSessionUpload(
  upload: upload,
  callerId: caller,
  state: state,
  receivedAt: _received,
);

/// A copy of [upload] with answer [index] replaced.
SessionUpload tamper(
  SessionUpload upload,
  int index,
  PersistedAnswer Function(PersistedAnswer a) change,
) => SessionUpload(
  session: upload.session,
  answers: [
    for (final (i, a) in upload.answers.indexed) i == index ? change(a) : a,
  ],
);

PersistedAnswer copyAnswer(
  PersistedAnswer a, {
  Map<String, Object?>? operands,
  int? submittedValue,
  bool? isCorrect,
  int? elapsedMs,
}) => PersistedAnswer(
  id: a.id,
  sessionId: a.sessionId,
  exerciseType: a.exerciseType,
  operationType: a.operationType,
  operands: operands ?? a.operands,
  submittedValue: submittedValue ?? a.submittedValue,
  isCorrect: isCorrect ?? a.isCorrect,
  elapsedMs: elapsedMs ?? a.elapsedMs,
  createdAt: a.createdAt,
);

void main() {
  group('rules (doc/levels.md)', () {
    test('an honest game from 0: each operation moved by its quality', () {
      // Additions fluent, multiplications right but slow.
      final upload = honestGame(
        answer: (i, q) => (value: q.correctAnswer, ms: i.isEven ? 1000 : 20000),
      );
      final result = validate(upload) as Accepted;
      expect(
        result.levelUpdates[ExerciseType.addition]!.level,
        Level.fromHundredths(300),
      );
      expect(
        result.levelUpdates[ExerciseType.multiplication]!.level,
        Level.fromHundredths(156), // rules v3: +1.56 all slow
      );
    });

    test('a session of retired rules (v1) is refused, never replayed', () {
      final v2 = honestGame();
      final s = v2.session;
      final v1 = SessionUpload(
        session: PersistedSession(
          id: s.id,
          playerId: s.playerId,
          seed: s.seed,
          enabledTypes: s.enabledTypes,
          exerciseCount: s.exerciseCount,
          totalScore: 0,
          levels: s.levels,
          createdAt: s.createdAt,
          typeSequence: s.typeSequence,
        ),
        answers: v2.answers,
      );
      expect(v1.session.rulesVersion, RulesVersion.v1);
      final result = validate(v1) as Rejected;
      expect(result.reason, RejectionReason.rulesRetired);
    });

    test('a placement is refused: there is none any more', () {
      for (final kind in [
        SessionKind.placementV1,
        SessionKind.placementV2,
        SessionKind.typePlacementV3,
      ]) {
        final v2 = honestGame();
        final s = v2.session;
        final placement = SessionUpload(
          session: PersistedSession(
            id: s.id,
            playerId: s.playerId,
            seed: s.seed,
            enabledTypes: s.enabledTypes,
            exerciseCount: s.exerciseCount,
            totalScore: 0,
            levels: s.levels,
            createdAt: s.createdAt,
            typeSequence: s.typeSequence,
            kind: kind,
            rulesVersion: RulesVersion.v2,
          ),
          answers: v2.answers,
        );
        final result = validate(placement) as Rejected;
        expect(result.reason, RejectionReason.notReplayable, reason: '$kind');
      }
    });

    test("a game claiming rules v1's level 1 for a new player is refused", () {
      final result = validate(
        honestGame(
          levels: {
            ExerciseType.addition: Level.whole(1),
            ExerciseType.multiplication: Level.whole(1),
          },
        ),
      );
      expect((result as Rejected).reason, RejectionReason.levelsMismatch);
    });

    test("a plan other than the setup's (3 questions each) cannot replay", () {
      final v2 = honestGame();
      final s = v2.session;
      final upload = SessionUpload(
        session: PersistedSession(
          id: s.id,
          playerId: s.playerId,
          seed: s.seed,
          enabledTypes: s.enabledTypes,
          exerciseCount: 6,
          totalScore: 0,
          levels: s.levels,
          createdAt: s.createdAt,
          typeSequence: s.typeSequence!.take(6).toList(),
          rulesVersion: RulesVersion.v2,
        ),
        answers: v2.answers.take(6).toList(),
      );
      final result = validate(upload);
      expect((result as Rejected).reason, RejectionReason.notReplayable);
    });
  });

  group('an honest game', () {
    test('each session under its own rules: v2 still replayed under v2, v3 '
        'under v3; a v3 game chains from v2 levels (no reset)', () {
      // One wrong answer per operation (the sequence alternates): 3 / 4
      // fluent, q = 0.75 — +1.2 under v2, +0.36 under v3.
      ({int value, int ms}) oneWrong(int i, Exercise q) => i < 2
          ? (value: q.correctAnswer + 1, ms: 1500)
          : (value: q.correctAnswer, ms: 1500 + 97 * i);
      final types = [ExerciseType.addition, ExerciseType.multiplication];
      final v2 =
          validate(honestGame(rulesVersion: RulesVersion.v2, answer: oneWrong))
              as Accepted;
      final v3 =
          validate(honestGame(rulesVersion: RulesVersion.v3, answer: oneWrong))
              as Accepted;
      for (final t in types) {
        expect(v2.levelUpdates[t]!.level, Level.fromHundredths(120));
        expect(v3.levelUpdates[t]!.level, Level.fromHundredths(36));
      }
      final next = honestGame(
        id: 's2',
        at: DateTime.utc(2026, 11, 20, 11, 5),
        rulesVersion: RulesVersion.v3,
        levels: {for (final t in types) t: v2.newState.levels[t]!.level},
      );
      final chained = validate(next, state: v2.newState) as Accepted;
      expect(
        chained.levelUpdates[ExerciseType.addition]!.level,
        Level.fromHundredths(420), // 1.2 + 3: a perfect game's cap
      );
    });

    test('accepted; levels exactly what the app computes', () {
      final upload = honestGame();
      final result = validate(upload) as Accepted;

      expect(result.completed, isTrue);
      final appSide = gameLevelUpdates(
        outcomes: [
          for (final (i, q) in replaySessionQuestions(
            upload.session,
            upload.answers.length,
          ).indexed)
            AnswerResult(
              exercise: q,
              submittedValue: upload.answers[i].submittedValue,
              isCorrect: upload.answers[i].isCorrect,
              elapsedMs: upload.answers[i].elapsedMs,
              answeredAt: upload.answers[i].createdAt,
            ),
        ],
        frozenLevels: upload.session.levels,
        priorLevels: const {},
        now: upload.session.createdAt,
        rulesVersion: upload.session.rulesVersion,
      );
      expect(result.levelUpdates.keys, appSide.keys);
      for (final type in appSide.keys) {
        expect(result.levelUpdates[type]!.level, appSide[type]!.level);
        expect(result.levelUpdates[type]!.sessionsPlayed, 1);
      }
      expect(result.newState.lastSessionAt, upload.session.createdAt);
      expect(result.newState.hasCompletedSession, isTrue);
      expect(result.flags, isEmpty);
    });

    test('the chain: the next game starts from the new levels', () {
      final first = validate(honestGame()) as Accepted;
      final next = honestGame(
        id: 's2',
        at: DateTime.utc(2026, 11, 20, 11, 5),
        levels: {
          for (final t in [ExerciseType.addition, ExerciseType.multiplication])
            t: first.newState.levels[t]?.level ?? Level.zero,
        },
      );
      expect(validate(next, state: first.newState), isA<Accepted>());
      // The same game claimed from the old levels: refused.
      final stale = honestGame(id: 's3', at: DateTime.utc(2026, 11, 20, 11, 6));
      final refused = validate(stale, state: first.newState) as Rejected;
      expect(refused.reason, RejectionReason.levelsMismatch);
    });

    group('Training', () {
      Map<ExerciseType, Level> at(int whole) => {
        ExerciseType.addition: Level.whole(whole),
        ExerciseType.multiplication: Level.whole(whole),
      };

      test('accepted at a fixed difficulty, whatever the server levels; '
          'no level moves', () {
        final first = validate(honestGame()) as Accepted;
        final training = honestGame(
          id: 't1',
          at: DateTime.utc(2026, 11, 20, 11, 5),
          kind: SessionKind.training,
          levels: at(TrainingDifficulty.hard.wholeLevel),
        );
        final result = validate(training, state: first.newState) as Accepted;
        expect(result.completed, isTrue);
        expect(result.levelUpdates, isEmpty);
        expect(result.newState.levels, first.newState.levels);
        // The chain goes on from the same levels.
        final next = honestGame(
          id: 's2',
          at: DateTime.utc(2026, 11, 20, 11, 9),
          levels: {
            for (final t in [
              ExerciseType.addition,
              ExerciseType.multiplication,
            ])
              t: first.newState.levels[t]?.level ?? Level.zero,
          },
        );
        expect(validate(next, state: result.newState), isA<Accepted>());
      });

      test('levels that are no difficulty, or two of them: refused', () {
        for (final levels in [
          at(41),
          {
            ExerciseType.addition: Level.whole(15),
            ExerciseType.multiplication: Level.whole(40),
          },
        ]) {
          final result =
              validate(honestGame(kind: SessionKind.training, levels: levels))
                  as Rejected;
          expect(result.reason, RejectionReason.levelsMismatch);
        }
      });
    });

    test('interrupted: accepted, no level moves', () {
      final result = validate(honestGame(answered: 3)) as Accepted;
      expect(result.completed, isFalse);
      expect(result.levelUpdates, isEmpty);
      expect(result.newState.hasCompletedSession, isFalse);
    });

    test('wrong answers and timeouts are honest too', () {
      final upload = honestGame(
        answer: (i, q) => switch (i % 3) {
          0 => (value: q.correctAnswer, ms: 2000),
          1 => (value: q.correctAnswer + 1, ms: 4000),
          _ => (value: timeoutSubmittedValue, ms: 15000),
        },
      );
      expect(validate(upload), isA<Accepted>());
    });
  });

  group('a forged upload is rejected', () {
    void expectRejected(ValidationResult result, RejectionReason reason) {
      expect(result, isA<Rejected>());
      expect((result as Rejected).reason, reason);
    }

    test('another question than the seed gives', () {
      final forged = tamper(
        honestGame(),
        2,
        (a) => copyAnswer(a, operands: {'operandA': 1, 'operandB': 1}),
      );
      expectRejected(validate(forged), RejectionReason.questionMismatch);
    });

    test('a wrong answer claimed right', () {
      final forged = tamper(
        honestGame(),
        0,
        (a) => copyAnswer(a, submittedValue: a.submittedValue + 1),
      );
      expectRejected(validate(forged), RejectionReason.correctnessMismatch);
    });

    test('easier frozen levels than the server holds', () {
      final state = ServerPlayerState(
        levels: {
          for (final t in [ExerciseType.addition, ExerciseType.multiplication])
            t: LevelCacheEntry(
              level: Level.whole(60),
              sessionsPlayed: 9,
              updatedAt: DateTime.utc(2026, 11, 19),
            ),
        },
        lastSessionAt: DateTime.utc(2026, 11, 19),
        hasCompletedSession: true,
      );
      // Played at level 0 while the server says 60.
      expectRejected(
        validate(honestGame(), state: state),
        RejectionReason.levelsMismatch,
      );
    });

    test('someone else’s session', () {
      expectRejected(
        validate(honestGame(player: 'p2')),
        RejectionReason.wrongPlayer,
      );
    });

    test('a date in the future, or before the last accepted session', () {
      expectRejected(
        validate(honestGame(at: _received.add(const Duration(minutes: 6)))),
        RejectionReason.futureTimestamp,
      );
      expect(
        validate(honestGame(at: _received.add(const Duration(minutes: 4)))),
        isA<Accepted>(),
        reason: 'clock skew within 5 minutes is tolerated',
      );
      expectRejected(
        validate(
          honestGame(),
          state: ServerPlayerState(lastSessionAt: DateTime.utc(2026, 11, 21)),
        ),
        RejectionReason.outOfOrder,
      );
    });

    test('an impossible response time', () {
      expectRejected(
        validate(tamper(honestGame(), 1, (a) => copyAnswer(a, elapsedMs: -5))),
        RejectionReason.badElapsed,
      );
      expectRejected(
        validate(
          tamper(honestGame(), 1, (a) => copyAnswer(a, elapsedMs: 30001)),
        ),
        RejectionReason.badElapsed,
      );
    });
  });

  group('timing flags: flagged, never rejected', () {
    test('multi-digit answers under 300 ms', () {
      final upload = honestGame(
        levels: {
          ExerciseType.addition: Level.whole(40),
          ExerciseType.multiplication: Level.whole(40),
        },
        answer: (i, q) => (value: q.correctAnswer, ms: 120 + 50 * i),
      );
      final result =
          validate(
                upload,
                state: ServerPlayerState(
                  levels: {
                    for (final t in [
                      ExerciseType.addition,
                      ExerciseType.multiplication,
                    ])
                      t: LevelCacheEntry(
                        level: Level.whole(40),
                        sessionsPlayed: 5,
                        updatedAt: DateTime.utc(2026, 11, 19),
                      ),
                  },
                ),
              )
              as Accepted;
      expect(result.flags, contains(ValidationFlag.implausiblyFast));
    });

    test('unnaturally flat times', () {
      final result =
          validate(
                honestGame(
                  answer: (i, q) => (value: q.correctAnswer, ms: 2000 + i % 2),
                ),
              )
              as Accepted;
      expect(result.flags, contains(ValidationFlag.flatTimes));
    });
  });
}
