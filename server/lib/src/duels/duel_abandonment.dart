import 'package:math_core/duel/duel_config.dart';

import '../supabase_gateway.dart';
import 'duel_json.dart';
import 'duel_runs.dart';

/// Duels started and left for 24 hours, recorded as losses (plan v3.8;
/// split out of `duel_endpoint.dart` at the 6a close-out, plan v4.0).
///
/// The production server sweeps outside the requests — at start, on a
/// timer, and soon after a duel request — and each such sweep **catches
/// up**: it keeps taking batches until the database lists no more (plan
/// v4.0: the free server sleeps, and wakes with a backlog). Tests sweep one
/// batch inside each request ([sweepOnce]), deterministically.
class DuelAbandonment {
  DuelAbandonment(this.gateway, this.runs, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final SupabaseGateway gateway;
  final DuelRuns runs;
  final DateTime Function() _clock;
  DateTime? _lastSweep;
  Future<void>? _sweeping;

  /// How many abandoned duels one batch records at most.
  static const batch = 3;

  /// The most batches one catch-up takes: 600 duels, then the next sweep
  /// goes on.
  static const maxBatches = 200;

  /// The shortest time between two sweeps outside requests.
  static const minSweepGap = Duration(minutes: 1);

  /// Starts a catch-up unless one ran in the last [minSweepGap] or is
  /// running; never awaited by a request, never failing. The first call —
  /// at server start — always runs.
  void sweepSoon() {
    final now = _clock();
    final last = _lastSweep;
    if (_sweeping != null ||
        (last != null && now.difference(last) < minSweepGap)) {
      return;
    }
    _lastSweep = now;
    _sweeping = catchUp()
        .catchError((Object e) {
          // ignore: avoid_print
          print('sweep: $e');
          return 0;
        })
        .whenComplete(() => _sweeping = null);
  }

  /// The sweep running now, if any (tests await it).
  Future<void>? get running => _sweeping;

  /// Records every duel abandoned for 24 hours, batch after batch, until a
  /// batch is not full — or records nothing (a duel that fails every time
  /// must not hold the loop) — or [maxBatches]. Returns how many it
  /// recorded.
  Future<int> catchUp() async {
    var total = 0;
    for (var i = 0; i < maxBatches; i++) {
      final (:listed, :recorded) = await sweepOnce();
      total += recorded;
      if (listed < batch || recorded == 0) break;
    }
    return total;
  }

  /// One batch of [batch] duels abandoned for 24 hours (`duel_abandoned`),
  /// each recorded as a loss from the progress the server received: the run
  /// completed with timeouts (empty rounds), replayed, applied with result 0
  /// — rated like any duel of its kind — and flagged `abandoned` (never in
  /// the pool). A progress that does not replay is still a loss (Phase 6a: a
  /// forfeited run, empty if nothing of it can be kept), and a challenge the
  /// friend opened is scored whatever its expiry. Never throws for one duel:
  /// its failure is logged and the others go on.
  Future<({int listed, int recorded})> sweepOnce() async {
    final List<Object?> abandoned;
    try {
      final listed = await gateway.rpc('duel_abandoned', {'p_limit': batch});
      abandoned = listed is List ? listed : const [];
    } on GatewayUnavailable {
      return (listed: 0, recorded: 0);
    }
    var recorded = 0;
    for (final entry in abandoned) {
      if (entry is! Map) continue;
      try {
        if (await _record('${entry['duelId']}', '${entry['player']}')) {
          recorded++;
        }
      } on Object catch (error) {
        // ignore: avoid_print
        print('abandoned duel ${entry['duelId']}: $error');
      }
    }
    return (listed: abandoned.length, recorded: recorded);
  }

  /// Whether the duel was recorded now (`false`: decided meanwhile, or the
  /// ratings kept moving).
  Future<bool> _record(String duelId, String player) async {
    for (var attempt = 0; attempt < DuelRuns.maxAttempts; attempt++) {
      final context = await gateway.rpc('duel_context', {
        'p_duel_id': duelId,
        'p_player_id': player,
      });
      if (context is! Map) return false;
      final duel = jsonMap(context['duel']);
      if (duel['state'] != 'awaitingSecond' || context['run'] is Map) {
        return false;
      }
      final config = DuelConfig.fromJson(duel['config']);
      final played = progressOf(duel, config.mode) ?? emptyRun(config.mode);
      final outcome = await runs.apply(
        duelId: duelId,
        player: player,
        role: 'second',
        context: context,
        config: config,
        run: completedRun(played),
        forcedResult: 0,
        extraFlags: const ['abandoned'],
      );
      if (outcome != 'stale') return outcome == 'applied';
    }
    return false;
  }
}
