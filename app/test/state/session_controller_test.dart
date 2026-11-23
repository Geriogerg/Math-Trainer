import 'dart:async';

import 'package:math_core/generation/exercise_source.dart';
import 'package:math_core/leveling/level.dart';
import 'package:math_core/persistence/level_cache_entry.dart';
import 'package:math_core/models/exercise.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/models/input_device.dart';
import 'package:math_core/models/operation_type.dart';
import 'package:math_core/models/session_config.dart';
import 'package:math_core/persistence/in_memory_session_repository.dart';
import 'package:math_core/persistence/persisted_answer.dart';
import 'package:math_core/persistence/persisted_session.dart';
import 'package:math_core/persistence/session_repository.dart';
import 'package:math_trainer/core/state/session_controller.dart';
import 'package:math_trainer/core/state/session_state.dart';
import 'package:test/test.dart';

class _FixedExerciseSource extends ExerciseSource {
  _FixedExerciseSource(this._exercises);

  final List<Exercise> _exercises;
  int _index = 0;

  @override
  Exercise next() => _exercises[_index++];
}

/// Fake timer: never fires on its own (no real clock), only when the test
/// calls [fire] explicitly. The default of [buildController] builds one per
/// question without ever calling [fire] — inert, so no real timer stays
/// pending at the end of a test that does not test the timeout itself.
class _FakeTimer implements Timer {
  _FakeTimer(this._callback);

  final void Function() _callback;
  bool _cancelled = false;
  bool _fired = false;

  void fire() {
    if (_cancelled || _fired) return;
    _fired = true;
    _callback();
  }

  @override
  void cancel() => _cancelled = true;

  @override
  bool get isActive => !_cancelled && !_fired;

  @override
  int get tick => 0;
}

/// Captures every `_FakeTimer` created by `SessionController` (one per armed
/// question), in order — `latest` is the one of the question currently
/// shown.
class _TimerSpy {
  final List<_FakeTimer> created = [];
  final List<Duration> durations = [];

  Timer create(Duration duration, void Function() callback) {
    final timer = _FakeTimer(callback);
    created.add(timer);
    durations.add(duration);
    return timer;
  }

  _FakeTimer get latest => created.last;
}

/// `currentLevels` fails (simulates a failed cache read), but
/// `recordSession` delegates to a working internal
/// `InMemorySessionRepository` — to check that the session and its answers
/// are stored despite the failed cache read.
class _LevelReadFailureRepository implements SessionRepository {
  @override
  Future<void> deletePlayerData(String playerId) => throw UnimplementedError();
  final inner = InMemorySessionRepository();
  @override
  Future<List<PersistedSession>> pendingUploads(String playerId) async => [];
  @override
  Future<void> markSynced(String sessionId, DateTime syncedAt) async {}
  @override
  Future<void> markUploadRefused(String sessionId, String reason) async {}
  @override
  Future<void> replaceLevelCache(
    String playerId,
    Map<ExerciseType, LevelCacheEntry> levels,
  ) async {}
  @override
  Future<bool> hasCompletedSession(String playerId) =>
      inner.hasCompletedSession(playerId);

  @override
  Future<Map<ExerciseType, LevelCacheEntry>> currentLevels(String playerId) =>
      throw Exception('simulated cache read failure');

  @override
  Future<void> recordSession({
    required PersistedSession session,
    required List<PersistedAnswer> answers,
    required Map<ExerciseType, LevelCacheEntry> levelUpdates,
  }) => inner.recordSession(
    session: session,
    answers: answers,
    levelUpdates: levelUpdates,
  );

  @override
  Future<List<PersistedSession>> recentSessions(
    String playerId, {
    int limit = 20,
  }) => inner.recentSessions(playerId, limit: limit);

  @override
  Future<void> transferPlayerData({
    required String fromPlayerId,
    required String toPlayerId,
  }) => inner.transferPlayerData(
    fromPlayerId: fromPlayerId,
    toPlayerId: toPlayerId,
  );

  @override
  Future<List<PersistedAnswer>> answersForSession(String sessionId) =>
      inner.answersForSession(sessionId);

  @override
  Future<Map<ExerciseType, double>> averageElapsedMsByType(String playerId) =>
      inner.averageElapsedMsByType(playerId);

  @override
  Future<List<PersistedSession>> sessionsSince(
    String playerId,
    DateTime since,
  ) => inner.sessionsSince(playerId, since);
}

/// `currentLevels` throws an `Error` (not an `Exception`): simulates a bug —
/// an invariant breaking somewhere in the chain — rather than an expected
/// I/O failure.
class _BuggyLevelReadRepository implements SessionRepository {
  @override
  Future<void> deletePlayerData(String playerId) => throw UnimplementedError();
  final inner = InMemorySessionRepository();
  @override
  Future<List<PersistedSession>> pendingUploads(String playerId) async => [];
  @override
  Future<void> markSynced(String sessionId, DateTime syncedAt) async {}
  @override
  Future<void> markUploadRefused(String sessionId, String reason) async {}
  @override
  Future<void> replaceLevelCache(
    String playerId,
    Map<ExerciseType, LevelCacheEntry> levels,
  ) async {}
  @override
  Future<bool> hasCompletedSession(String playerId) =>
      inner.hasCompletedSession(playerId);

  @override
  Future<Map<ExerciseType, LevelCacheEntry>> currentLevels(String playerId) =>
      throw ArgumentError('simulated bug, not a network/disk failure');

  @override
  Future<void> recordSession({
    required PersistedSession session,
    required List<PersistedAnswer> answers,
    required Map<ExerciseType, LevelCacheEntry> levelUpdates,
  }) => inner.recordSession(
    session: session,
    answers: answers,
    levelUpdates: levelUpdates,
  );

  @override
  Future<List<PersistedSession>> recentSessions(
    String playerId, {
    int limit = 20,
  }) => inner.recentSessions(playerId, limit: limit);

  @override
  Future<void> transferPlayerData({
    required String fromPlayerId,
    required String toPlayerId,
  }) => inner.transferPlayerData(
    fromPlayerId: fromPlayerId,
    toPlayerId: toPlayerId,
  );

  @override
  Future<List<PersistedAnswer>> answersForSession(String sessionId) =>
      inner.answersForSession(sessionId);

  @override
  Future<Map<ExerciseType, double>> averageElapsedMsByType(String playerId) =>
      inner.averageElapsedMsByType(playerId);

  @override
  Future<List<PersistedSession>> sessionsSince(
    String playerId,
    DateTime since,
  ) => inner.sessionsSince(playerId, since);
}

void main() {
  persistenceRobustnessTests();
  final exercises = [
    ArithmeticExercise(
      operandA: 2,
      operandB: 2,
      operationType: OperationType.addition,
    ),
    ArithmeticExercise(
      operandA: 5,
      operandB: 3,
      operationType: OperationType.addition,
    ),
    ArithmeticExercise(
      operandA: 9,
      operandB: 1,
      operationType: OperationType.addition,
    ),
  ];

  SessionController buildController({InMemorySessionRepository? repository}) {
    return SessionController(
      config: SessionConfig(
        seed: 1,
        enabledTypes: {ExerciseType.addition},
        exerciseCount: exercises.length,
        levels: {ExerciseType.addition: Level.whole(1)},
      ),
      exerciseSource: _FixedExerciseSource(exercises),
      repository: repository ?? InMemorySessionRepository(),
      playerId: 'test-player',
      clock: () => DateTime(2024),
      // Inert by default: these tests are not about the timeout, a real
      // Timer(Duration(seconds: 15), ...) would stay pending at the end of the
      // test.
      createTimer: (duration, callback) => _FakeTimer(callback),
    );
  }

  group('SessionController', () {
    test('start() goes in progress and shows the first exercise', () {
      final controller = buildController();

      controller.start();

      expect(controller.state.status, SessionStatus.inProgress);
      expect(controller.state.currentExercise, exercises[0]);
      expect(controller.state.score, 0);
    });

    test('submitAnswer ignored before start()', () {
      final controller = buildController();

      controller.submitAnswer(4);

      expect(controller.state.status, SessionStatus.notStarted);
      expect(controller.state.outcomes, isEmpty);
    });

    test('chains exercises and computes score/streak/final result', () {
      final controller = buildController();
      controller.start();

      controller.submitAnswer(4); // correct, exercises[0] : 2+2
      expect(controller.state.currentStreak, 1);
      expect(
        controller.state.score,
        20,
      ); // base 10 + max speed bonus 10 (zero elapsed)
      expect(controller.state.currentExercise, exercises[1]);

      controller.submitAnswer(0); // incorrect, exercises[1] : 5+3=8
      expect(controller.state.currentStreak, 0);
      expect(controller.state.score, 20);
      expect(controller.state.currentExercise, exercises[2]);

      controller.submitAnswer(10); // correct, exercises[2] : 9+1
      expect(controller.state.status, SessionStatus.finished);
      expect(controller.state.currentExercise, isNull);

      final result = controller.result;
      expect(result.correctCount, 2);
      expect(result.outcomes.length, 3);
      expect(result.totalScore, controller.state.score);
    });

    test("the score is weighted by the operation's frozen level", () {
      final controller = SessionController(
        config: SessionConfig(
          seed: 1,
          enabledTypes: {ExerciseType.addition},
          exerciseCount: exercises.length,
          levels: {ExerciseType.addition: Level.whole(100)},
        ),
        exerciseSource: _FixedExerciseSource(exercises),
        repository: InMemorySessionRepository(),
        playerId: 'test-player',
        clock: () => DateTime(2024),
      );
      controller.start();

      controller.submitAnswer(4); // correct, exercises[0] : 2+2

      // base 10 + max speed bonus 10 = 20 raw; level 100, default bonusMax
      // 1.0 → multiplier 2 → 40.
      expect(controller.state.score, 40);
    });

    test('persists the session in the repository once finished', () async {
      final repository = InMemorySessionRepository();
      final controller = buildController(repository: repository);
      controller.start();

      controller.submitAnswer(4);
      controller.submitAnswer(0);
      controller.submitAnswer(10);

      // Lets the asynchronous persistence (not awaited by submitAnswer) run
      // before checking the repository.
      await Future<void>.delayed(Duration.zero);

      final sessions = await repository.recentSessions('test-player');
      expect(sessions, hasLength(1));
      expect(sessions.single.playerId, 'test-player');
      expect(sessions.single.totalScore, controller.state.score);
      expect(sessions.single.levels, {ExerciseType.addition: Level.whole(1)});

      final answers = await repository.answersForSession(sessions.single.id);
      expect(answers, hasLength(3));
      expect(answers.map((a) => a.isCorrect), [true, false, true]);

      // Completed: the game moves its operation's level, whatever the
      // number of answers (`doc/levels.md`, no n_min any more).
      expect((await repository.currentLevels('test-player')).keys, {
        ExerciseType.addition,
      });
    });

    test(
      'each stored answer carries its own time, a timeout the time it ran out',
      () async {
        final repository = InMemorySessionRepository();
        final spy = _TimerSpy();
        var now = DateTime.utc(2024, 3, 1, 9);
        final controller = SessionController(
          config: SessionConfig(
            seed: 1,
            enabledTypes: {ExerciseType.addition},
            exerciseCount: exercises.length,
            levels: {ExerciseType.addition: Level.whole(1)},
          ),
          exerciseSource: _FixedExerciseSource(exercises),
          repository: repository,
          playerId: 'test-player',
          clock: () => now,
          createTimer: spy.create,
        );
        controller.start();

        now = now.add(const Duration(seconds: 2));
        controller.submitAnswer(4);
        now = now.add(const Duration(seconds: 3));
        controller.submitAnswer(0);
        now = now.add(const Duration(seconds: 15));
        spy.latest.fire();
        await controller.pendingPersistence;

        final session = (await repository.recentSessions('test-player')).single;
        final answers = await repository.answersForSession(session.id);
        expect(answers.map((a) => a.createdAt), [
          DateTime.utc(2024, 3, 1, 9, 0, 2),
          DateTime.utc(2024, 3, 1, 9, 0, 5),
          DateTime.utc(2024, 3, 1, 9, 0, 20),
        ]);
        expect(answers.map((a) => a.createdAt.isUtc), everyElement(isTrue));
        expect(
          controller.state.outcomes.map((o) => o.answeredAt),
          answers.map((a) => a.createdAt),
        );
      },
    );

    test('a local clock is stored as UTC', () async {
      final repository = InMemorySessionRepository();
      final local = DateTime(2024, 3, 1, 9, 30);
      final controller = SessionController(
        config: SessionConfig(
          seed: 1,
          enabledTypes: {ExerciseType.addition},
          exerciseCount: 1,
          levels: {ExerciseType.addition: Level.whole(1)},
        ),
        exerciseSource: _FixedExerciseSource(exercises),
        repository: repository,
        playerId: 'test-player',
        clock: () => local,
        createTimer: (duration, callback) => _FakeTimer(callback),
      );
      controller.start();
      controller.submitAnswer(4);
      await controller.pendingPersistence;

      final session = (await repository.recentSessions('test-player')).single;
      final answer = (await repository.answersForSession(session.id)).single;
      expect(answer.createdAt, local.toUtc());
      expect(answer.createdAt.isUtc, isTrue);
    });

    test(
      'a session with at least n_min right and fast answers updates the level '
      'cache (calibration, first time on this operation)',
      () async {
        final repository = InMemorySessionRepository();
        final eightExercises = List.generate(
          8,
          (i) => ArithmeticExercise(
            operandA: i,
            operandB: 0,
            operationType: OperationType.addition,
          ),
        );
        final controller = SessionController(
          config: SessionConfig(
            seed: 1,
            enabledTypes: {ExerciseType.addition},
            exerciseCount: 8,
            levels: {ExerciseType.addition: Level.whole(50)},
          ),
          exerciseSource: _FixedExerciseSource(eightExercises),
          repository: repository,
          playerId: 'test-player',
          clock: () => DateTime(2024),
          createTimer: (duration, callback) => _FakeTimer(callback),
        );

        controller.start();
        for (var i = 0; i < 8; i++) {
          controller.submitAnswer(i); // i + 0 = i: always right
        }
        await Future<void>.delayed(Duration.zero);

        final levels = await repository.currentLevels('test-player');
        // From level 50, 8 right and instant answers (n_min = 4, weighting
        // √(8/4) — see doc/decisions.md), "calibration" confidence (first
        // session on this operation): the unclamped change exceeds deltaMax,
        // capped at 3 → 53.
        expect(levels[ExerciseType.addition]?.level, Level.whole(53));
        expect(levels[ExerciseType.addition]?.sessionsPlayed, 1);
      },
    );

    test('a failed level cache read does not prevent the session from being '
        'stored', () async {
      final repository = _LevelReadFailureRepository();
      final eightExercises = List.generate(
        8,
        (i) => ArithmeticExercise(
          operandA: i,
          operandB: 0,
          operationType: OperationType.addition,
        ),
      );
      final controller = SessionController(
        config: SessionConfig(
          seed: 1,
          enabledTypes: {ExerciseType.addition},
          exerciseCount: 8,
          levels: {ExerciseType.addition: Level.whole(50)},
        ),
        exerciseSource: _FixedExerciseSource(eightExercises),
        repository: repository,
        playerId: 'test-player',
        clock: () => DateTime(2024),
        createTimer: (duration, callback) => _FakeTimer(callback),
      );

      controller.start();
      for (var i = 0; i < 8; i++) {
        controller.submitAnswer(i);
      }
      await Future<void>.delayed(Duration.zero);

      // The session and its answers (not rebuildable) are there despite the
      // failed cache read.
      final sessions = await repository.inner.recentSessions('test-player');
      expect(sessions, hasLength(1));
      final answers = await repository.inner.answersForSession(
        sessions.single.id,
      );
      expect(answers, hasLength(8));

      // The level cache (recomputable) could not be updated this time — no
      // entry, but no lost session either.
      expect(await repository.inner.currentLevels('test-player'), isEmpty);
    });

    test(
      'an Error (bug) while computing the cache is not silently swallowed',
      () async {
        final repository = _BuggyLevelReadRepository();
        final eightExercises = List.generate(
          8,
          (i) => ArithmeticExercise(
            operandA: i,
            operandB: 0,
            operationType: OperationType.addition,
          ),
        );
        final controller = SessionController(
          config: SessionConfig(
            seed: 1,
            enabledTypes: {ExerciseType.addition},
            exerciseCount: 8,
            levels: {ExerciseType.addition: Level.whole(50)},
          ),
          exerciseSource: _FixedExerciseSource(eightExercises),
          repository: repository,
          playerId: 'test-player',
          clock: () => DateTime(2024),
          createTimer: (duration, callback) => _FakeTimer(callback),
        );

        final uncaughtErrors = <Object>[];
        await runZonedGuarded(() async {
          controller.start();
          for (var i = 0; i < 8; i++) {
            controller.submitAnswer(i);
          }
          // _persistCompletedSession runs in the background (unawaited): let
          // the unhandled error reach the zone before checking.
          await Future<void>.delayed(Duration.zero);
        }, (error, stack) => uncaughtErrors.add(error));

        expect(uncaughtErrors, hasLength(1));
        expect(uncaughtErrors.single, isA<ArgumentError>());

        // The Error propagates before reaching recordSession (rule 13: do not
        // carry on after a broken invariant) — unlike the Exception case
        // (previous test), where recordSession still runs.
        final sessions = await repository.inner.recentSessions('test-player');
        expect(sessions, isEmpty);
      },
    );

    test('restart() fully resets the session', () {
      final controller = buildController();
      controller.start();
      controller.submitAnswer(4);

      controller.restart();

      expect(controller.state.status, SessionStatus.notStarted);
      expect(controller.state.score, 0);
      expect(controller.state.outcomes, isEmpty);
      expect(controller.state.currentExercise, isNull);
    });
  });

  group('Per-question timeout (step 4.2, commit B)', () {
    List<ArithmeticExercise> manyExercises(int count) => List.generate(
      count,
      (i) => ArithmeticExercise(
        operandA: i,
        operandB: 0,
        operationType: OperationType.addition,
      ),
    );

    SessionController buildTimeoutController({
      required _TimerSpy spy,
      required int exerciseCount,
      SessionRepository? repository,
    }) {
      return SessionController(
        config: SessionConfig(
          seed: 1,
          enabledTypes: {ExerciseType.addition},
          exerciseCount: exerciseCount,
          levels: {ExerciseType.addition: Level.whole(50)},
        ),
        exerciseSource: _FixedExerciseSource(manyExercises(exerciseCount)),
        repository: repository ?? InMemorySessionRepository(),
        playerId: 'test-player',
        clock: () => DateTime(2024),
        createTimer: spy.create,
      );
    }

    test(
      'a timeout without activity counts as wrong and moves to the next question',
      () {
        final spy = _TimerSpy();
        final controller = buildTimeoutController(spy: spy, exerciseCount: 5);

        controller.start();
        spy.latest.fire();

        expect(controller.state.status, SessionStatus.inProgress);
        expect(controller.state.outcomes, hasLength(1));
        expect(controller.state.outcomes.single.isCorrect, isFalse);
        expect(controller.state.outcomes.single.isTimeout, isTrue);
        expect(controller.state.currentExercise, manyExercises(5)[1]);
      },
    );

    test(
      'a timeout after activity (input never submitted) does not count towards abandonment',
      () {
        final spy = _TimerSpy();
        final controller = buildTimeoutController(spy: spy, exerciseCount: 10);

        controller.start();
        // 3 timeouts, but with activity each time: must never
        // interrupt.
        for (var i = 0; i < 3; i++) {
          controller.registerActivity();
          spy.latest.fire();
        }

        expect(controller.state.status, SessionStatus.inProgress);
        expect(controller.state.outcomes, hasLength(3));
      },
    );

    test('no timeout (debug switch): no timer armed, the question waits', () {
      final spy = _TimerSpy();
      final controller = SessionController(
        config: SessionConfig(
          seed: 1,
          enabledTypes: {ExerciseType.addition},
          exerciseCount: 3,
          levels: {ExerciseType.addition: Level.whole(50)},
        ),
        exerciseSource: _FixedExerciseSource(manyExercises(3)),
        repository: InMemorySessionRepository(),
        playerId: 'test-player',
        clock: () => DateTime(2024),
        createTimer: spy.create,
        questionTimeout: null,
      );

      controller.start();
      controller.submitAnswer(0);

      expect(spy.created, isEmpty);
      expect(controller.state.status, SessionStatus.inProgress);
      expect(controller.state.outcomes, hasLength(1));
      expect(controller.state.outcomes.single.isTimeout, isFalse);
    });

    test(
      'three consecutive timeouts without any activity interrupt the session',
      () {
        final spy = _TimerSpy();
        final controller = buildTimeoutController(spy: spy, exerciseCount: 10);

        controller.start();
        spy.latest.fire();
        spy.latest.fire();
        spy.latest.fire();

        expect(controller.state.status, SessionStatus.interrupted);
        expect(controller.state.outcomes, hasLength(3));
        expect(controller.state.currentExercise, isNull);
      },
    );

    test(
      'a real answer between two timeouts resets the abandonment counter',
      () {
        final spy = _TimerSpy();
        final controller = buildTimeoutController(spy: spy, exerciseCount: 10);

        controller.start();
        spy.latest.fire(); // timeout 1, no activity
        spy.latest.fire(); // timeout 2, no activity
        controller.submitAnswer(0); // real answer: resets the counter to 0
        spy.latest.fire(); // timeout 1 (nouveau compte)
        spy.latest.fire(); // timeout 2

        // 4 timeouts + 1 real answer, but never 3 consecutive timeouts without
        // activity: still in progress.
        expect(controller.state.status, SessionStatus.inProgress);
      },
    );

    test(
      'an interrupted session stores the answers already given but not the level',
      () async {
        final repository = InMemorySessionRepository();
        final spy = _TimerSpy();
        final controller = buildTimeoutController(
          spy: spy,
          exerciseCount: 10,
          repository: repository,
        );

        controller.start();
        spy.latest.fire();
        spy.latest.fire();
        spy.latest.fire();
        await Future<void>.delayed(Duration.zero);

        final sessions = await repository.recentSessions('test-player');
        expect(sessions, hasLength(1));
        // exerciseCount stays the planned count (10), not the number of
        // answers actually given (3): this gap tells an interrupted session
        // from a finished one, without a dedicated field.
        expect(sessions.single.exerciseCount, 10);
        final answers = await repository.answersForSession(sessions.single.id);
        expect(answers, hasLength(3));

        // Does not count for levels.
        expect(await repository.currentLevels('test-player'), isEmpty);
      },
    );

    test(
      'pendingPersistence only resolves once the session is written (immediate replay, '
      'step 4.2 commit C)',
      () async {
        final repository = InMemorySessionRepository();
        final controller = buildTimeoutController(
          spy: _TimerSpy(),
          exerciseCount: 3,
          repository: repository,
        );

        controller.start();
        controller.submitAnswer(0);
        controller.submitAnswer(1);
        controller.submitAnswer(2);

        await controller.pendingPersistence;

        final sessions = await repository.recentSessions('test-player');
        expect(sessions, hasLength(1));
      },
    );

    test(
      'pendingPersistence is already resolved while no session has ended',
      () async {
        final controller = buildTimeoutController(
          spy: _TimerSpy(),
          exerciseCount: 5,
        );
        controller.start();

        // Must not block: no persistence running.
        await controller.pendingPersistence;
      },
    );

    test('restart() cancels the running session timer', () {
      final spy = _TimerSpy();
      final controller = buildTimeoutController(spy: spy, exerciseCount: 5);

      controller.start();
      final staleTimer = spy.latest;
      expect(staleTimer.isActive, isTrue);

      controller.restart();

      expect(staleTimer.isActive, isFalse);
      expect(controller.state.status, SessionStatus.notStarted);
    });
  });

  group('correction pause after a mistake (Phase 0, commit 9)', () {
    const delay = Duration(milliseconds: 1000);
    List<ArithmeticExercise> questions(int count) => List.generate(
      count,
      (i) => ArithmeticExercise(
        operandA: i,
        operandB: 1,
        operationType: OperationType.addition,
      ),
    );

    ({SessionController controller, _TimerSpy spy, void Function(int) tick})
    build({int count = 4, InMemorySessionRepository? repository}) {
      final spy = _TimerSpy();
      var now = DateTime.utc(2024, 5, 1, 12);
      final controller = SessionController(
        config: SessionConfig(
          seed: 1,
          enabledTypes: {ExerciseType.addition},
          exerciseCount: count,
          levels: {ExerciseType.addition: Level.whole(1)},
        ),
        exerciseSource: _FixedExerciseSource(questions(count)),
        repository: repository ?? InMemorySessionRepository(),
        playerId: 'test-player',
        clock: () => now,
        createTimer: spy.create,
        correctionDelay: delay,
      );
      return (
        controller: controller,
        spy: spy,
        tick: (ms) => now = now.add(Duration(milliseconds: ms)),
      );
    }

    test('a wrong answer keeps the question on screen with its correction', () {
      final s = build();
      s.controller.start();

      s.controller.submitAnswer(99); // 0 + 1 = 1

      final state = s.controller.state;
      expect(state.status, SessionStatus.inProgress);
      expect(state.isCorrecting, isTrue);
      expect(state.correction, state.outcomes.single);
      expect(state.currentExercise, questions(4)[0]);
      expect(s.spy.durations.last, delay);
      expect(s.spy.created.first.isActive, isFalse); // timeout cancelled
    });

    test('a right answer moves on at once, no pause', () {
      final s = build();
      s.controller.start();

      s.controller.submitAnswer(1);

      expect(s.controller.state.isCorrecting, isFalse);
      expect(s.controller.state.currentExercise, questions(4)[1]);
      expect(s.spy.durations.last, SessionController.defaultQuestionTimeout);
    });

    test('a timeout is corrected the same way', () {
      final s = build();
      s.controller.start();

      s.spy.latest.fire();

      expect(s.controller.state.correction?.isTimeout, isTrue);
      expect(s.controller.state.currentExercise, questions(4)[0]);
    });

    test('input during the pause is ignored', () {
      final s = build();
      s.controller.start();
      s.controller.submitAnswer(99);

      s.controller.submitAnswer(1);

      expect(s.controller.state.outcomes, hasLength(1));
      expect(s.controller.state.isCorrecting, isTrue);
    });

    test('after the pause: next question, fresh clock and timeout', () {
      final s = build();
      s.controller.start();
      s.tick(3000);
      s.controller.submitAnswer(99);

      s.tick(1000); // the pause
      s.spy.latest.fire();
      expect(s.controller.state.isCorrecting, isFalse);
      expect(s.controller.state.currentExercise, questions(4)[1]);
      expect(s.spy.durations.last, SessionController.defaultQuestionTimeout);

      s.tick(2000);
      s.controller.submitAnswer(2);
      // The pause never counts in the next response time.
      expect(s.controller.state.outcomes.last.elapsedMs, 2000);
    });

    test('a mistake on the last question ends the session without pause', () {
      final s = build(count: 1);
      s.controller.start();

      s.controller.submitAnswer(99);

      expect(s.controller.state.status, SessionStatus.finished);
      expect(s.controller.state.isCorrecting, isFalse);
    });

    test('abandoning during the pause interrupts and cancels it', () {
      final s = build();
      s.controller.start();
      s.controller.submitAnswer(99);
      final pause = s.spy.latest;

      s.controller.abandon();

      expect(s.controller.state.status, SessionStatus.interrupted);
      expect(pause.isActive, isFalse);
    });

    test('three silent timeouts still interrupt, pauses in between', () {
      final s = build(count: 10);
      s.controller.start();

      for (var i = 0; i < 2; i++) {
        s.spy.latest.fire(); // timeout
        expect(s.controller.state.isCorrecting, isTrue);
        s.spy.latest.fire(); // end of the pause
      }
      s.spy.latest.fire(); // third timeout

      expect(s.controller.state.status, SessionStatus.interrupted);
      expect(s.controller.state.outcomes, hasLength(3));
    });
  });

  group('abandon() (step 5, commit A)', () {
    List<ArithmeticExercise> manyExercises(int count) => List.generate(
      count,
      (i) => ArithmeticExercise(
        operandA: i,
        operandB: 0,
        operationType: OperationType.addition,
      ),
    );

    test('interrupts a running session, answers already given kept', () async {
      final repository = InMemorySessionRepository();
      final controller = SessionController(
        config: SessionConfig(
          seed: 1,
          enabledTypes: {ExerciseType.addition},
          exerciseCount: 10,
          levels: {ExerciseType.addition: Level.whole(50)},
        ),
        exerciseSource: _FixedExerciseSource(manyExercises(10)),
        repository: repository,
        playerId: 'test-player',
        clock: () => DateTime(2024),
        createTimer: (duration, callback) => _FakeTimer(callback),
      );

      controller.start();
      controller.submitAnswer(0);
      controller.submitAnswer(1);
      controller.abandon();

      expect(controller.state.status, SessionStatus.interrupted);
      expect(controller.state.outcomes, hasLength(2));
      expect(controller.state.currentExercise, isNull);

      await controller.pendingPersistence;
      final sessions = await repository.recentSessions('test-player');
      expect(sessions, hasLength(1));
      expect(sessions.single.exerciseCount, 10);
      final answers = await repository.answersForSession(sessions.single.id);
      expect(answers, hasLength(2));
      // Does not count for levels, like an automatic interruption.
      expect(await repository.currentLevels('test-player'), isEmpty);
    });

    test('before any answer: nothing is stored', () async {
      final repository = InMemorySessionRepository();
      final controller = SessionController(
        config: SessionConfig(
          seed: 1,
          enabledTypes: {ExerciseType.addition},
          exerciseCount: 10,
          levels: {ExerciseType.addition: Level.whole(50)},
        ),
        exerciseSource: _FixedExerciseSource(manyExercises(10)),
        repository: repository,
        playerId: 'test-player',
        clock: () => DateTime(2024),
        createTimer: (duration, callback) => _FakeTimer(callback),
      );

      controller.start();
      controller.abandon();
      await controller.pendingPersistence;

      expect(controller.state.status, SessionStatus.interrupted);
      expect(await repository.recentSessions('test-player'), isEmpty);
    });

    test('cancels the running timer', () {
      final spy = _TimerSpy();
      final controller = SessionController(
        config: SessionConfig(
          seed: 1,
          enabledTypes: {ExerciseType.addition},
          exerciseCount: 5,
          levels: {ExerciseType.addition: Level.whole(1)},
        ),
        exerciseSource: _FixedExerciseSource(manyExercises(5)),
        repository: InMemorySessionRepository(),
        playerId: 'test-player',
        clock: () => DateTime(2024),
        createTimer: spy.create,
      );

      controller.start();
      final timer = spy.latest;
      expect(timer.isActive, isTrue);

      controller.abandon();

      expect(timer.isActive, isFalse);
    });

    test('does nothing before start() or after the session ended', () {
      final controller = SessionController(
        config: SessionConfig(
          seed: 1,
          enabledTypes: {ExerciseType.addition},
          exerciseCount: 1,
          levels: {ExerciseType.addition: Level.whole(1)},
        ),
        exerciseSource: _FixedExerciseSource(manyExercises(1)),
        repository: InMemorySessionRepository(),
        playerId: 'test-player',
        clock: () => DateTime(2024),
        createTimer: (duration, callback) => _FakeTimer(callback),
      );

      controller.abandon();
      expect(controller.state.status, SessionStatus.notStarted);

      controller.start();
      controller.submitAnswer(0); // only question: session already finished
      expect(controller.state.status, SessionStatus.finished);

      controller.abandon();
      expect(controller.state.status, SessionStatus.finished);
    });
  });

  group('lastLevelUpdates (step 5, commit D)', () {
    test('is set once the session ends normally', () async {
      final repository = InMemorySessionRepository();
      final eightExercises = List.generate(
        8,
        (i) => ArithmeticExercise(
          operandA: i,
          operandB: 0,
          operationType: OperationType.addition,
        ),
      );
      final controller = SessionController(
        config: SessionConfig(
          seed: 1,
          enabledTypes: {ExerciseType.addition},
          exerciseCount: 8,
          levels: {ExerciseType.addition: Level.whole(50)},
        ),
        exerciseSource: _FixedExerciseSource(eightExercises),
        repository: repository,
        playerId: 'test-player',
        clock: () => DateTime(2024),
        createTimer: (duration, callback) => _FakeTimer(callback),
      );

      expect(controller.lastLevelUpdates, isNull);

      controller.start();
      for (var i = 0; i < 8; i++) {
        controller.submitAnswer(i); // i + 0 = i: always right
      }
      await controller.pendingPersistence;

      expect(
        controller.lastLevelUpdates?[ExerciseType.addition]?.level,
        Level.whole(53),
      );
    });

    test(
      'stays null after an interrupted session (countsForLevels: false)',
      () async {
        final repository = InMemorySessionRepository();
        final controller = SessionController(
          config: SessionConfig(
            seed: 1,
            enabledTypes: {ExerciseType.addition},
            exerciseCount: 8,
            levels: {ExerciseType.addition: Level.whole(50)},
          ),
          exerciseSource: _FixedExerciseSource(
            List.generate(
              8,
              (i) => ArithmeticExercise(
                operandA: i,
                operandB: 0,
                operationType: OperationType.addition,
              ),
            ),
          ),
          repository: repository,
          playerId: 'test-player',
          clock: () => DateTime(2024),
          createTimer: (duration, callback) => _FakeTimer(callback),
        );

        controller.start();
        controller.submitAnswer(0);
        controller.abandon();
        await controller.pendingPersistence;

        expect(controller.lastLevelUpdates, isNull);
      },
    );

    test('restart() clears the previous value', () async {
      final repository = InMemorySessionRepository();
      final controller = SessionController(
        config: SessionConfig(
          seed: 1,
          enabledTypes: {ExerciseType.addition},
          exerciseCount: 4,
          levels: {ExerciseType.addition: Level.whole(50)},
        ),
        exerciseSource: _FixedExerciseSource(
          List.generate(
            4,
            (i) => ArithmeticExercise(
              operandA: i,
              operandB: 0,
              operationType: OperationType.addition,
            ),
          ),
        ),
        repository: repository,
        playerId: 'test-player',
        clock: () => DateTime(2024),
        createTimer: (duration, callback) => _FakeTimer(callback),
      );

      controller.start();
      for (var i = 0; i < 4; i++) {
        controller.submitAnswer(i);
      }
      await controller.pendingPersistence;
      expect(controller.lastLevelUpdates, isNotNull);

      controller.restart();

      expect(controller.lastLevelUpdates, isNull);
    });
  });
}

class _RecordFailureRepository extends InMemorySessionRepository {
  @override
  Future<void> recordSession({
    required PersistedSession session,
    required List<PersistedAnswer> answers,
    required Map<ExerciseType, LevelCacheEntry> levelUpdates,
  }) async => throw Exception('disk full (simulated)');
}

/// Fails while [failuresLeft] > 0, then writes normally — storage briefly
/// unavailable.
class _FlakyRecordRepository extends InMemorySessionRepository {
  _FlakyRecordRepository(this.failuresLeft);

  int failuresLeft;

  @override
  Future<void> recordSession({
    required PersistedSession session,
    required List<PersistedAnswer> answers,
    required Map<ExerciseType, LevelCacheEntry> levelUpdates,
  }) async {
    if (failuresLeft > 0) {
      failuresLeft--;
      throw Exception('storage unavailable (simulated)');
    }
    await super.recordSession(
      session: session,
      answers: answers,
      levelUpdates: levelUpdates,
    );
  }
}

void persistenceRobustnessTests() {
  SessionController finishedSoon(SessionRepository repository) =>
      SessionController(
        config: SessionConfig(
          seed: 1,
          enabledTypes: {ExerciseType.addition},
          exerciseCount: 4,
          levels: {ExerciseType.addition: Level.whole(10)},
        ),
        exerciseSource: _FixedExerciseSource(
          List.generate(
            4,
            (i) => ArithmeticExercise(
              operandA: i,
              operandB: 0,
              operationType: OperationType.addition,
            ),
          ),
        ),
        repository: repository,
        playerId: 'test-player',
        clock: () => DateTime(2024),
        createTimer: (duration, callback) => _FakeTimer(callback),
      );

  group('robustness of the end-of-session write', () {
    test(
      'controller disposed right after the last answer: the game is still stored',
      () async {
        final repository = InMemorySessionRepository();
        final controller = finishedSoon(repository)..start();
        for (var i = 0; i < 4; i++) {
          controller.submitAnswer(i);
        }
        // "New selection" tapped before the write finished.
        controller.dispose();

        await controller.pendingPersistence;

        expect(await repository.recentSessions('test-player'), hasLength(1));
        expect(await repository.currentLevels('test-player'), isNotEmpty);
      },
    );

    test('a save failure is exposed, not silently swallowed', () async {
      final controller = finishedSoon(_RecordFailureRepository())..start();
      expect(controller.persistenceFailed, isFalse);
      for (var i = 0; i < 4; i++) {
        controller.submitAnswer(i);
      }

      await controller.pendingPersistence;

      expect(controller.persistenceFailed, isTrue);
    });

    test(
      'retrying after a failure stores the game and clears the warning',
      () async {
        final repository = _FlakyRecordRepository(1);
        final controller = finishedSoon(repository)..start();
        for (var i = 0; i < 4; i++) {
          controller.submitAnswer(i);
        }
        await controller.pendingPersistence;
        expect(controller.persistenceFailed, isTrue);

        await controller.retryPersistence();

        expect(controller.persistenceFailed, isFalse);
        expect(await repository.recentSessions('test-player'), hasLength(1));
        expect(await repository.currentLevels('test-player'), isNotEmpty);
      },
    );

    test(
      'a new failure keeps the warning; pendingPersistence waits for the next attempt',
      () async {
        final repository = _FlakyRecordRepository(2);
        final controller = finishedSoon(repository)..start();
        for (var i = 0; i < 4; i++) {
          controller.submitAnswer(i);
        }
        await controller.pendingPersistence;

        await controller.retryPersistence();
        expect(controller.persistenceFailed, isTrue);
        expect(controller.isRetryingPersistence, isFalse);

        // Not awaited here: `pendingPersistence` (what leaving the result
        // screen waits for) must cover this new attempt.
        unawaited(controller.retryPersistence());
        expect(controller.isRetryingPersistence, isTrue);
        await controller.pendingPersistence;

        expect(controller.persistenceFailed, isFalse);
        expect(await repository.recentSessions('test-player'), hasLength(1));
      },
    );
  });

  group('overall level after the session (overallLevelAfter)', () {
    test(
      'computed over the whole cache, types not played this time included',
      () async {
        final repository = InMemorySessionRepository();
        // Multiplication played in an earlier game, not this time.
        await repository.recordSession(
          session: PersistedSession(
            id: 'partie-precedente',
            playerId: 'test-player',
            seed: 1,
            enabledTypes: const {ExerciseType.multiplication},
            exerciseCount: 4,
            totalScore: 40,
            levels: {ExerciseType.multiplication: Level.whole(50)},
            createdAt: DateTime.utc(2023),
          ),
          answers: const [],
          levelUpdates: {
            ExerciseType.multiplication: LevelCacheEntry(
              level: Level.whole(50),
              sessionsPlayed: 1,
              updatedAt: DateTime.utc(2023),
            ),
          },
        );
        final controller = finishedSoon(repository)..start();
        for (var i = 0; i < 4; i++) {
          controller.submitAnswer(i);
        }
        await controller.pendingPersistence;

        final additionAfter = (await repository.currentLevels(
          'test-player',
        ))[ExerciseType.addition]!.level.value;
        final session = (await repository.recentSessions('test-player')).first;
        // Main level: addition updated + multiplication 50 + the two other
        // basics at 0, over 4.
        expect(
          session.overallLevelAfter,
          closeTo((additionAfter + 50) / 4, 1e-9),
        );
      },
    );

    test(
      'unreadable cache: session stored anyway, without this value',
      () async {
        final repository = _LevelReadFailureRepository();
        final controller = finishedSoon(repository)..start();
        for (var i = 0; i < 4; i++) {
          controller.submitAnswer(i);
        }
        await controller.pendingPersistence;

        final sessions = await repository.inner.recentSessions('test-player');
        expect(sessions.single.overallLevelAfter, isNull);
      },
    );
  });

  group('input device and app version (after Phase 3a)', () {
    test('each answer records its keys, the session its build', () async {
      final spy = _TimerSpy();
      final repository = InMemorySessionRepository();
      final controller = SessionController(
        config: SessionConfig(
          seed: 1,
          enabledTypes: {ExerciseType.addition},
          exerciseCount: 5,
          levels: {ExerciseType.addition: Level.whole(50)},
        ),
        exerciseSource: _FixedExerciseSource([
          for (var i = 0; i < 5; i++)
            ArithmeticExercise(
              operandA: i,
              operandB: 0,
              operationType: OperationType.addition,
            ),
        ]),
        repository: repository,
        playerId: 'test-player',
        clock: () => DateTime(2024),
        createTimer: spy.create,
        appVersion: 'e9bd019',
      )..start();

      // On-screen keypad only.
      controller.registerActivity(InputDevice.keypad);
      controller.submitAnswer(0, device: InputDevice.keypad);
      // Physical keyboard only.
      controller.registerActivity(InputDevice.keyboard);
      controller.submitAnswer(1, device: InputDevice.keyboard);
      // Typed on the keyboard, submitted on the keypad.
      controller.registerActivity(InputDevice.keyboard);
      controller.submitAnswer(2, device: InputDevice.keypad);
      // A key, then the time ran out: the key counts.
      controller.registerActivity(InputDevice.keypad);
      spy.latest.fire();
      // Nothing pressed before the time ran out: unknown.
      spy.latest.fire();
      await controller.pendingPersistence;

      final session = (await repository.recentSessions('test-player')).single;
      expect(session.appVersion, 'e9bd019');
      final answers = await repository.answersForSession(session.id);
      expect(answers.map((a) => a.inputDevice), [
        InputDevice.keypad,
        InputDevice.keyboard,
        InputDevice.mixed,
        InputDevice.keypad,
        null,
      ]);
    });
  });
}
