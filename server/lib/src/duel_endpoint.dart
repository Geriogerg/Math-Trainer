import 'dart:convert';
import 'dart:math';

import 'package:math_core/duel/duel_config.dart';
import 'package:math_core/duel/duel_mode.dart';
import 'package:math_core/duel/duel_rating.dart';
import 'package:math_core/duel/duel_run.dart';
import 'package:math_core/duel/duel_validation.dart';
import 'package:math_core/duel/practice_lane.dart';
import 'package:math_core/leveling/level.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/persistence/uuid.dart';
import 'package:shelf/shelf.dart';

import 'http_app.dart';
import 'rate_limit.dart';
import 'rating/duel_rating_update.dart';
import 'rating/glicko2.dart';
import 'session_endpoint.dart' show refused;
import 'supabase_gateway.dart';

/// Largest accepted duel body: a Get the count run with many improvements
/// is a few KB.
const maxDuelBytes = 64 * 1024;

/// Most duels handed out to one player over a rolling 24 hours (plan v3.9,
/// Phase 6a): a duel takes a minute or more, and each one is a row.
const maxDuelsPerDay = 200;

/// The duel endpoints (plan v3.7, Phase 7). Online play needs a linked
/// account: a guest gets 403 `account_required`.
///
/// `POST /v1/duels/run` `{duelId, run}` — a player's run of a duel, replayed
/// with math_core (`validateDuelRun`) and applied once (idempotent on the
/// duel and player):
/// - 200 `{status: accepted, duplicate, role, …}`: for the second player,
///   the result (`result`: 1 / 0.5 / 0, both scores, `rated`, the rating
///   before and after); for a challenger, `waiting: true`;
/// - 400 / 404 / 409 `{status: refused, reason}`: malformed, no such duel,
///   not this player's, not their turn, expired, not a continuation of the
///   progress the server holds (`progressMismatch`), or — for a challenger's
///   own first run — the run failed its replay (a `DuelRunProblem`: the
///   duel is void): the app records it and never resends;
/// - **the second player's run that does not replay is a loss** (plan v3.9,
///   Phase 6a): the answer is the accepted shape, `result: 0`, the run
///   flagged `forfeited`. No request escapes a duel once it is handed out;
/// - 401, 403, 413, 503 (Supabase unavailable, or ratings kept moving): the
///   app retries later.
///
/// `POST /v1/duels` `{mode}` — **matchmaking** (commit 4): the caller's
/// unanswered duel of the mode opened within the hour if any, else the
/// pool's run whose owner's rating is closest (`duel_take_run`), else a
/// **practice** duel at the caller's rating against a simulated lane
/// (`practiceLane`). `{mode, rematchOf}`: another pool run of that duel's
/// opponent, the closest tier first; none → a challenge sent to them (after
/// a practice duel: a new search) — only for a finished duel of the same
/// mode (`notFinished`, `wrongMode`). `{mode, challenge: playerId}`: a
/// challenge at the mean of both ratings, the caller playing first — only
/// to a friend or an opponent of the last 30 days (`notAllowed`). Answers
/// an offer `{duelId, kind, config, lane, opponent}` (`lane` null for a
/// challenge the caller opens; `opponent` null for practice), or 409
/// `{status: refused, reason}`: `self`, `notLinked`, `exists`,
/// `notYourDuel`, `unknownDuel`.
///
/// `POST /v1/duels/open` `{duelId}` — the friend opens a challenge waiting
/// for them: the offer with the challenger's lane; 409 `notOpen` or
/// `expired` otherwise.
class DuelEndpoint {
  DuelEndpoint(
    this.gateway, {
    Random? seeds,
    String Function()? newId,
    this.limits,
    this.sweepInRequests = true,
    DateTime Function()? clock,
  }) : _seeds = seeds ?? Random.secure(),
       _newId = newId ?? generateUuidV4,
       _clock = clock ?? DateTime.now;

  /// Whether each duel request records the abandoned duels before it is
  /// handled (tests: deterministic). The production server does it on a
  /// timer and, at most once a minute, after a request — never inside one
  /// (Phase 6a, review m10: it slowed unrelated requests).
  final bool sweepInRequests;
  final DateTime Function() _clock;
  DateTime? _lastSweep;
  Future<void>? _sweeping;

  /// Starts a sweep unless one ran in the last [minSweepGap] or is running;
  /// never awaited by a request, never failing.
  void sweepSoon() {
    final now = _clock();
    final last = _lastSweep;
    if (_sweeping != null ||
        (last != null && now.difference(last) < minSweepGap)) {
      return;
    }
    _lastSweep = now;
    _sweeping = sweepAbandoned()
        .catchError((Object e) {
          // ignore: avoid_print
          print('sweep: $e');
        })
        .whenComplete(() => _sweeping = null);
  }

  /// The shortest time between two sweeps outside requests.
  static const minSweepGap = Duration(minutes: 1);

  final SupabaseGateway gateway;

  /// The per-player request limit (none in most tests).
  final RateLimits? limits;
  final Random _seeds;
  final String Function() _newId;

  List<Route> get routes => [
    (method: 'POST', path: '/v1/duels', handler: handleFind),
    (method: 'POST', path: '/v1/duels/open', handler: handleOpen),
    (method: 'POST', path: '/v1/duels/run', handler: handleRun),
    (method: 'POST', path: '/v1/duels/progress', handler: handleProgress),
  ];

  /// `POST /v1/duels/progress {duelId, run}` (close-out commit 1): the run
  /// as it stands, after every answer or round — what an abandoned duel is
  /// recorded from, and what the final run must continue (Phase 6a). Parsed
  /// and stored in the server's own shape, replayed only with the run or
  /// the abandonment. 200 `{status: saved}`; 409 `notOpen` (not this
  /// player's open duel) or `progressMismatch` (it does not continue the
  /// progress already held: another device, or an older message arriving
  /// late — nothing changes).
  Future<Response> handleProgress(Request request) =>
      _guarded(request, sweep: false, (user, body) async {
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
        final duel = _map(context['duel']);
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
        final held = _progress(duel, config.mode);
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
      });

  /// How much more than the time since the duel was handed out a run may
  /// claim (`DuelRun.claimedMs`): clocks and rounding, not play.
  static const clockMargin = Duration(seconds: 5);

  /// How many abandoned duels one request records at most.
  static const abandonedPerRequest = 3;

  /// Records the duels abandoned for 24 hours (plan v3.8, `duel_abandoned`)
  /// as losses, from the progress the server received: the run completed
  /// with timeouts (empty rounds), replayed, applied with result 0 — rated
  /// like any duel of its kind — and flagged `abandoned` (never in the
  /// pool). A progress that does not replay is still a loss (Phase 6a: a
  /// forfeited run, empty if nothing of it can be kept), and a challenge
  /// the friend opened is scored whatever its expiry. Runs on every duel
  /// request (the free server has no clock of its own); a failure here
  /// never fails the request.
  Future<void> sweepAbandoned() async {
    final List<Object?> abandoned;
    try {
      final listed = await gateway.rpc('duel_abandoned', {
        'p_limit': abandonedPerRequest,
      });
      abandoned = listed is List ? listed : const [];
    } on GatewayUnavailable {
      return;
    }
    for (final entry in abandoned) {
      if (entry is! Map) continue;
      try {
        await _recordAbandoned('${entry['duelId']}', '${entry['player']}');
      } on Object catch (error) {
        // ignore: avoid_print
        print('abandoned duel ${entry['duelId']}: $error');
      }
    }
  }

  Future<void> _recordAbandoned(String duelId, String player) async {
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final context = await gateway.rpc('duel_context', {
        'p_duel_id': duelId,
        'p_player_id': player,
      });
      if (context is! Map) return;
      final duel = _map(context['duel']);
      if (duel['state'] != 'awaitingSecond' || context['run'] is Map) return;
      final config = DuelConfig.fromJson(duel['config']);
      final played = _progress(duel, config.mode) ?? _emptyRun(config.mode);
      final outcome = await _applyRun(
        duelId: duelId,
        player: player,
        role: 'second',
        context: context,
        config: config,
        run: _completed(played),
        forcedResult: 0,
        extraFlags: const ['abandoned'],
      );
      if (outcome != 'stale') return;
    }
  }

  /// Decides [run] of [player] in [duelId] and applies it (one try):
  /// `apply_duel_run`'s outcome, or — for a challenger's own first run that
  /// does not replay — the `DuelRunProblem` name (recorded, the duel void).
  ///
  /// **The second player's run that does not replay is a loss** (plan v3.9,
  /// Phase 6a; review B5): the reason is recorded and a forfeited run is
  /// applied in its place (`_forfeit`). So is a run claiming more playing
  /// time than has passed since the duel was handed out
  /// (`DuelRunProblem.notElapsed`). [forcedResult]: an abandoned duel is a
  /// loss whatever its answers, and its clock is not checked (the server
  /// completed the run itself).
  Future<String> _applyRun({
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
        ? DuelRunInvalid(_problem(recorded['reason']), 'recorded before')
        : validateDuelRun(config, run);
    if (verdict is DuelRunValid && forcedResult == null) {
      final played = _playedMs(context, role);
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
    final duel = _map(context['duel']);
    await gateway.rpc('record_duel_run_forfeit', {
      'p_duel_id': duelId,
      'p_player_id': player,
      'p_reason': problem.name,
      'p_detail': detail,
      'p_payload': sent.toJson(),
    });
    final held = _progress(duel, config.mode);
    final candidates = [sent, ?held, _emptyRun(config.mode)];
    for (final candidate in candidates) {
      final run = _completed(candidate);
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
    final duel = _map(context['duel']);
    final DuelRunValid(:score, :lane, :flags) = verdict;
    final start = _startRating(config.mode, context['levels']);
    double? result;
    Map<String, Object?>? ratings;
    if (role == 'second') {
      final theirs = DuelLane.fromJson(duel['firstLane'], config.mode);
      result = forcedResult ?? duelResult(score, theirs.score);
      ratings = _ratingUpdates(
        context,
        player,
        start,
        result,
        secondFlagged: flags.isNotEmpty,
      );
    }
    final rows = _rows(
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

  /// A duel's seed: positive and under 2³¹, the same on every platform
  /// that will draw from it.
  int _seed() => _seeds.nextInt(1 << 31);

  Future<Response> handleFind(Request request) =>
      _guarded(request, (user, body) async {
        final DuelMode mode;
        try {
          mode = DuelMode.parse(body['mode']);
        } on FormatException catch (e) {
          return refused(400, 'badRequest', detail: e.message);
        }
        final me = await _player(user.id, mode);
        if (me == null) return refused(409, 'notLinked');
        // The owner suspended the account: no new duel (a hidden player
        // still plays, against practice opponents — `duel_take_run`).
        if (me.banned) return jsonResponse(403, {'error': 'account_suspended'});
        // The daily cap on new duels; the one still open is handed back.
        if (me.duelsToday >= maxDuelsPerDay) {
          final open = await gateway.rpc('duel_open_offer', {
            'p_player_id': user.id,
            'p_mode': mode.name,
          });
          if (open is Map) return jsonResponse(200, open);
          return tooManyRequests(
            'daily_limit',
            retryAfter: const Duration(hours: 1),
          );
        }
        final rating = me.rating;

        if (body['challenge'] case final String target) {
          return _challenge(user.id, target, mode, rating);
        }
        if (body['rematchOf'] case final String previous) {
          final context = await gateway.rpc('duel_context', {
            'p_duel_id': previous,
            'p_player_id': user.id,
          });
          if (context is! Map) return refused(404, 'unknownDuel');
          final duel = _map(context['duel']);
          final first = duel['firstPlayer'];
          final second = duel['secondPlayer'];
          final String? opponent;
          if (second == user.id) {
            opponent = first as String?;
          } else if (first == user.id) {
            opponent = second as String?;
          } else {
            return refused(409, 'notYourDuel');
          }
          // Only a finished duel of this mode is played again (Phase 6a):
          // `rematchOf` is not a way to aim at any player one once met.
          if (duel['state'] != 'done') return refused(409, 'notFinished');
          if (duel['mode'] != mode.name) return refused(409, 'wrongMode');
          if (opponent != null) {
            final offer = await gateway.rpc('duel_take_run', {
              'p_player_id': user.id,
              'p_mode': mode.name,
              'p_rating': rating,
              'p_opponent': opponent,
              'p_difficulty': _difficultyFor(mode, rating),
              'p_duel_id': _newId(),
            });
            if (offer is Map) return jsonResponse(200, offer);
            return _challenge(user.id, opponent, mode, rating);
          }
          // After a practice duel: a new search.
        }

        final open = await gateway.rpc('duel_open_offer', {
          'p_player_id': user.id,
          'p_mode': mode.name,
        });
        if (open is Map) return jsonResponse(200, open);
        final pooled = await gateway.rpc('duel_take_run', {
          'p_player_id': user.id,
          'p_mode': mode.name,
          'p_rating': rating,
          'p_opponent': null,
          'p_difficulty': null,
          'p_duel_id': _newId(),
        });
        if (pooled is Map) return jsonResponse(200, pooled);

        final config = DuelConfig.forRating(
          mode: mode,
          seed: _seed(),
          rating: ratingPoints(rating),
        );
        final lane = practiceLane(config).toJson();
        final duelId = _newId();
        await gateway.rpc('duel_insert', {
          'p_duel_id': duelId,
          'p_mode': mode.name,
          'p_kind': 'practice',
          'p_config': config.toJson(),
          'p_first_player': null,
          'p_second_player': user.id,
          'p_first_lane': lane,
          'p_expires_at': null,
        });
        return jsonResponse(200, {
          'duelId': duelId,
          'kind': 'practice',
          'config': config.toJson(),
          'lane': lane,
          'opponent': null,
        });
      });

  Future<Response> handleOpen(Request request) => _guarded(request, (
    user,
    body,
  ) async {
    final duelId = body['duelId'];
    if (duelId is! String) return refused(400, 'badRequest', detail: 'duelId');
    final context = await gateway.rpc('duel_context', {
      'p_duel_id': duelId,
      'p_player_id': user.id,
    });
    if (context is! Map) return refused(404, 'unknownDuel');
    final duel = _map(context['duel']);
    if (duel['secondPlayer'] != user.id) return refused(409, 'notYourDuel');
    if (duel['state'] != 'awaitingSecond' || context['run'] is Map) {
      return refused(409, 'notOpen');
    }
    final expires = DateTime.tryParse('${duel['expiresAt']}');
    if (expires != null && DateTime.now().toUtc().isAfter(expires)) {
      return refused(409, 'expired');
    }
    // A challenge's 24 hours start when the friend opens it.
    await gateway.rpc('duel_mark_opened', {
      'p_duel_id': duelId,
      'p_player_id': user.id,
    });
    final first = duel['firstPlayer'];
    final theirs = _map(context['ratings'])[first];
    return jsonResponse(200, {
      'duelId': duelId,
      'kind': duel['kind'],
      'config': duel['config'],
      'lane': duel['firstLane'],
      'opponent': first == null
          ? null
          : {
              'id': first,
              'name': duel['opponentName'],
              'rating': theirs is Map ? theirs['rating'] : null,
              'ratedDuels': theirs is Map ? theirs['ratedDuels'] : null,
            },
    });
  });

  /// A challenge from [me] to [target] at the mean of both ratings; the
  /// challenger plays first, so the offer has no lane.
  Future<Response> _challenge(
    String me,
    String target,
    DuelMode mode,
    double myRating,
  ) async {
    if (target == me) return refused(409, 'self');
    final them = await _player(target, mode);
    if (them == null) return refused(409, 'notLinked');
    final config = DuelConfig.forRating(
      mode: mode,
      seed: _seed(),
      rating: ratingPoints((myRating + them.rating) / 2),
    );
    final duelId = _newId();
    final outcome = await gateway.rpc('duel_create_challenge', {
      'p_duel_id': duelId,
      'p_mode': mode.name,
      'p_config': config.toJson(),
      'p_challenger': me,
      'p_target': target,
    });
    if (outcome != 'created') return refused(409, '$outcome');
    return jsonResponse(200, {
      'duelId': duelId,
      'kind': 'challenge',
      'config': config.toJson(),
      'lane': null,
      'opponent': {
        'id': target,
        'name': them.name,
        'rating': them.rating,
        'ratedDuels': them.ratedDuels,
      },
    });
  }

  /// A linked player's rating in [mode] (their row, or the start from their
  /// levels); `null` for a guest or nobody.
  Future<
    ({
      double rating,
      int ratedDuels,
      String? name,
      int duelsToday,
      bool banned,
    })?
  >
  _player(String id, DuelMode mode) async {
    final json = await gateway.rpc('duel_player', {
      'p_player_id': id,
      'p_mode': mode.name,
    });
    if (json is! Map || json['linked'] != true) return null;
    final row = json['rating'];
    return (
      rating: row is Map
          ? (row['rating'] as num).toDouble()
          : _startRating(mode, json['levels']).rating,
      ratedDuels: row is Map ? row['ratedDuels'] as int : 0,
      name: json['name'] as String?,
      duelsToday: json['duelsToday'] as int? ?? 0,
      banned: json['moderation'] == 'banned',
    );
  }

  /// Times the server re-reads and recomputes when a rating moved under it.
  static const maxAttempts = 3;

  Future<Response> handleRun(Request request) =>
      _guarded(request, (user, body) async {
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
          final duel = _map(context['duel']);
          final String role;
          if (duel['secondPlayer'] == user.id) {
            role = 'second';
          } else if (duel['firstPlayer'] == user.id) {
            role = 'first';
          } else {
            return refused(409, 'notYourDuel');
          }
          // Decided already — a forfeit too (a run and its reason): the
          // same answer again.
          if (context['run'] is Map) {
            return _decided(context, role: role, duplicate: true);
          }
          final turn = role == 'first' ? 'awaitingFirst' : 'awaitingSecond';
          if (context['rejection'] case final Map<Object?, Object?> rejection
              when role == 'first' || duel['state'] != turn) {
            return refused(409, '${rejection['reason']}');
          }
          // Not this player's turn (a friend before the challenger, a decided
          // or void duel): refused before the replay, which would record a
          // refusal for someone else's mistake.
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
          // (review M2): the duel stays open for the device that started it,
          // or is lost after 24 hours from that progress.
          if (role == 'second') {
            final held = _progress(duel, config.mode);
            if (held != null && !run.continues(held)) {
              return refused(409, 'progressMismatch');
            }
          }
          final outcome = await _applyRun(
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
              return _decided(
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
      });

  /// Authentication, linked account, body size and JSON object; then
  /// [handle]. Supabase failing anywhere is a 503 (logged).
  Future<Response> _guarded(
    Request request,
    Future<Response> Function(AuthenticatedUser user, Map<String, Object?> body)
    handle, {
    bool sweep = true,
  }) async {
    final path = '/${request.url.path}';
    try {
      final user = await bearerUser(gateway, request);
      if (user == null) return jsonResponse(401, {'error': 'unauthorized'});
      // Plan v3.7: online play needs a linked account — no guests.
      if (user.isAnonymous) {
        return jsonResponse(403, {'error': 'account_required'});
      }
      final limited = limits?.checkPlayer(user.id);
      if (limited != null) return limited;
      final text = await readBodyWithin(request, maxDuelBytes);
      if (text == null) return jsonResponse(413, {'error': 'too_large'});
      final Object? body;
      try {
        body = text.isEmpty ? const <String, Object?>{} : jsonDecode(text);
      } on FormatException {
        return refused(400, 'badRequest', detail: 'not JSON');
      }
      if (body is! Map) return refused(400, 'badRequest', detail: 'body');
      if (sweep && sweepInRequests) await sweepAbandoned();
      final response = await handle(user, body.cast<String, Object?>());
      // After the answer is ready: the sweep never delays a request.
      if (!sweepInRequests) sweepSoon();
      return response;
    } on GatewayUnavailable catch (e) {
      // ignore: avoid_print
      print('503 on POST $path: ${e.detail}');
      return jsonResponse(503, {'error': 'unavailable'});
    } on GatewayRejected catch (e) {
      // ignore: avoid_print
      print('400 on POST $path: ${e.detail}');
      return refused(400, 'badRequest', detail: 'refused by the database');
    }
  }
}

/// The rating rows `apply_duel_run` writes for a rated duel — both
/// players' new Glicko-2 ratings with the versions they were computed from
/// — or `null` when the duel is not rated:
/// - practice, never;
/// - a duel reached through a **chosen opponent** (a challenge, a rematch:
///   `chosen`), only if no other chosen duel between the pair was rated in
///   this mode in the last 24 hours (plan v3.9; `pairRatedToday`);
/// - **a flagged run earns nothing** (plan v3.9, "a flagged run's duel is
///   recorded unrated"): the duel is unrated unless the flagged run's
///   player lost it — a loss stands, or getting flagged would be a way out
///   of one. [secondFlagged]: this run's timing flags; `firstFlags`: the
///   first run's, unless the owner reviewed it ok.
/// The second player ([me]) without a rating yet starts at [start]
/// (`apply_duel_run` creates it at version 0).
Map<String, Object?>? _ratingUpdates(
  Map<Object?, Object?> context,
  String me,
  Glicko2Rating start,
  double result, {
  required bool secondFlagged,
}) {
  final duel = _map(context['duel']);
  final chosen = duel['chosen'] == true || duel['kind'] == 'challenge';
  final rated = switch (duel['kind']) {
    'pool' || 'challenge' => !(chosen && context['pairRatedToday'] == true),
    _ => false,
  };
  if (!rated) return null;
  if (secondFlagged && result > 0) return null;
  if (_reviewFlags(context['firstFlags']).isNotEmpty && result < 1) return null;
  final rows = _map(context['ratings']);
  final first = duel['firstPlayer'];
  final firstRow = rows[first];
  // A run's owner has a rating since that run was accepted; none would be
  // a broken invariant — the duel then stays unrated rather than guessed.
  if (firstRow is! Map || first is! String) return null;
  final secondRow = rows[me];
  final before = (
    first: _rating(firstRow),
    second: secondRow is Map ? _rating(secondRow) : start,
  );
  final after = rateDuel(
    first: before.first,
    second: before.second,
    secondScore: result,
  );
  Map<String, Object?> row(Glicko2Rating r, Object? version) => {
    'rating': r.rating,
    'deviation': r.deviation,
    'volatility': r.volatility,
    'expectedVersion': version ?? 0,
  };
  return {
    first: row(after.first, firstRow['version']),
    me: row(after.second, secondRow is Map ? secondRow['version'] : 0),
  };
}

Glicko2Rating _rating(Map<Object?, Object?> row) => Glicko2Rating(
  rating: (row['rating'] as num).toDouble(),
  deviation: (row['deviation'] as num).toDouble(),
  volatility: (row['volatility'] as num).toDouble(),
);

/// The difficulty a new duel at [rating] gets (a tier or a count band): a
/// rematch looks for the opponent's run closest to it.
int _difficultyFor(DuelMode mode, double rating) => DuelConfig.forRating(
  mode: mode,
  seed: 0,
  rating: ratingPoints(rating),
).difficulty;

/// The starting rating from the player's server levels (`duel_context`'s
/// `levels`, hundredths by type), at Glicko-2's new-player deviation and
/// volatility.
Glicko2Rating _startRating(DuelMode mode, Object? levels) {
  final parsed = <ExerciseType, Level>{};
  if (levels is Map) {
    for (final type in ExerciseType.values) {
      if (levels[type.name] case final int hundredths) {
        parsed[type] = Level.fromHundredths(hundredths);
      }
    }
  }
  return Glicko2Rating(
    rating: startingDuelRating(mode, parsed),
    deviation: newPlayerRating.deviation,
    volatility: newPlayerRating.volatility,
  );
}

/// A decided run, from `duel_context`: what the app shows on its result
/// screen. For the second player: the result, both scores, and their own
/// rating before and after (none when unrated); for a challenger: waiting.
Response _decided(
  Map<Object?, Object?> context, {
  required String role,
  required bool duplicate,
}) {
  final duel = _map(context['duel']);
  final run = _map(context['run']);
  final mode = DuelMode.parse(duel['mode']);
  final body = <String, Object?>{
    'status': 'accepted',
    'duplicate': duplicate,
    'duelId': duel['id'],
    'role': role,
    'kind': duel['kind'],
    'you': run['score'],
    'flags': run['flags'] ?? const [],
  };
  if (role == 'first') {
    body['waiting'] = duel['state'] == 'awaitingSecond';
    if (duel['state'] != 'done') return jsonResponse(200, body);
  }
  final firstLane = duel['firstLane'];
  final myRatings = _map(
    context['ratings'],
  )[duel[role == 'first' ? 'firstPlayer' : 'secondPlayer']];
  final secondResult = (duel['result'] as num?)?.toDouble();
  body.addAll({
    'result': role == 'second' || secondResult == null
        ? secondResult
        : 1 - secondResult,
    'them': role == 'second' && firstLane != null
        ? DuelLane.fromJson(firstLane, mode).score.toJson()
        : null,
    'rated': duel['rated'] == true,
    'rating': {
      'before':
          duel[role == 'first' ? 'firstRatingBefore' : 'secondRatingBefore'],
      'after': duel[role == 'first' ? 'firstRatingAfter' : 'secondRatingAfter'],
      'current': myRatings is Map ? myRatings['rating'] : null,
      'ratedDuels': myRatings is Map ? myRatings['ratedDuels'] : null,
      // "?" for the first 10 rated duels of the mode.
      'provisional': isProvisionalRating(
        myRatings is Map ? (myRatings['ratedDuels'] as int? ?? 0) : 0,
      ),
    },
  });
  return jsonResponse(200, body);
}

Map<Object?, Object?> _map(Object? value) =>
    value is Map ? value : const <Object?, Object?>{};

/// The flags of a run that wait for the owner's review: not the marks of a
/// loss the server recorded itself.
List<String> _reviewFlags(Object? flags) => [
  if (flags is List)
    for (final f in flags)
      if (f is String && f != 'abandoned' && f != 'forfeited') f,
];

/// The second player's progress the server holds, or `null` (none, or
/// stored before the server parsed it and unreadable).
DuelRun? _progress(Map<Object?, Object?> duel, DuelMode mode) {
  final stored = duel['progress'];
  if (stored == null) return null;
  try {
    return DuelRun.fromJson(stored, mode);
  } on FormatException {
    return null;
  }
}

DuelRun _emptyRun(DuelMode mode) =>
    mode.isQuiz ? QuizRun(const []) : CountRun(const []);

/// [run] with what was not played filled in: timeouts, empty rounds.
DuelRun _completed(DuelRun run) => switch (run) {
  final QuizRun q => q.completedWithTimeouts(),
  final CountRun c => c.completedWithEmptyRounds(),
};

DuelRunProblem _problem(Object? name) => DuelRunProblem.values.firstWhere(
  (p) => p.name == name,
  orElse: () => DuelRunProblem.wrongShape,
);

/// How long ago, by the database's clock, [role]'s part of the duel was
/// handed out: a challenger's when the challenge was created, a friend's
/// when they opened it, a pool or practice duel's when matchmaking made it.
/// `null` when the context does not say (a database before Phase 6a).
int? _playedMs(Map<Object?, Object?> context, String role) {
  final duel = _map(context['duel']);
  final opened = role == 'second' && duel['kind'] == 'challenge';
  final now = DateTime.tryParse('${context['now']}');
  final started = DateTime.tryParse(
    '${opened ? duel['openedAt'] : duel['createdAt']}',
  );
  if (now == null || started == null) return null;
  return now.difference(started).inMilliseconds;
}

List<Map<String, Object?>> _rows(Object? result) => switch (result) {
  final List<Object?> list => [
    for (final row in list)
      if (row is Map) row.cast<String, Object?>(),
  ],
  final Map<Object?, Object?> row => [row.cast<String, Object?>()],
  _ => const [],
};
