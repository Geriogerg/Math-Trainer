import 'package:math_core/leveling/level.dart';
import 'package:math_core/persistence/level_cache_entry.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/models/session_kind.dart';
import 'package:math_core/persistence/persisted_answer.dart';
import 'package:math_core/persistence/persisted_session.dart';
import 'package:math_trainer/infrastructure/persistence/database.dart';
import 'package:math_trainer/infrastructure/persistence/sqflite_session_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:test/test.dart';

void main() {
  // sqflite has no platform (no device/emulator) under `flutter test` on the
  // Dart VM: sqflite_common_ffi provides an implementation based on native
  // sqlite3 that runs directly on the VM.
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late SqfliteSessionRepository repository;

  setUp(() async {
    db = await openMathTrainerDatabase(inMemoryDatabasePath);
    repository = SqfliteSessionRepository(db);
  });

  tearDown(() => db.close());

  PersistedSession session(
    String id, {
    required DateTime createdAt,
    String playerId = 'player-1',
  }) {
    return PersistedSession(
      id: id,
      playerId: playerId,
      seed: 42,
      enabledTypes: const {ExerciseType.addition, ExerciseType.division},
      exerciseCount: 10,
      totalScore: 150,
      levels: {
        ExerciseType.addition: Level.whole(42),
        ExerciseType.division: Level.whole(17),
      },
      createdAt: createdAt,
      overallLevelAfter: 9.5,
    );
  }

  PersistedAnswer answer(
    String id,
    String sessionId, {
    String operationType = 'addition',
    int elapsedMs = 1200,
  }) {
    return PersistedAnswer(
      id: id,
      sessionId: sessionId,
      exerciseType: 'arithmetic',
      operationType: operationType,
      operands: const {'operandA': 4, 'operandB': 3},
      submittedValue: 7,
      isCorrect: true,
      elapsedMs: elapsedMs,
      createdAt: DateTime.utc(2026, 8, 8),
      syncedAt: DateTime.utc(2026, 8, 8, 1),
    );
  }

  group('SqfliteSessionRepository', () {
    group('uploads (schema v7)', () {
      Future<void> store(
        String id,
        DateTime at, {
        String player = 'player-1',
      }) => repository.recordSession(
        session: session(id, createdAt: at, playerId: player),
        answers: [answer('$id-a', id)],
        levelUpdates: const {},
      );

      test(
        'pending: this player only, never synced nor refused, oldest first',
        () async {
          await store('late', DateTime.utc(2026, 11, 3));
          await store('early', DateTime.utc(2026, 11, 1));
          await store('refused', DateTime.utc(2026, 11, 2));
          await store('theirs', DateTime.utc(2026, 11, 2), player: 'other');
          await repository.markUploadRefused('refused', 'levelsMismatch');

          expect(
            [for (final s in await repository.pendingUploads('player-1')) s.id],
            ['early', 'late'],
          );

          await repository.markSynced('early', DateTime.utc(2026, 11, 20, 10));
          expect(
            [for (final s in await repository.pendingUploads('player-1')) s.id],
            ['late'],
          );
          final synced = (await repository.recentSessions(
            'player-1',
          )).firstWhere((s) => s.id == 'early');
          expect(synced.syncedAt, DateTime.utc(2026, 11, 20, 10));
          expect(
            (await repository.answersForSession('early')).single.syncedAt,
            DateTime.utc(2026, 11, 20, 10),
          );
          // The reason is read back with the session (Profile explains it).
          final sessions = await repository.recentSessions('player-1');
          expect(
            sessions.firstWhere((s) => s.id == 'refused').uploadRefused,
            'levelsMismatch',
          );
          expect(synced.uploadRefused, isNull);
        },
      );

      test('replaceLevelCache swaps the whole cache of one player', () async {
        LevelCacheEntry entry(int level) => LevelCacheEntry(
          level: Level.whole(level),
          sessionsPlayed: 1,
          updatedAt: DateTime.utc(2026, 11, 1),
        );
        await repository.recordSession(
          session: session('s', createdAt: DateTime.utc(2026, 11, 1)),
          answers: const [],
          levelUpdates: {
            ExerciseType.addition: entry(30),
            ExerciseType.division: entry(20),
          },
        );
        await repository.recordSession(
          session: session(
            't',
            createdAt: DateTime.utc(2026, 11, 1),
            playerId: 'other',
          ),
          answers: const [],
          levelUpdates: {ExerciseType.addition: entry(50)},
        );

        await repository.replaceLevelCache('player-1', {
          ExerciseType.power: entry(12),
        });

        final mine = await repository.currentLevels('player-1');
        expect(mine.keys, [ExerciseType.power]);
        expect(mine[ExerciseType.power]!.level, Level.whole(12));
        expect(
          (await repository.currentLevels(
            'other',
          ))[ExerciseType.addition]!.level,
          Level.whole(50),
        );
      });
    });

    test('the type sequence round-trips, in order; null stays null', () async {
      final sequence = [
        for (var i = 0; i < 10; i++)
          i % 3 == 0 ? ExerciseType.division : ExerciseType.addition,
      ];
      final withSequence = PersistedSession(
        id: 'with',
        playerId: 'player-1',
        seed: 42,
        enabledTypes: const {ExerciseType.addition, ExerciseType.division},
        exerciseCount: 10,
        totalScore: 0,
        levels: {
          ExerciseType.addition: Level.whole(4),
          ExerciseType.division: Level.whole(2),
        },
        createdAt: DateTime.utc(2026, 11, 2),
        typeSequence: sequence,
      );
      await repository.recordSession(
        session: withSequence,
        answers: const [],
        levelUpdates: const {},
      );
      await repository.recordSession(
        session: session('without', createdAt: DateTime.utc(2026, 11, 1)),
        answers: const [],
        levelUpdates: const {},
      );

      final stored = await repository.recentSessions('player-1');
      expect(stored.first, withSequence);
      expect(stored.first.typeSequence, sequence);
      expect(stored.last.typeSequence, isNull);
    });

    test('answers come back in the order they were stored', () async {
      await repository.recordSession(
        session: session('s', createdAt: DateTime.utc(2026, 11, 1)),
        answers: [
          for (final id in ['z', 'a', 'm']) answer(id, 's'),
        ],
        levelUpdates: const {},
      );
      expect(
        [for (final a in await repository.answersForSession('s')) a.id],
        ['z', 'a', 'm'],
      );
    });

    test('hasCompletedSession: only a session played to its last question '
        'counts, and only for its player', () async {
      expect(await repository.hasCompletedSession('player-1'), isFalse);
      // Interrupted: 2 answers out of the 10 planned.
      await repository.recordSession(
        session: session('interrupted', createdAt: DateTime.utc(2026, 11, 1)),
        answers: [answer('i-1', 'interrupted'), answer('i-2', 'interrupted')],
        levelUpdates: const {},
      );
      expect(await repository.hasCompletedSession('player-1'), isFalse);

      await repository.recordSession(
        session: session('complete', createdAt: DateTime.utc(2026, 11, 2)),
        answers: [for (var i = 0; i < 10; i++) answer('c-$i', 'complete')],
        levelUpdates: const {},
      );
      expect(await repository.hasCompletedSession('player-1'), isTrue);
      expect(await repository.hasCompletedSession('player-2'), isFalse);
    });

    test('deletePlayerData removes the sessions, answers and levels of one '
        'player only', () async {
      for (final player in ['me', 'other']) {
        await repository.recordSession(
          session: session(
            's-$player',
            createdAt: DateTime.utc(2026, 11, 1),
            playerId: player,
          ),
          answers: [answer('a-$player', 's-$player')],
          levelUpdates: {
            ExerciseType.addition: LevelCacheEntry(
              level: Level.whole(20),
              sessionsPlayed: 1,
              updatedAt: DateTime.utc(2026, 11, 1),
            ),
          },
        );
      }

      await repository.deletePlayerData('me');

      expect(await repository.recentSessions('me'), isEmpty);
      expect(await repository.answersForSession('s-me'), isEmpty);
      expect(await repository.currentLevels('me'), isEmpty);
      expect(await repository.recentSessions('other'), hasLength(1));
      expect(await repository.answersForSession('s-other'), hasLength(1));
      expect(await repository.currentLevels('other'), hasLength(1));
    });

    test('a placement keeps its kind; a game is a game', () async {
      final game = session('game-1', createdAt: DateTime.utc(2026, 11, 1));
      final placement = PersistedSession(
        id: 'placement-1',
        playerId: 'player-1',
        seed: 7,
        enabledTypes: const {ExerciseType.addition},
        exerciseCount: 24,
        totalScore: 0,
        levels: {ExerciseType.addition: Level.whole(35)},
        createdAt: DateTime.utc(2026, 11, 2),
        kind: SessionKind.placementV1,
      );
      for (final s in [game, placement]) {
        await repository.recordSession(
          session: s,
          answers: const [],
          levelUpdates: const {},
        );
      }

      final stored = {
        for (final s in await repository.recentSessions('player-1')) s.id: s,
      };
      expect(stored['game-1']!.kind, SessionKind.game);
      expect(stored['placement-1'], placement);
    });

    test(
      'recordSession persists the session and answers, readable afterwards',
      () async {
        final s = session('session-1', createdAt: DateTime.utc(2026, 8, 8));
        final answers = [
          answer('answer-1', 'session-1'),
          answer('answer-2', 'session-1'),
        ];

        await repository.recordSession(
          session: s,
          answers: answers,
          levelUpdates: const {},
        );

        final sessions = await repository.recentSessions('player-1');
        final storedAnswers = await repository.answersForSession('session-1');

        expect(sessions, equals([s]));
        expect(storedAnswers, equals(answers));
      },
    );

    test(
      'answersForSession only returns the answers of the requested session',
      () async {
        await repository.recordSession(
          session: session('session-1', createdAt: DateTime.utc(2026, 8, 8)),
          answers: [answer('answer-1', 'session-1')],
          levelUpdates: const {},
        );
        await repository.recordSession(
          session: session('session-2', createdAt: DateTime.utc(2026, 8, 9)),
          answers: [answer('answer-2', 'session-2')],
          levelUpdates: const {},
        );

        final result = await repository.answersForSession('session-1');

        expect(result.map((a) => a.id), equals(['answer-1']));
      },
    );

    test(
      'recentSessions sorts most recent first and respects the limit',
      () async {
        await repository.recordSession(
          session: session('oldest', createdAt: DateTime.utc(2026, 8, 1)),
          answers: const [],
          levelUpdates: const {},
        );
        await repository.recordSession(
          session: session('newest', createdAt: DateTime.utc(2026, 8, 10)),
          answers: const [],
          levelUpdates: const {},
        );
        await repository.recordSession(
          session: session('middle', createdAt: DateTime.utc(2026, 8, 5)),
          answers: const [],
          levelUpdates: const {},
        );

        final result = await repository.recentSessions('player-1', limit: 2);

        expect(result.map((s) => s.id), equals(['newest', 'middle']));
      },
    );

    test(
      "recentSessions only returns the requested player's sessions",
      () async {
        await repository.recordSession(
          session: session(
            'a-1',
            createdAt: DateTime.utc(2026, 8, 1),
            playerId: 'player-a',
          ),
          answers: const [],
          levelUpdates: const {},
        );
        await repository.recordSession(
          session: session(
            'b-1',
            createdAt: DateTime.utc(2026, 8, 2),
            playerId: 'player-b',
          ),
          answers: const [],
          levelUpdates: const {},
        );

        final result = await repository.recentSessions('player-a');

        expect(result.map((s) => s.id), equals(['a-1']));
      },
    );

    test(
      'transferPlayerData hands sessions, answers and levels to the new player',
      () async {
        final entry = LevelCacheEntry(
          level: Level.whole(42),
          sessionsPlayed: 1,
          updatedAt: DateTime.utc(2026, 8, 8),
        );
        await repository.recordSession(
          session: session(
            'session-1',
            createdAt: DateTime.utc(2026, 8, 8),
            playerId: 'device',
          ),
          answers: [answer('answer-1', 'session-1', elapsedMs: 900)],
          levelUpdates: {ExerciseType.addition: entry},
        );

        await repository.transferPlayerData(
          fromPlayerId: 'device',
          toPlayerId: 'account',
        );

        expect(
          (await repository.recentSessions(
            'account',
          )).map((s) => (s.id, s.playerId)),
          [('session-1', 'account')],
        );
        expect(
          (await repository.currentLevels(
            'account',
          ))[ExerciseType.addition]?.level,
          Level.whole(42),
        );
        expect(await repository.averageElapsedMsByType('account'), {
          ExerciseType.addition: 900,
        });
        expect(await repository.recentSessions('device'), isEmpty);
        expect(await repository.currentLevels('device'), isEmpty);
      },
    );

    test(
      'transferPlayerData never merges with a player who already has data',
      () async {
        final deviceLevel = LevelCacheEntry(
          level: Level.whole(10),
          sessionsPlayed: 1,
          updatedAt: DateTime.utc(2026, 8, 8),
        );
        final accountLevel = LevelCacheEntry(
          level: Level.whole(80),
          sessionsPlayed: 3,
          updatedAt: DateTime.utc(2026, 8, 9),
        );
        await repository.recordSession(
          session: session(
            'device-1',
            createdAt: DateTime.utc(2026, 8, 8),
            playerId: 'device',
          ),
          answers: const [],
          levelUpdates: {ExerciseType.addition: deviceLevel},
        );
        await repository.recordSession(
          session: session(
            'account-1',
            createdAt: DateTime.utc(2026, 8, 9),
            playerId: 'account',
          ),
          answers: const [],
          levelUpdates: {ExerciseType.addition: accountLevel},
        );

        await repository.transferPlayerData(
          fromPlayerId: 'device',
          toPlayerId: 'account',
        );

        expect((await repository.recentSessions('account')).map((s) => s.id), [
          'account-1',
        ]);
        expect(
          (await repository.currentLevels(
            'account',
          ))[ExerciseType.addition]?.level,
          Level.whole(80),
        );
        expect((await repository.recentSessions('device')).map((s) => s.id), [
          'device-1',
        ]);
      },
    );

    test(
      'a session without an overall level after (older than schema v3) reads back as is',
      () async {
        final legacy = PersistedSession(
          id: 'legacy',
          playerId: 'player-1',
          seed: 1,
          enabledTypes: const {ExerciseType.addition},
          exerciseCount: 4,
          totalScore: 10,
          levels: const {},
          createdAt: DateTime.utc(2026, 8, 8),
        );

        await repository.recordSession(
          session: legacy,
          answers: const [],
          levelUpdates: const {},
        );

        expect(await repository.recentSessions('player-1'), equals([legacy]));
      },
    );

    test(
      'recordSession writes session, answers and levels in a single transaction',
      () async {
        final s = session('session-1', createdAt: DateTime.utc(2026, 8, 8));
        final entry = LevelCacheEntry(
          level: Level.whole(42),
          sessionsPlayed: 1,
          updatedAt: DateTime.utc(2026, 8, 8),
        );

        await repository.recordSession(
          session: s,
          answers: [
            answer('answer-1', 'session-1'),
            answer('answer-2', 'session-1'),
          ],
          levelUpdates: {ExerciseType.addition: entry},
        );

        final storedAnswers = await repository.answersForSession('session-1');
        expect(storedAnswers, hasLength(2));

        final levels = await repository.currentLevels('player-1');
        expect(levels[ExerciseType.addition]?.level, Level.whole(42));
      },
    );

    test('currentLevels is empty for a player who never played', () async {
      expect(await repository.currentLevels('unknown-player'), isEmpty);
    });

    test(
      'currentLevels replaces the previous value for an operation already cached',
      () async {
        final firstEntry = LevelCacheEntry(
          level: Level.whole(40),
          sessionsPlayed: 1,
          updatedAt: DateTime.utc(2026, 8, 8),
        );
        final secondEntry = LevelCacheEntry(
          level: Level.whole(45),
          sessionsPlayed: 2,
          updatedAt: DateTime.utc(2026, 8, 9),
        );

        await repository.recordSession(
          session: session('session-1', createdAt: DateTime.utc(2026, 8, 8)),
          answers: const [],
          levelUpdates: {ExerciseType.addition: firstEntry},
        );
        await repository.recordSession(
          session: session('session-2', createdAt: DateTime.utc(2026, 8, 9)),
          answers: const [],
          levelUpdates: {ExerciseType.addition: secondEntry},
        );

        final levels = await repository.currentLevels('player-1');
        expect(levels[ExerciseType.addition]?.level, Level.whole(45));
        expect(levels[ExerciseType.addition]?.sessionsPlayed, 2);
      },
    );

    test(
      "averageElapsedMsByType averages per operation, one player's answers only",
      () async {
        await repository.recordSession(
          session: session('session-1', createdAt: DateTime.utc(2026, 8, 8)),
          answers: [
            answer(
              'a1',
              'session-1',
              operationType: 'addition',
              elapsedMs: 1000,
            ),
            answer(
              'a2',
              'session-1',
              operationType: 'addition',
              elapsedMs: 2000,
            ),
            answer(
              'a3',
              'session-1',
              operationType: 'subtraction',
              elapsedMs: 500,
            ),
          ],
          levelUpdates: const {},
        );
        // Another player's answer — must not enter the mean.
        await repository.recordSession(
          session: session(
            'session-2',
            createdAt: DateTime.utc(2026, 8, 8),
            playerId: 'player-b',
          ),
          answers: [
            answer(
              'a4',
              'session-2',
              operationType: 'addition',
              elapsedMs: 9999,
            ),
          ],
          levelUpdates: const {},
        );

        final result = await repository.averageElapsedMsByType('player-1');

        expect(result[ExerciseType.addition], 1500);
        expect(result[ExerciseType.subtraction], 500);
        expect(result.containsKey(ExerciseType.multiplication), isFalse);
      },
    );

    test(
      "sessionsSince only returns the player's sessions from the date, sorted",
      () async {
        await repository.recordSession(
          session: session('too-old', createdAt: DateTime.utc(2026, 7, 1)),
          answers: const [],
          levelUpdates: const {},
        );
        await repository.recordSession(
          session: session(
            'in-window-late',
            createdAt: DateTime.utc(2026, 8, 10),
          ),
          answers: const [],
          levelUpdates: const {},
        );
        await repository.recordSession(
          session: session(
            'in-window-early',
            createdAt: DateTime.utc(2026, 8, 5),
          ),
          answers: const [],
          levelUpdates: const {},
        );
        await repository.recordSession(
          session: session(
            'other-player',
            createdAt: DateTime.utc(2026, 8, 5),
            playerId: 'player-b',
          ),
          answers: const [],
          levelUpdates: const {},
        );

        final result = await repository.sessionsSince(
          'player-1',
          DateTime.utc(2026, 8, 1),
        );

        expect(
          result.map((s) => s.id),
          equals(['in-window-early', 'in-window-late']),
        );
      },
    );
  });
}
