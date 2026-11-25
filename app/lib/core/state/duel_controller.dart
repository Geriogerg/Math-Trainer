import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:math_core/challenges/count.dart';
import 'package:math_core/duel/duel_client.dart';
import 'package:math_core/duel/duel_config.dart';
import 'package:math_core/duel/duel_run.dart';
import 'package:math_core/duel/duel_run_queue.dart';
import 'package:math_core/duel/duel_validation.dart';
import 'package:math_core/models/answer_result.dart';
import 'package:math_core/patterns/pattern_family.dart';

import 'count_controller.dart';
import 'session_controller.dart';
import 'session_state.dart';

/// Where a duel stands on screen.
enum DuelPhase {
  /// The questions or rounds are being played.
  playing,

  /// The run is played; the server is being told.
  sending,

  /// Decided: by the server ([DuelController.verdict]), or locally while
  /// the run waits to be sent ([DuelController.pending]).
  done,
}

/// One lane's progress: how far along (0–1) and its number (correct
/// answers, or the distance to the target).
typedef LaneProgress = ({double fraction, int value});

/// A duel being played (plan v3.7, Phase 7 commit 5): the player's run
/// against the opponent's lane, replayed at its original pace.
///
/// Basics and Advanced play on the game's own [SessionController] (the 30 s
/// timer, timeouts, the correction pause, the keypad and keyboard) with the
/// duel's questions; Get the count plays three [CountController.round]s of
/// 30 s. The run is saved on the device after every answer and round
/// ([DuelRunQueue.saveProgress]) and sent when it ends — or when the player
/// quits: unanswered questions count (plan v3.7).
class DuelController extends ChangeNotifier {
  DuelController({
    required this.offer,
    required this.queue,
    required SessionController Function(DuelConfig config) quizController,
    this.clock = DateTime.now,
    Timer Function(Duration period, void Function(Timer) tick)? ticker,
    this.countTimer = Timer.new,
  }) : _ticker = ticker ?? Timer.periodic {
    if (offer.config.mode.isQuiz) {
      _quiz = quizController(offer.config)..addListener(_onQuizChanged);
      families = offer.config.questionFamilies();
    } else {
      families = const [];
      _rounds = offer.config.rounds();
    }
  }

  final DuelOffer offer;
  final DuelRunQueue queue;
  final DateTime Function() clock;
  final Timer Function(Duration period, void Function(Timer) tick) _ticker;

  /// The rounds' one-second timer (tests inject theirs).
  final Timer Function(Duration duration, void Function() callback) countTimer;

  /// The correction pause after a wrong answer: the opponent's lane pauses
  /// as long, so both lanes keep the same clock.
  static const correctionPauseMs = 1000;

  SessionController? _quiz;
  SessionController? get quiz => _quiz;

  List<(CountPuzzle, List<CountStep>)> _rounds = const [];
  final _playedRounds = <CountRoundRun>[];
  CountController? _round;

  /// The Get the count round being played.
  CountController? get round => _round;
  int get roundIndex => _playedRounds.length;

  DuelPhase _phase = DuelPhase.playing;
  DuelPhase get phase => _phase;

  DateTime? _startedAt;
  Timer? _tick;
  int _savedAnswers = 0;

  DuelVerdict? _verdict;

  /// The server's verdict; `null` while sending or when it stays pending.
  DuelVerdict? get verdict => _verdict;

  /// Refused by the server (`DuelRunProblem` or another reason).
  String? _refusal;
  String? get refusal => _refusal;

  /// The run as played (sent with what is missing filled in).
  DuelRun? _run;

  /// The player's score and lane, computed here from the run — what the
  /// result shows at once, and while the run waits to be sent.
  DuelRunValid? _local;
  DuelRunValid? get local => _local;

  /// Played but not yet decided by the server (offline, asleep).
  bool get pending =>
      _phase == DuelPhase.done && _verdict == null && _refusal == null;

  /// Each question's pattern family (`null`: a standard question), for
  /// the result's Method — the pattern's own strategy, as in games.
  late final List<PatternFamily?> families;

  /// The quiz's answers, for the result's mistakes.
  List<AnswerResult> get outcomes => _quiz?.state.outcomes ?? const [];

  /// The rounds' controllers as played, for the result's corrections.
  final _roundControllers = <CountController>[];
  List<CountController> get playedRounds =>
      List.unmodifiable(_roundControllers);

  void start() {
    _startedAt = clock();
    _tick = _ticker(const Duration(milliseconds: 200), (_) {
      if (_phase == DuelPhase.playing) notifyListeners();
    });
    if (_quiz case final quiz?) {
      quiz.start();
    } else {
      _startRound();
    }
    notifyListeners();
  }

  /// Milliseconds since the duel (or the current round) started.
  int get elapsedMs {
    if (_round case final round?) return round.roundElapsedMs;
    final started = _startedAt;
    return started == null ? 0 : clock().difference(started).inMilliseconds;
  }

  // ---- Question modes -------------------------------------------------------

  void _onQuizChanged() {
    final quiz = _quiz!;
    final outcomes = quiz.state.outcomes;
    if (outcomes.length != _savedAnswers) {
      _savedAnswers = outcomes.length;
      queue.saveProgress(offer, _quizRun()).ignore();
    }
    final status = quiz.state.status;
    if (_phase == DuelPhase.playing &&
        (status == SessionStatus.finished ||
            status == SessionStatus.interrupted)) {
      _finish();
    }
    notifyListeners();
  }

  QuizRun _quizRun() => QuizRun([
    for (final o in outcomes)
      DuelAnswer(value: o.submittedValue, elapsedMs: o.elapsedMs),
  ]);

  // ---- Get the count --------------------------------------------------------

  void _startRound() {
    final (puzzle, solution) = _rounds[_playedRounds.length];
    final round = CountController.round(
      puzzle: puzzle,
      solution: solution,
      roundSeconds: countDuelRoundSeconds,
      clock: clock,
      createTimer: countTimer,
    )..addListener(_onRoundChanged);
    _round = round;
    _roundControllers.add(round);
    round.start();
  }

  void _onRoundChanged() {
    final round = _round;
    if (round == null || !round.ended || _phase != DuelPhase.playing) {
      notifyListeners();
      return;
    }
    _endRound(round);
  }

  void _endRound(CountController round) {
    round.removeListener(_onRoundChanged);
    _playedRounds.add(CountRoundRun(round.improvements));
    queue.saveProgress(offer, CountRun(_playedRounds)).ignore();
    if (_playedRounds.length < countDuelRounds) {
      _startRound();
      notifyListeners();
    } else {
      _round = null;
      _finish();
    }
  }

  // ---- Lanes ----------------------------------------------------------------

  /// The player's lane now.
  LaneProgress get mine {
    if (_quiz case final quiz?) {
      final outcomes = quiz.state.outcomes;
      return (
        fraction: outcomes.length / duelQuestionCount,
        value: outcomes.where((o) => o.isCorrect).length,
      );
    }
    final round = _round ?? _roundControllers.lastOrNull;
    if (round == null) return (fraction: 0, value: 0);
    return _closeness(baseCountDistance(round.puzzle), round.bestDistance);
  }

  /// The opponent's lane now, at their original pace; `null` when there is
  /// none (a challenge the player opens plays first).
  LaneProgress? get theirs {
    final lane = offer.lane;
    if (lane == null) return null;
    final now = elapsedMs;
    switch (lane) {
      case QuizLane(:final answers):
        var at = 0;
        var answered = 0;
        var correct = 0;
        for (final a in answers) {
          at += a.elapsedMs;
          if (at > now) break;
          answered++;
          if (a.correct) correct++;
          if (!a.correct) at += correctionPauseMs;
        }
        return (fraction: answered / duelQuestionCount, value: correct);
      case CountLane(:final rounds):
        final index = roundIndex.clamp(0, rounds.length - 1);
        final r = rounds[index];
        return _closeness(r.baseDistance, r.distanceAt(now));
    }
  }

  static LaneProgress _closeness(int base, int distance) => (
    fraction: base == 0 ? 1 : (1 - distance / base).clamp(0, 1).toDouble(),
    value: distance,
  );

  // ---- The end --------------------------------------------------------------

  /// ✕, confirmed: the run as it stands is sent; what is missing counts as
  /// unanswered (plan v3.7: quitting counts).
  void quit() {
    if (_phase != DuelPhase.playing) return;
    if (_quiz case final quiz?) {
      quiz.removeListener(_onQuizChanged);
      quiz.abandon();
      _finish();
    } else if (_round case final round?) {
      round.removeListener(_onRoundChanged);
      _playedRounds.add(CountRoundRun(round.improvements));
      _round = null;
      _finish();
    }
  }

  void _finish() {
    if (_phase != DuelPhase.playing) return;
    _tick?.cancel();
    final played = _quiz != null ? _quizRun() : CountRun(_playedRounds);
    _run = played;
    final toSend = switch (played) {
      final QuizRun q => q.completedWithTimeouts(),
      final CountRun c => c.completedWithEmptyRounds(),
    };
    final local = validateDuelRun(offer.config, toSend);
    _local = local is DuelRunValid ? local : null;
    _phase = DuelPhase.sending;
    notifyListeners();
    _send(played);
  }

  Future<void> _send(DuelRun run) async {
    try {
      _verdict = await queue.finish(offer, run);
    } on DuelRefused catch (e) {
      _refusal = e.reason;
    } on Exception catch (_) {
      // Kept in the queue: sent by a later flush.
    }
    _phase = DuelPhase.done;
    _notifyIfAlive();
  }

  /// Sends the run again (the result screen's retry while pending).
  Future<void> retry() async {
    final run = _run;
    if (run == null || !pending) return;
    _phase = DuelPhase.sending;
    notifyListeners();
    await _send(run);
  }

  /// 1 a win, 0.5 a draw, 0 a loss: the server's when known, else this
  /// device's own reckoning; `null` when there is nothing to race (a
  /// challenger waiting for their friend).
  double? get result {
    if (_verdict case final v?) return v.waiting ? null : v.result;
    final mine = _local?.score;
    final theirs = offer.lane?.score;
    if (mine == null || theirs == null) return null;
    return duelResult(mine, theirs);
  }

  bool _disposed = false;

  void _notifyIfAlive() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _tick?.cancel();
    _quiz?.removeListener(_onQuizChanged);
    _quiz?.dispose();
    for (final round in _roundControllers) {
      round.dispose();
    }
    super.dispose();
  }
}
