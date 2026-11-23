import 'package:math_core/leveling/level.dart';
import 'package:math_core/leveling/level_updater.dart';
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
import 'package:math_core/placement/placement.dart';
import 'package:math_core/placement/placement_exercise_source.dart';
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
  RulesVersion rulesVersion = RulesVersion.v1,
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
    levels: levels ?? {for (final t in types) t: Level.floor},
    createdAt: createdAt,
    kind: kind,
    typeSequence: [
      for (var i = 0; i < count; i++)
        i.isEven ? ExerciseType.addition : ExerciseType.multiplication,
    ],
    rulesVersion: rulesVersion,
  );
  final n = answered ?? count;
  final questions = replaySessionQuestions(session, [
    for (var i = 0; i < n; i++) (isCorrect: true, elapsedMs: 0),
  ]);
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
  group('rules v2 (doc/levels.md)', () {
    final zero = {
      ExerciseType.addition: Level.zero,
      ExerciseType.multiplication: Level.zero,
    };

    test('an honest game from 0: accepted, each operation moved by its '
        'quality — what the app computes', () {
      // Additions fluent, multiplications right but slow.
      final upload = honestGame(
        rulesVersion: RulesVersion.v2,
        levels: zero,
        answer: (i, q) => (value: q.correctAnswer, ms: i.isEven ? 1000 : 20000),
      );
      final result = validate(upload) as Accepted;
      expect(
        result.levelUpdates[ExerciseType.addition]!.level,
        Level.fromHundredths(300),
      );
      expect(
        result.levelUpdates[ExerciseType.multiplication]!.level,
        Level.fromHundredths(120),
      );
      final appSide = gameLevelUpdates(
        outcomes: [
          for (final (i, q) in replaySessionQuestions(upload.session, [
            for (var k = 0; k < 8; k++) (isCorrect: true, elapsedMs: 0),
          ]).indexed)
            AnswerResult(
              exercise: q,
              submittedValue: q.correctAnswer,
              isCorrect: true,
              elapsedMs: i.isEven ? 1000 : 20000,
              answeredAt: upload.session.createdAt,
            ),
        ],
        frozenLevels: zero,
        priorLevels: const {},
        now: upload.session.createdAt,
        rulesVersion: RulesVersion.v2,
      );
      expect(
        {for (final e in result.levelUpdates.entries) e.key: e.value.level},
        {for (final e in appSide.entries) e.key: e.value.level},
      );
    });

    test("a game claiming rules v1's level 1 for a new player is refused", () {
      final result = validate(honestGame(rulesVersion: RulesVersion.v2));
      expect((result as Rejected).reason, RejectionReason.levelsMismatch);
    });

    test('a forged question is refused', () {
      final upload = honestGame(rulesVersion: RulesVersion.v2, levels: zero);
      final forged = tamper(
        upload,
        0,
        (a) => copyAnswer(a, operands: {'operandA': 1, 'operandB': 1}),
      );
      expect(
        (validate(forged) as Rejected).reason,
        RejectionReason.questionMismatch,
      );
    });

    test("a plan other than the setup's (3 questions each) cannot replay", () {
      final v1 = honestGame(count: 6);
      final s = v1.session;
      final upload = SessionUpload(
        session: PersistedSession(
          id: s.id,
          playerId: s.playerId,
          seed: s.seed,
          enabledTypes: s.enabledTypes,
          exerciseCount: s.exerciseCount,
          totalScore: 0,
          levels: zero,
          createdAt: s.createdAt,
          typeSequence: s.typeSequence,
          rulesVersion: RulesVersion.v2,
        ),
        answers: v1.answers,
      );
      final result = validate(upload);
      expect((result as Rejected).reason, RejectionReason.notReplayable);
    });
  });

  group('an honest game', () {
    test('accepted; levels exactly what the app computes', () {
      final upload = honestGame();
      final result = validate(upload) as Accepted;

      expect(result.completed, isTrue);
      final appSide = gameLevelUpdates(
        outcomes: [
          for (final (i, q) in replaySessionQuestions(upload.session, [
            for (final _ in upload.answers) (isCorrect: true, elapsedMs: 0),
          ]).indexed)
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
        levelUpdater: LevelUpdater(),
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
            t: first.newState.levels[t]?.level ?? Level.floor,
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
              t: first.newState.levels[t]?.level ?? Level.floor,
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
      // Played at level 1 while the server says 60.
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

  group('placement', () {
    SessionUpload placement({
      PlacementRules rules = placementRulesV2,
      int? answered,
    }) {
      final n = answered ?? rules.questionCount;
      final at = DateTime.utc(2026, 11, 20, 10);
      final session = PersistedSession(
        id: 'pl',
        playerId: 'p1',
        seed: 31337,
        enabledTypes: placementTypes.toSet(),
        exerciseCount: rules.questionCount,
        totalScore: 0,
        levels: {
          for (final t in placementTypes) t: Level.whole(rules.startLevel),
        },
        createdAt: at,
        kind: placementKindFor(rules),
        typeSequence: placementTypeSequence(rules),
      );
      // Right and fast on additions only: the staircases diverge.
      final outcomes = <({bool isCorrect, int elapsedMs})>[];
      final answers = <PersistedAnswer>[];
      for (var i = 0; i < n; i++) {
        final q = replayPlacementQuestions(
          seed: session.seed,
          answers: [...outcomes, (isCorrect: false, elapsedMs: 0)],
          rules: rules,
        )[i];
        final right = q.type == ExerciseType.addition;
        final given = (
          value: right ? q.correctAnswer : q.correctAnswer + 1,
          ms: 1200 + 31 * i,
        );
        outcomes.add((isCorrect: right, elapsedMs: given.ms));
        answers.add(_answerOf('pl', i, q, given, at));
      }
      return SessionUpload(session: session, answers: answers);
    }

    test('a complete placement sets the four starting levels', () {
      final result = validate(placement()) as Accepted;
      expect(result.levelUpdates.keys, unorderedEquals(placementTypes));
      expect(
        result.levelUpdates[ExerciseType.addition]!.level.hundredths,
        greaterThan(3500),
      );
      expect(
        result.levelUpdates[ExerciseType.division]!.level.hundredths,
        lessThan(3500),
      );
    });

    test('version 1 still replays', () {
      expect(validate(placement(rules: placementRulesV1)), isA<Accepted>());
    });

    test('interrupted: kept, no level', () {
      final result = validate(placement(answered: 7)) as Accepted;
      expect(result.levelUpdates, isEmpty);
    });

    test('not after a completed game', () {
      final result = validate(
        placement(),
        state: ServerPlayerState(
          hasCompletedSession: true,
          lastSessionAt: DateTime.utc(2026, 11, 19),
        ),
      );
      expect((result as Rejected).reason, RejectionReason.placementAfterGames);
    });

    test('a forged answer reshapes the next questions: rejected', () {
      // Claiming the first division right changes its staircase, so the
      // next division question differs from what was really asked.
      final honest = placement();
      final forged = tamper(honest, 3, (a) => copyAnswer(a, isCorrect: true));
      expect(validate(forged), isA<Rejected>());
    });

    test('not from other starting levels', () {
      final honest = placement();
      final s = honest.session;
      final moved = SessionUpload(
        session: PersistedSession(
          id: s.id,
          playerId: s.playerId,
          seed: s.seed,
          enabledTypes: s.enabledTypes,
          exerciseCount: s.exerciseCount,
          totalScore: 0,
          levels: {for (final t in placementTypes) t: Level.whole(80)},
          createdAt: s.createdAt,
          kind: s.kind,
          typeSequence: s.typeSequence,
        ),
        answers: honest.answers,
      );
      expect(
        (validate(moved) as Rejected).reason,
        RejectionReason.levelsMismatch,
      );
    });
  });

  group('type placement (Phase 3a commit 7)', () {
    const placed = {ExerciseType.power, ExerciseType.percentage};

    SessionUpload typePlacement({
      int? answered,
      List<ExerciseType>? sequence,
      int startLevel = 35,
    }) {
      final seq = sequence ?? typePlacementSequence(placed);
      final n = answered ?? seq.length;
      final at = DateTime.utc(2026, 11, 20, 10);
      final session = PersistedSession(
        id: 'tp',
        playerId: 'p1',
        seed: 4242,
        enabledTypes: placed,
        exerciseCount: seq.length,
        totalScore: 0,
        levels: {for (final t in placed) t: Level.whole(startLevel)},
        createdAt: at,
        kind: SessionKind.typePlacementV3,
        typeSequence: seq,
      );
      // Right and fast on powers only: the two staircases diverge.
      final outcomes = <({bool isCorrect, int elapsedMs})>[];
      final answers = <PersistedAnswer>[];
      for (var i = 0; i < n; i++) {
        final q = replayPlacementQuestions(
          seed: session.seed,
          answers: [...outcomes, (isCorrect: false, elapsedMs: 0)],
          rules: typePlacementRules,
          sequence: seq,
        )[i];
        final right = q.type == ExerciseType.power;
        final given = (
          value: right ? q.correctAnswer : q.correctAnswer + 1,
          ms: 1400 + 13 * i,
        );
        outcomes.add((isCorrect: right, elapsedMs: given.ms));
        answers.add(_answerOf('tp', i, q, given, at));
      }
      return SessionUpload(session: session, answers: answers);
    }

    test('sets levels for its operations only, boost kept', () {
      final result = validate(typePlacement()) as Accepted;
      expect(result.levelUpdates.keys, unorderedEquals(placed));
      expect(
        result.levelUpdates[ExerciseType.power]!.level.hundredths,
        greaterThan(3500),
      );
      expect(
        result.levelUpdates[ExerciseType.percentage]!.level.hundredths,
        lessThan(3500),
      );
      for (final entry in result.levelUpdates.values) {
        expect(entry.sessionsPlayed, typePlacementRules.sessionsPlayedAfter);
      }
    });

    test('allowed after games, on operations the server never saw', () {
      final state = ServerPlayerState(
        hasCompletedSession: true,
        lastSessionAt: DateTime.utc(2026, 11, 19),
        levels: {
          ExerciseType.addition: LevelCacheEntry(
            level: Level.whole(40),
            sessionsPlayed: 6,
            updatedAt: DateTime.utc(2026, 11, 19),
          ),
        },
      );
      expect(validate(typePlacement(), state: state), isA<Accepted>());
    });

    test('an operation the server has a level for is refused', () {
      final state = ServerPlayerState(
        levels: {
          ExerciseType.percentage: LevelCacheEntry(
            level: Level.whole(12),
            sessionsPlayed: 2,
            updatedAt: DateTime.utc(2026, 11, 19),
          ),
        },
      );
      final result = validate(typePlacement(), state: state);
      expect((result as Rejected).reason, RejectionReason.typeAlreadyPlayed);
    });

    test('a start level other than the rules’ is refused', () {
      final result = validate(typePlacement(startLevel: 60));
      expect((result as Rejected).reason, RejectionReason.levelsMismatch);
    });

    test('a rotation other than the rules’ cannot replay', () {
      final reordered = typePlacementSequence(placed).reversed.toList();
      final result = validate(typePlacement(sequence: reordered));
      expect((result as Rejected).reason, RejectionReason.notReplayable);
    });

    test('interrupted: accepted, sets nothing', () {
      final result = validate(typePlacement(answered: 4)) as Accepted;
      expect(result.levelUpdates, isEmpty);
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
