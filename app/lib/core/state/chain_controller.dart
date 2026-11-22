import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:math_core/challenges/challenge_stats.dart';
import 'package:math_core/challenges/chain.dart';

/// Where a chain round is (Redesign phase commit 7).
enum ChainPhase {
  /// Screen [ChainController.screen] is up: 0 is the starting number, then
  /// one operation per screen.
  showing,

  /// The short blank between two screens: two identical steps stay two.
  blank,

  /// The keypad: the player types the result.
  answering,

  /// Answered (or quit after the last screen): the correction.
  done,
}

/// Plays one chain: each screen for [secondsPerScreen], a [blank] between
/// screens, then the keypad. Timers are injected (tests never wait).
/// Records the round in the device's stats once answered.
class ChainController extends ChangeNotifier {
  ChainController({
    required this.chain,
    required this.secondsPerScreen,
    required this.statsStore,
    this.blank = defaultBlank,
    this.clock = DateTime.now,
    this.createTimer = Timer.new,
  }) {
    if (!chainSecondsChoices.contains(secondsPerScreen)) {
      throw ArgumentError.value(
        secondsPerScreen,
        'secondsPerScreen',
        'must be one of $chainSecondsChoices.',
      );
    }
  }

  static const defaultBlank = Duration(milliseconds: 250);

  final Chain chain;
  final int secondsPerScreen;
  final ChallengeStatsStore statsStore;
  final Duration blank;
  final DateTime Function() clock;
  final Timer Function(Duration duration, void Function() callback) createTimer;

  ChainPhase _phase = ChainPhase.showing;
  ChainPhase get phase => _phase;

  int _screen = 0;

  /// 0: the starting number; i ≥ 1: step i.
  int get screen => _screen;

  /// The number of screens after the start (the setup's operations).
  int get operations => chain.steps.length;

  int? _given;

  /// What the player typed; `null` before answering.
  int? get given => _given;

  bool get solved => _given == chain.answer;

  DateTime? _answeringSince;
  int? _elapsedMs;

  /// From the keypad's appearance to the answer.
  int? get elapsedMs => _elapsedMs;

  Timer? _timer;
  Future<void>? _pendingStats;

  /// Resolves once the round is in the stats (tests).
  Future<void> get pendingStats => _pendingStats ?? Future<void>.value();

  void start() {
    _phase = ChainPhase.showing;
    _screen = 0;
    _schedule(Duration(seconds: secondsPerScreen), _endScreen);
    notifyListeners();
  }

  void _schedule(Duration after, void Function() then) {
    _timer?.cancel();
    _timer = createTimer(after, then);
  }

  void _endScreen() {
    if (_phase != ChainPhase.showing) return;
    if (_screen >= operations) {
      _phase = ChainPhase.answering;
      _answeringSince = clock();
    } else {
      _phase = ChainPhase.blank;
      _schedule(blank, _nextScreen);
    }
    notifyListeners();
  }

  void _nextScreen() {
    if (_phase != ChainPhase.blank) return;
    _screen++;
    _phase = ChainPhase.showing;
    _schedule(Duration(seconds: secondsPerScreen), _endScreen);
    notifyListeners();
  }

  void submit(int value) {
    if (_phase != ChainPhase.answering) return;
    _given = value;
    _elapsedMs = clock().difference(_answeringSince!).inMilliseconds;
    _phase = ChainPhase.done;
    notifyListeners();
    _pendingStats = _record();
  }

  /// A failed read or write costs one round of stats, never the round.
  Future<void> _record() async {
    try {
      final before = await statsStore.load(Challenge.chainOperations);
      await statsStore.save(
        Challenge.chainOperations,
        before.record(solved: solved, elapsedMs: _elapsedMs!),
      );
    } on Exception catch (_) {
      // See above.
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
