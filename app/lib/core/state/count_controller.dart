import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:math_core/challenges/challenge_stats.dart';
import 'package:math_core/challenges/count.dart';
import 'package:math_core/duel/duel_run.dart';
import 'package:math_core/duel/duel_validation.dart';

/// One round of Get the count (Redesign phase commit 8): 45 seconds, tap a
/// tile, an operator, another tile; undo, reset. Ends when a tile equals
/// the target, or when time runs out. Timers are injected (tests never
/// wait); the round is recorded in the device's stats when it ends.
///
/// A duel's round ([CountController.round], Phase 7): a given puzzle, 30 s,
/// no solo stats, and every [improvements] of the closest value kept with
/// the operations that made it — the run the server replays.
class CountController extends ChangeNotifier {
  factory CountController({
    required int seed,
    required ChallengeStatsStore statsStore,
    DateTime Function() clock = DateTime.now,
    Timer Function(Duration duration, void Function() callback) createTimer =
        Timer.new,
  }) {
    final (puzzle, solution) = generateCountPuzzleWithSolution(seed);
    return CountController.round(
      puzzle: puzzle,
      solution: solution,
      statsStore: statsStore,
      clock: clock,
      createTimer: createTimer,
    );
  }

  CountController.round({
    required this.puzzle,
    required List<CountStep> solution,
    this.statsStore,
    this.roundSeconds = countRoundSeconds,
    this.clock = DateTime.now,
    this.createTimer = Timer.new,
  }) : solution = List.unmodifiable(solution),
       _board = CountBoard.start(puzzle),
       _remaining = roundSeconds,
       _bestDistance = baseCountDistance(puzzle);

  /// `null`: a duel's round, kept out of the solo stats.
  final ChallengeStatsStore? statsStore;
  final int roundSeconds;
  final DateTime Function() clock;
  final Timer Function(Duration duration, void Function() callback) createTimer;

  final CountPuzzle puzzle;

  /// The shortest solution (the correction), computed with the puzzle.
  final List<CountStep> solution;

  CountBoard _board;
  CountBoard get board => _board;

  int _bestDistance;

  /// The closest distance to the target reached so far (the six numbers'
  /// at the start).
  int get bestDistance => _bestDistance;

  final _improvements = <CountImprovement>[];

  /// Every time the closest value improved: when, the value, and how it
  /// was made from the six numbers.
  List<CountImprovement> get improvements => List.unmodifiable(_improvements);

  /// Milliseconds since [start], at most the round's length.
  int get roundElapsedMs {
    final started = _startedAt;
    if (started == null) return 0;
    final ms = clock().difference(started).inMilliseconds;
    return ms > roundSeconds * 1000 ? roundSeconds * 1000 : ms;
  }

  int? _first;

  /// The first tile picked (its id), waiting for an operator and a second.
  int? get first => _first;

  CountOperator? _operator;
  CountOperator? get operator => _operator;

  int _remaining;
  int get remainingSeconds => _remaining;

  bool _ended = false;
  bool get ended => _ended;
  bool get solved => _board.solved;

  DateTime? _startedAt;
  int? _elapsedMs;

  /// From the start to the solving move; `null` unless solved.
  int? get elapsedMs => _elapsedMs;

  Timer? _tick;
  Future<void>? _pendingStats;
  Future<void> get pendingStats => _pendingStats ?? Future<void>.value();

  void start() {
    _startedAt = clock();
    _scheduleTick();
    notifyListeners();
  }

  void _scheduleTick() {
    _tick = createTimer(const Duration(seconds: 1), () {
      if (_ended) return;
      _remaining--;
      if (_remaining <= 0) {
        _end();
      } else {
        _scheduleTick();
      }
      notifyListeners();
    });
  }

  void tapTile(int id) {
    if (_ended) return;
    final tile = _board.tiles.where((t) => t.id == id).firstOrNull;
    if (tile == null || tile.used) return;
    final first = _first;
    final op = _operator;
    if (first == null || op == null) {
      // Pick, change or drop the first tile.
      _first = first == id ? null : id;
      _operator = null;
    } else if (first != id) {
      final next = _board.combine(first, op, id);
      if (next != null) {
        _board = next;
        _first = null;
        _operator = null;
        // The new tile takes the next id: the board's largest.
        final made = next.tiles.reduce((a, b) => a.id > b.id ? a : b);
        final distance = (made.value - puzzle.target).abs();
        if (distance < _bestDistance) {
          _bestDistance = distance;
          // Strictly later than the last (the server's replay requires it):
          // two moves within the same millisecond still count.
          final last = _improvements.lastOrNull?.atMs ?? -1;
          final at = roundElapsedMs;
          _improvements.add(
            CountImprovement(
              atMs: at > last ? at : last + 1,
              value: made.value,
              steps: made.steps,
            ),
          );
        }
        if (_board.solved) {
          _elapsedMs = clock().difference(_startedAt!).inMilliseconds;
          _end();
        }
      } else {
        // Not allowed (negative, inexact…): the operator is dropped, the
        // first tile stays picked.
        _operator = null;
      }
    }
    notifyListeners();
  }

  void tapOperator(CountOperator op) {
    if (_ended || _first == null) return;
    _operator = _operator == op ? null : op;
    notifyListeners();
  }

  void undo() {
    if (_ended) return;
    _board = _board.undo();
    _first = null;
    _operator = null;
    notifyListeners();
  }

  void reset() {
    if (_ended) return;
    _board = _board.reset();
    _first = null;
    _operator = null;
    notifyListeners();
  }

  void _end() {
    if (_ended) return;
    _ended = true;
    _tick?.cancel();
    _pendingStats = _record();
  }

  Future<void> _record() async {
    final statsStore = this.statsStore;
    if (statsStore == null) return;
    try {
      final before = await statsStore.load(Challenge.getTheCount);
      await statsStore.save(
        Challenge.getTheCount,
        before.record(
          solved: solved,
          elapsedMs: _elapsedMs ?? roundSeconds * 1000,
        ),
      );
    } on Exception catch (_) {
      // A failed write costs one round of stats, never the round.
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }
}
