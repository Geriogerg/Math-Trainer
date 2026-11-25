import 'package:flutter/foundation.dart';

import 'package:math_core/duel/duel_client.dart';
import 'package:math_core/duel/duel_mode.dart';
import 'package:math_core/duel/duel_rating.dart';
import 'package:math_core/duel/duel_run_queue.dart';
import 'package:math_core/duel/online_overview.dart';
import 'package:math_core/leveling/level.dart';
import 'package:math_core/models/exercise_type.dart';

/// The Online tab's state (Phase 7 commit 6): the overview the server
/// holds, and the ratings to show — the server's, or the starting rating
/// from the player's own levels before their first duel of a mode
/// (provisional either way until 10 rated duels). Each [load] also sends
/// the runs still waiting on the device and wakes the server (`/health`),
/// so the first duel does not wait for it as long.
class OnlineController extends ChangeNotifier {
  OnlineController({
    required this.repository,
    required this.levels,
    this.client,
    this.queue,
  });

  final OnlineRepository repository;

  /// The player's levels on this device (for the starting ratings).
  final Future<Map<ExerciseType, Level>> Function() levels;
  final DuelClient? client;
  final DuelRunQueue? queue;

  OnlineOverview? _overview;
  OnlineOverview? get overview => _overview;

  Map<ExerciseType, Level> _levels = const {};

  bool _loading = false;
  bool get loading => _loading;

  bool _failed = false;
  bool get failed => _failed;

  bool _disposed = false;
  int _request = 0;

  /// Something waits for the player: the tab's badge.
  bool get needsAttention => _overview?.needsAttention ?? false;

  /// The rating shown for [mode] and whether it is provisional.
  ({double rating, bool provisional}) rating(DuelMode mode) {
    final held = _overview?.ratings[mode];
    return held == null
        ? (rating: startingDuelRating(mode, _levels), provisional: true)
        : (
            rating: held.rating,
            provisional: isProvisionalRating(held.ratedDuels),
          );
  }

  Future<void> load() async {
    final request = ++_request;
    _loading = true;
    _failed = false;
    _notify();
    // Background chores: never block the tab.
    queue?.flush().ignore();
    client?.support().ignore();
    try {
      final overview = await repository.overview();
      final levels = await this.levels();
      if (request != _request) return;
      _overview = overview;
      _levels = levels;
    } on Exception catch (_) {
      if (request != _request) return;
      _failed = true;
    }
    _loading = false;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
