import 'package:math_core/duel/duel_config.dart';
import 'package:math_core/duel/duel_mode.dart';
import 'package:math_core/duel/duel_run.dart';
import 'package:math_core/duel/duel_validation.dart';
import 'package:shelf/shelf.dart';

import '../http_app.dart';
import '../session_endpoint.dart' show refused;
import '../supabase_gateway.dart';
import 'duel_json.dart';
import 'duel_ratings.dart';

/// A player's runs of a duel — the final run and the progress sent during
/// play — replayed with math_core and applied (split out of
/// `duel_endpoint.dart` at the 6a close-out, plan v4.0).
class DuelRuns {
  DuelRuns(this.gateway);

  final SupabaseGateway gateway;

  /// How much more than the time since the duel was handed out a run may
  /// claim (`DuelRun.claimedMs`): clocks and rounding, not play.
  static const clockMargin = Duration(seconds: 5);

  /// Times the server re-reads and recomputes when a rating moved under it.
  static const maxAttempts = 3;

  /// `POST /v1/duels/progress {duelId, run}` (close-out commit 1): the run
  /// as it stands, after every answer or round — what an abandoned duel is
  /// recorded from, and what the final run must continue (Phase 6a). Parsed
  /// and stored in the server's own shape, replayed only with the run or
  /// the abandonment. 200 `{status: saved}`; 409 `notOpen` (not this
  /// player's open duel) or `progressMismatch` (it does not continue the
  /// progress already held: another device, or an older message arriving
  /// late — nothing changes).
  Future<Response> progress(
    AuthenticatedUser user,
    Map<String, Object?> body,
  ) async {
    final duelId = body['duelId'];
    final sent = body['run'];
    if (duelId is! String || sent is! Map) {
      return refused(400, 'badRequest', detail: 'duelId, run');
    }
    final context = await gateway.rpc('duel_context', {
      'p_duel_id': duelId,
      'p_player_id': user.id,
    });
    if (context is! Map) return refused(409, 'notOpen');
    final duel = jsonMap(context['duel']);
    if (duel['secondPlayer'] != user.id ||
        duel['state'] != 'awaitingSecond' ||
        context['run'] is Map) {
      return refused(409, 'notOpen');
    }
    final config = DuelConfig.fromJson(duel['config']);
    final DuelRun run;
    try {
      run = DuelRun.fromJson(sent, config.mode);
    } on FormatException catch (e) {
      return refused(400, 'badRequest', detail: e.message);
    }
    final held = progressOf(duel, config.mode);
    if (held != null && !run.continues(held)) {
      return refused(409, 'progressMismatch');
    }
    final outcome = await gateway.rpc('duel_save_progress', {
      'p_duel_id': duelId,
      'p_player_id': user.id,
      'p_payload': run.toJson(),
    });
    return outcome == 'saved'
        ? jsonResponse(200, {'status': 'saved'})
        : refused(409, 'notOpen');
  }

  /// `POST /v1/duels/run {duelId, run}`: the run decided and applied once
  /// (idempotent on the duel and player) — see `DuelEndpoint`.
  Future<Response> run(
    AuthenticatedUser user,
    Map<String, Object?> body,
  ) async {
    final duelId = body['duelId'];
    if (duelId is! String || duelId.isEmpty) {
      return refused(400, 'badRequest', detail: 'duelId');
    }
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final context = await gateway.rpc('duel_context', {
        'p_duel_id': duelId,
        'p_player_id': user.id,
      });
      if (context is! Map) return refused(404, 'unknownDuel');
      final duel = jsonMap(context['duel']);
      final String role;
      if (duel['secondPlayer'] == user.id) {
        role = 'second';
      } else if (duel['firstPlayer'] == user.id) {
        role = 'first';
      } else {
        return refused(409, 'notYourDuel');
      }
      // Decided already — a forfeit too (a run and its reason): the same
      // answer again.
      if (context['run'] is Map) {
        return decidedResponse(context, role: role, duplicate: true);
      }
      final turn = role == 'first' ? 'awaitingFirst' : 'awaitingSecond';
      if (context['rejection'] case final Map<Object?, Object?> rejection
          when role == 'first' || duel['state'] != turn) {
        return refused(409, '${rejection['reason']}');
      }
      // Not this player's turn (a friend before the challenger, a decided or
      // void duel): refused before the replay, which would record a refusal
      // for someone else's mistake.
      if (duel['state'] != turn) return refused(409, 'notOpen');
      // A challenge is played after it was opened (`/open` hands out its
      // questions and starts its clock).
      if (role == 'second' &&
          duel['kind'] == 'challenge' &&
          duel['openedAt'] == null) {
        return refused(409, 'notOpen');
      }

      final config = DuelConfig.fromJson(duel['config']);
      final DuelRun run;
      try {
        run = DuelRun.fromJson(body['run'], config.mode);
      } on FormatException catch (e) {
        return refused(400, 'badRequest', detail: e.message);
      }
      // Once the server holds progress, only its continuation is a run
      // (review M2): the duel stays open for the device that started it, or
      // is lost after 24 hours from that progress.
      if (role == 'second') {
        final held = progressOf(duel, config.mode);
        if (held != null && !run.continues(held)) {
          return refused(409, 'progressMismatch');
        }
      }
      final outcome = await apply(
        duelId: duelId,
        player: user.id,
        role: role,
        context: context,
        config: config,
        run: run,
      );
      switch (outcome) {
        case 'applied':
        case 'duplicate':
          // Read back what was stored: one shape for every answer.
          final stored = await gateway.rpc('duel_context', {
            'p_duel_id': duelId,
            'p_player_id': user.id,
          });
          if (stored is! Map) return refused(404, 'unknownDuel');
          return decidedResponse(
            stored,
            role: role,
            duplicate: outcome == 'duplicate',
          );
        case 'stale':
          continue;
        default:
          // notOpen, expired, or a challenger's own DuelRunProblem.
          return refused(409, outcome);
      }
    }
    return jsonResponse(503, {'error': 'busy'});
  }

  /// Decides [run] of [player] in [duelId] and applies it (one try):
  /// `apply_duel_run`'s outcome, or — for a challenger's own first run that
  /// does not replay — the `DuelRunProblem` name (recorded, the duel void).
  ///
  /// **The second player's run that does not replay is a loss** (plan v3.9,
  /// Phase 6a; review B5): the reason is recorded and a forfeited run is
  /// applied in its place ([_forfeit]). So is a run claiming more playing
  /// time than has passed since the duel was handed out
  /// (`DuelRunProblem.notElapsed`). [forcedResult]: an abandoned duel is a
  /// loss whatever its answers, and its clock is not checked (the server
  /// completed the run itself).
  Future<String> apply({
    required String duelId,
    required String player,
    required String role,
    required Map<Object?, Object?> context,
    required DuelConfig config,
    required DuelRun run,
    double? forcedResult,
    List<String> extraFlags = const [],
  }) async {
    // A forfeit recorded but not applied yet (a rating moved in between):
    // whatever is sent now, the duel stays lost.
    final recorded = context['rejection'];
    var verdict = role == 'second' && recorded is Map
        ? DuelRunInvalid(problemNamed(recorded['reason']), 'recorded before')
        : validateDuelRun(config, run);
    if (verdict is DuelRunValid && forcedResult == null) {
      final played = playedMs(context, role);
      if (played != null &&
          run.claimedMs > played + clockMargin.inMilliseconds) {
        verdict = DuelRunInvalid(
          DuelRunProblem.notElapsed,
          'claims ${run.claimedMs} ms, $played ms since the offer',
        );
      }
    }
    switch (verdict) {
      case DuelRunInvalid(:final problem, :final detail):
        if (role == 'second') {
          return _forfeit(
            duelId: duelId,
            player: player,
            context: context,
            config: config,
            sent: run,
            problem: problem,
            detail: detail,
            extraFlags: extraFlags,
          );
        }
        await gateway.rpc('record_duel_run_refused', {
          'p_duel_id': duelId,
          'p_player_id': player,
          'p_reason': problem.name,
          'p_detail': detail,
          'p_payload': run.toJson(),
        });
        return problem.name;
      case final DuelRunValid valid:
        return _store(
          duelId: duelId,
          player: player,
          role: role,
          context: context,
          config: config,
          run: run,
          verdict: valid,
          forcedResult: forcedResult,
          extraFlags: extraFlags,
        );
    }
  }

  /// The second player's run did not replay: the reason is recorded once
  /// (`record_duel_run_forfeit` — the duel is not void) and the duel is
  /// applied as a loss, "with what was received": the run as sent if
  /// completing it with timeouts makes it replay, else the progress the
  /// server holds, else nothing. Flagged `forfeited`: never in the pool,
  /// rated like any duel of its kind.
  Future<String> _forfeit({
    required String duelId,
    required String player,
    required Map<Object?, Object?> context,
    required DuelConfig config,
    required DuelRun sent,
    required DuelRunProblem problem,
    required String detail,
    required List<String> extraFlags,
  }) async {
    final duel = jsonMap(context['duel']);
    await gateway.rpc('record_duel_run_forfeit', {
      'p_duel_id': duelId,
      'p_player_id': player,
      'p_reason': problem.name,
      'p_detail': detail,
      'p_payload': sent.toJson(),
    });
    final held = progressOf(duel, config.mode);
    final candidates = [sent, ?held, emptyRun(config.mode)];
    for (final candidate in candidates) {
      final run = completedRun(candidate);
      final verdict = validateDuelRun(config, run);
      if (verdict is! DuelRunValid) continue;
      return _store(
        duelId: duelId,
        player: player,
        role: 'second',
        context: context,
        config: config,
        run: run,
        verdict: verdict,
        forcedResult: 0,
        extraFlags: [
          ...extraFlags,
          if (!extraFlags.contains('forfeited')) 'forfeited',
        ],
      );
    }
    throw StateError('an empty run did not replay for duel $duelId');
  }

  /// Applies a run that replays ([verdict]): the result against the first
  /// lane for the second player, the ratings when the duel is rated.
  Future<String> _store({
    required String duelId,
    required String player,
    required String role,
    required Map<Object?, Object?> context,
    required DuelConfig config,
    required DuelRun run,
    required DuelRunValid verdict,
    double? forcedResult,
    List<String> extraFlags = const [],
  }) async {
    final duel = jsonMap(context['duel']);
    final DuelRunValid(:score, :lane, :flags) = verdict;
    final start = startRating(config.mode, context['levels']);
    double? result;
    Map<String, Object?>? ratings;
    if (role == 'second') {
      final theirs = DuelLane.fromJson(duel['firstLane'], config.mode);
      result = forcedResult ?? duelResult(score, theirs.score);
      ratings = ratingUpdates(
        context,
        player,
        start,
        result,
        secondFlagged: flags.isNotEmpty,
      );
    }
    final rows = jsonRows(
      await gateway.rpc('apply_duel_run', {
        'p_duel_id': duelId,
        'p_player_id': player,
        'p_payload': run.toJson(),
        'p_lane': lane.toJson(),
        'p_score': score.toJson(),
        'p_flags': [for (final f in flags) f.name, ...extraFlags],
        'p_start_rating': {
          'rating': start.rating,
          'deviation': start.deviation,
          'volatility': start.volatility,
        },
        'p_result': result,
        'p_rated': ratings != null,
        'p_ratings': ratings,
      }),
    );
    final outcome = rows.isEmpty ? null : rows.first['outcome'];
    if (outcome is! String) throw StateError('apply_duel_run: $outcome');
    return outcome;
  }
}

/// The second player's progress the server holds, or `null` (none, or
/// stored before the server parsed it and unreadable).
DuelRun? progressOf(Map<Object?, Object?> duel, DuelMode mode) {
  final stored = duel['progress'];
  if (stored == null) return null;
  try {
    return DuelRun.fromJson(stored, mode);
  } on FormatException {
    return null;
  }
}

/// A run with no answer and no round.
DuelRun emptyRun(DuelMode mode) =>
    mode.isQuiz ? QuizRun(const []) : CountRun(const []);

/// [run] with what was not played filled in: timeouts, empty rounds.
DuelRun completedRun(DuelRun run) => switch (run) {
  final QuizRun q => q.completedWithTimeouts(),
  final CountRun c => c.completedWithEmptyRounds(),
};

/// A stored refusal's reason; an unknown name reads as `wrongShape`.
DuelRunProblem problemNamed(Object? name) => DuelRunProblem.values.firstWhere(
  (p) => p.name == name,
  orElse: () => DuelRunProblem.wrongShape,
);

/// How long ago, by the database's clock, [role]'s part of the duel was
/// handed out: a challenger's when the challenge was created, a friend's
/// when they opened it, a pool or practice duel's when matchmaking made it.
/// `null` when the context does not say (a database before Phase 6a).
int? playedMs(Map<Object?, Object?> context, String role) {
  final duel = jsonMap(context['duel']);
  final opened = role == 'second' && duel['kind'] == 'challenge';
  final now = DateTime.tryParse('${context['now']}');
  final started = DateTime.tryParse(
    '${opened ? duel['openedAt'] : duel['createdAt']}',
  );
  if (now == null || started == null) return null;
  return now.difference(started).inMilliseconds;
}
