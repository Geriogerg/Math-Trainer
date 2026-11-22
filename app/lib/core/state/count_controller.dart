import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:math_core/challenges/challenge_stats.dart';
import 'package:math_core/challenges/count.dart';

/// One round of Get the count (Redesign phase commit 8): 45 seconds, tap a
/// tile, an operator, another tile; undo, reset. Ends when a tile equals
/// the target, or when time runs out. Timers are injected (tests never
/// wait); the round is recorded in the device's stats when it ends.
class CountController extends ChangeNotifier {
  CountController({
    required int seed,
    required this.statsStore,
    this.clock = DateTime.now,
    this.createTimer = Timer.new,
  }) {
    final (puzzle, solution) = generateCountPuzzleWithSolution(seed);
    this.puzzle = puzzle;
    this.solution = List.unmodifiable(solution);
    _board = CountBoard.start(puzzle);
  }

  final ChallengeStatsStore statsStore;
  final DateTime Function() clock;
  final Timer Function(Duration duration, void Function() callback) createTimer;

  late final CountPuzzle puzzle;

  /// The shortest solution (the correction), computed with the puzzle.
  late final List<CountStep> solution;

  late CountBoard _board;
  CountBoard get board => _board;

  int? _first;

  /// The first tile picked (its id), waiting for an operator and a second.
  int? get first => _first;

  CountOperator? _operator;
  CountOperator? get operator => _operator;

  int _remaining = countRoundSeconds;
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
    try {
      final before = await statsStore.load(Challenge.getTheCount);
      await statsStore.save(
        Challenge.getTheCount,
        before.record(
          solved: solved,
          elapsedMs: _elapsedMs ?? countRoundSeconds * 1000,
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
