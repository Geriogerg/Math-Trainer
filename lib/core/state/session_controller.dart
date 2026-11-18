import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/generation/exercise_source.dart';
import '../domain/leveling/level_cache_orchestrator.dart';
import '../domain/leveling/overall_level.dart';
import '../domain/models/answer_result.dart';
import '../domain/models/exercise.dart';
import '../domain/models/exercise_type.dart';
import '../domain/models/session_config.dart';
import '../domain/models/session_result.dart';
import '../domain/persistence/exercise_codec.dart';
import '../domain/persistence/level_cache_entry.dart';
import '../domain/persistence/persisted_answer.dart';
import '../domain/persistence/persisted_session.dart';
import '../domain/persistence/session_repository.dart';
import '../domain/persistence/uuid.dart';
import '../domain/scoring/scorer.dart';
import 'session_state.dart';

/// End-of-session write, kept as is if it fails so that
/// [SessionController.retryPersistence] can replay it identically.
typedef _SessionWrite = ({
  PersistedSession session,
  List<PersistedAnswer> answers,
  Map<ExerciseType, LevelCacheEntry> levelUpdates,
});

/// Session orchestration: exercise source + scoring + persistence at the
/// end of the session. Depends on interfaces (`ExerciseSource`,
/// `SessionRepository`), never on a concrete implementation, so that duels
/// or a future backend can replace them without changing this class or the
/// UI observing it.
///
/// `ChangeNotifier` comes from `flutter/foundation.dart`: an observable
/// object native to the Flutter SDK (not a widget). `notifyListeners()`
/// tells every listening widget (through `ListenableBuilder`) to rebuild.
class SessionController extends ChangeNotifier {
  SessionController({
    required this.config,
    required this.exerciseSource,
    required this.repository,
    required this.playerId,
    this.scorer = const Scorer(),
    this.clock = DateTime.now,
    this.idGenerator = generateUuidV4,
    this.createTimer = Timer.new,
    this.questionTimeout = defaultQuestionTimeout,
    LevelCacheOrchestrator? levelCacheOrchestrator,
  }) : levelCacheOrchestrator =
           levelCacheOrchestrator ?? LevelCacheOrchestrator();

  final SessionConfig config;
  final ExerciseSource exerciseSource;
  final LevelCacheOrchestrator levelCacheOrchestrator;
  final SessionRepository repository;
  final String playerId;
  final Scorer scorer;
  final DateTime Function() clock;
  final String Function() idGenerator;

  /// Injectable for tests (same spirit as [clock]/[idGenerator]) — a real
  /// 15 s `Timer` must never run during a test.
  final Timer Function(Duration duration, void Function() callback) createTimer;

  static const defaultQuestionTimeout = Duration(seconds: 15);

  /// `null`: no timeout at all — only the debug switch of
  /// `composition_root.dart` passes it (`questionTimeoutFor`); without
  /// timeouts there is no abandonment interruption either.
  final Duration? questionTimeout;

  /// Three consecutive timeouts without any key pressed interrupt the
  /// session (`doc/decisions.md`).
  static const _abandonThreshold = 3;

  SessionState _state = SessionState.initial();
  SessionState get state => _state;

  DateTime? _questionStartedAt;
  Timer? _timeoutTimer;
  bool _hasActivityThisQuestion = false;
  int _consecutiveTimeoutsWithoutActivity = 0;
  Future<void>? _pendingPersistence;
  Map<ExerciseType, LevelCacheEntry>? _lastLevelUpdates;
  bool _persistenceFailed = false;
  _SessionWrite? _failedWrite;
  bool _isRetryingPersistence = false;
  bool _isDisposed = false;

  /// The end-of-session write failed: the game is not in the history and
  /// the levels did not move. Shown on the result screen — without it, the
  /// player would believe their progress counted.
  bool get persistenceFailed => _persistenceFailed;

  /// A new attempt ([retryPersistence]) is running.
  bool get isRetryingPersistence => _isRetryingPersistence;

  /// Replays the failed write identically (same ids): `recordSession` is
  /// atomic, a failure left nothing behind, so nothing can be written
  /// twice. Replaces [pendingPersistence] so that leaving the result screen
  /// also waits for this attempt before re-reading the levels. No effect if
  /// there is nothing to replay.
  Future<void> retryPersistence() async {
    final write = _failedWrite;
    if (write == null || _isRetryingPersistence) return;
    _isRetryingPersistence = true;
    _notifyIfAlive();
    final attempt = _record(write);
    _pendingPersistence = attempt;
    await attempt;
    _isRetryingPersistence = false;
    _notifyIfAlive();
  }

  /// The end-of-session write continues after the screen closes ("New
  /// selection" right after the last answer disposes the controller):
  /// notifying a disposed `ChangeNotifier` throws in debug, and that error
  /// interrupted the write before `recordSession` — game lost.
  void _notifyIfAlive() {
    if (!_isDisposed) notifyListeners();
  }

  /// Levels updated by the session that just ended — `null` until the
  /// asynchronous computation (`_persistCompletedSession`) has resolved, or
  /// after an interrupted session (never computed, see `countsForLevels`).
  /// Not in `outcomes`, so it cannot be rebuilt otherwise: the result screen
  /// uses it to animate the level change (`doc/design.md`,
  /// `AppMotion.levelUp`).
  Map<ExerciseType, LevelCacheEntry>? get lastLevelUpdates => _lastLevelUpdates;

  /// Resolves when the end-of-session write (answers + possible level cache
  /// update) is done. An immediate replay must wait for it before re-reading
  /// the levels — `_persistCompletedSession` runs in the background, without
  /// this `buildSessionController` could read the levels from *before* the
  /// session that just ended.
  Future<void> get pendingPersistence =>
      _pendingPersistence ?? Future<void>.value();

  void start() {
    _state = SessionState(
      status: SessionStatus.inProgress,
      currentExercise: exerciseSource.next(),
    );
    _questionStartedAt = clock();
    _scheduleTimeout();
    notifyListeners();
  }

  /// Called by the screen on every keypad key — digit *or* backspace, not
  /// only Submit. This is what tells "tried" from "touched nothing" for the
  /// abandonment interruption: a timeout after input that was never
  /// submitted does not count as abandonment.
  void registerActivity() {
    _hasActivityThisQuestion = true;
  }

  void _scheduleTimeout() {
    _timeoutTimer?.cancel();
    _hasActivityThisQuestion = false;
    final timeout = questionTimeout;
    _timeoutTimer = timeout == null ? null : createTimer(timeout, _onTimeout);
  }

  void _onTimeout() {
    final exercise = _state.currentExercise;
    final timeout = questionTimeout;
    if (_state.status != SessionStatus.inProgress ||
        exercise == null ||
        timeout == null) {
      return;
    }

    final hadActivity = _hasActivityThisQuestion;
    _recordOutcome(
      exercise: exercise,
      submittedValue: timeoutSubmittedValue,
      isCorrect: false,
      elapsedMs: timeout.inMilliseconds,
      answeredAt: clock().toUtc(),
    );

    if (hadActivity) {
      _consecutiveTimeoutsWithoutActivity = 0;
      return;
    }
    _consecutiveTimeoutsWithoutActivity++;
    // Completion wins: if this timeout falls on the last question,
    // _recordOutcome has just set the status to `finished` — the session
    // ends normally, it is not interrupted.
    if (_consecutiveTimeoutsWithoutActivity >= _abandonThreshold &&
        _state.status == SessionStatus.inProgress) {
      _interruptSession();
    }
  }

  void submitAnswer(int submittedValue) {
    final exercise = _state.currentExercise;
    if (_state.status != SessionStatus.inProgress || exercise == null) return;

    final isCorrect = exercise.isCorrectAnswer(submittedValue);
    _consecutiveTimeoutsWithoutActivity = 0;
    final now = clock();
    _recordOutcome(
      exercise: exercise,
      submittedValue: submittedValue,
      isCorrect: isCorrect,
      elapsedMs: now.difference(_questionStartedAt!).inMilliseconds,
      answeredAt: now.toUtc(),
    );
  }

  /// Computes score/streak, moves to the next question or ends the session,
  /// notifies, and triggers persistence if the session ends. Shared by
  /// [submitAnswer] and [_onTimeout]: a timeout follows exactly the same
  /// path as a wrong answer, only [submittedValue] differs.
  void _recordOutcome({
    required Exercise exercise,
    required int submittedValue,
    required bool isCorrect,
    required int elapsedMs,
    required DateTime answeredAt,
  }) {
    final nextStreak = isCorrect ? _state.currentStreak + 1 : 0;

    final outcome = AnswerResult(
      exercise: exercise,
      submittedValue: submittedValue,
      isCorrect: isCorrect,
      elapsedMs: elapsedMs,
      answeredAt: answeredAt,
    );
    final points = scorer.pointsFor(
      outcome,
      currentStreak: nextStreak,
      level: config.levels[exercise.type] ?? 1,
    );
    final outcomes = [..._state.outcomes, outcome];
    final isSessionComplete = outcomes.length >= config.exerciseCount;

    _state = SessionState(
      status: isSessionComplete
          ? SessionStatus.finished
          : SessionStatus.inProgress,
      currentExercise: isSessionComplete ? null : exerciseSource.next(),
      outcomes: outcomes,
      score: _state.score + points,
      currentStreak: nextStreak,
    );
    _questionStartedAt = clock();

    if (isSessionComplete) {
      _timeoutTimer?.cancel();
    } else {
      _scheduleTimeout();
    }
    notifyListeners();

    if (isSessionComplete) {
      _pendingPersistence = _persistCompletedSession(countsForLevels: true);
    }
  }

  void _interruptSession() {
    _timeoutTimer?.cancel();
    _state = SessionState(
      status: SessionStatus.interrupted,
      outcomes: _state.outcomes,
      score: _state.score,
      currentStreak: _state.currentStreak,
    );
    notifyListeners();
    // Abandoned before any answer (the only possible case: a timeout always
    // records an answer) — nothing to keep, and an empty session would show
    // up as a 0-point game in the Profile history.
    if (_state.outcomes.isEmpty) return;
    _pendingPersistence = _persistCompletedSession(countsForLevels: false);
  }

  /// Manual abandonment (confirmed back gesture, step 5 commit A): same
  /// handling as an automatic interruption — `interrupted` status, answers
  /// already given persisted, level cache untouched. Nothing new: the
  /// finished/interrupted distinction exists since step 4.2.
  void abandon() {
    if (_state.status != SessionStatus.inProgress) return;
    _interruptSession();
  }

  SessionResult get result => SessionResult(
    outcomes: _state.outcomes,
    totalScore: _state.score,
    scorer: scorer,
  );

  void restart() {
    _timeoutTimer?.cancel();
    _state = SessionState.initial();
    _questionStartedAt = null;
    _lastLevelUpdates = null;
    _persistenceFailed = false;
    _failedWrite = null;
    _isRetryingPersistence = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _timeoutTimer?.cancel();
    super.dispose();
  }

  /// [countsForLevels]: `false` for an interrupted session (abandonment) —
  /// the session and the answers already given are still stored (they
  /// cannot be rebuilt otherwise), only the level cache computation is
  /// skipped. `PersistedSession.exerciseCount` stays the *planned* count;
  /// `answers.length < exerciseCount` is enough to recognise an interrupted
  /// session later, with no extra field to persist.
  Future<void> _persistCompletedSession({required bool countsForLevels}) async {
    final sessionId = idGenerator();
    final createdAt = clock().toUtc();

    final answers = _state.outcomes.map((outcome) {
      final described = describeExerciseForStorage(outcome.exercise);
      return PersistedAnswer(
        id: idGenerator(),
        sessionId: sessionId,
        exerciseType: described.exerciseType,
        operationType: described.operationType,
        operands: described.operands,
        submittedValue: outcome.submittedValue,
        isCorrect: outcome.isCorrect,
        elapsedMs: outcome.elapsedMs,
        createdAt: outcome.answeredAt,
      );
    }).toList();

    var levelUpdates = const <ExerciseType, LevelCacheEntry>{};
    if (countsForLevels) {
      try {
        levelUpdates = await levelCacheOrchestrator.computeUpdates(
          outcomes: _state.outcomes,
          frozenLevels: config.levels,
          repository: repository,
          playerId: playerId,
          now: createdAt,
        );
      } on Exception catch (_) {
        // The level cache can be recomputed from history (see
        // doc/decisions.md): a failed read must not prevent recording the
        // session, which cannot be rebuilt from anywhere else — what cannot
        // be rebuilt comes first.
        //
        // `on Exception`, not `catch (_)`: an `Error` (ArgumentError,
        // StateError...) signals a bug — an invariant throwing somewhere in
        // this chain (LevelUpdater, LevelCacheEntry, LevelingRules...) must
        // stay visible, not be swallowed like a network/disk failure. This is
        // exactly what rule 13 defends: a catch that is too broad would bring
        // back the problem of an `assert` stripped in release, on the
        // try/catch side this time.
      }
      // Set even when empty (failure above, or no type reached n_min this
      // session): `null` specifically means "never computed" (interrupted
      // session), not "computed, nothing changed".
      _lastLevelUpdates = levelUpdates;
      _notifyIfAlive();
    }

    // Full cache (7 types) after this session, not only the types played:
    // see `PersistedSession.overallLevelAfter`.
    double? overallLevelAfter;
    try {
      final cacheBefore = await repository.currentLevels(playerId);
      overallLevelAfter = overallLevel({...cacheBefore, ...levelUpdates});
    } on Exception catch (_) {
      // One point fewer on the Profile curve, nothing more — does not block
      // writing the session itself.
    }

    final session = PersistedSession(
      id: sessionId,
      playerId: playerId,
      seed: config.seed,
      enabledTypes: config.enabledTypes,
      exerciseCount: config.exerciseCount,
      totalScore: _state.score,
      levels: config.levels,
      createdAt: createdAt,
      overallLevelAfter: overallLevelAfter,
    );

    await _record((
      session: session,
      answers: answers,
      levelUpdates: levelUpdates,
    ));
  }

  /// Persistence must never break the running game: a failure is reported
  /// ([persistenceFailed]) and the write kept for [retryPersistence] — in
  /// memory only, lost when the app closes (server upload, Phase 2, will
  /// have its own retry).
  Future<void> _record(_SessionWrite write) async {
    try {
      await repository.recordSession(
        session: write.session,
        answers: write.answers,
        levelUpdates: write.levelUpdates,
      );
    } on Exception catch (_) {
      _failedWrite = write;
      _persistenceFailed = true;
      _notifyIfAlive();
      return;
    }
    if (_persistenceFailed) {
      _failedWrite = null;
      _persistenceFailed = false;
      _notifyIfAlive();
    }
  }
}
