import 'dart:convert';
import 'dart:math';

import 'package:math_core/persistence/uuid.dart';
import 'package:shelf/shelf.dart';

import 'duels/duel_abandonment.dart';
import 'duels/duel_matchmaking.dart';
import 'duels/duel_runs.dart';
import 'http_app.dart';
import 'rate_limit.dart';
import 'session_endpoint.dart' show refused;
import 'supabase_gateway.dart';

export 'duels/duel_matchmaking.dart' show maxDuelsPerDay;

/// Largest accepted duel body: a Get the count run with many improvements
/// is a few KB.
const maxDuelBytes = 64 * 1024;

/// The duel endpoints (plan v3.7, Phase 7). Online play needs a linked
/// account: a guest gets 403 `account_required`. This class is the HTTP
/// surface — authentication, body, the routes; the work is in `duels/`
/// (split by responsibility at the 6a close-out, plan v4.0): handing out
/// duels ([DuelMatchmaking]), runs and progress ([DuelRuns]), abandoned
/// duels ([DuelAbandonment]), ratings (`duel_ratings.dart`) and the JSON
/// answers (`duel_json.dart`).
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
/// `POST /v1/duels/progress` `{duelId, run}` — the run as it stands during
/// play ([DuelRuns.progress]).
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
  }) {
    _runs = DuelRuns(gateway);
    _matchmaking = DuelMatchmaking(
      gateway,
      seeds ?? Random.secure(),
      newId ?? generateUuidV4,
    );
    _abandonment = DuelAbandonment(gateway, _runs, clock: clock);
  }

  final SupabaseGateway gateway;

  /// The per-player request limit (none in most tests).
  final RateLimits? limits;

  /// Whether each duel request records one batch of abandoned duels before
  /// it is handled (tests: deterministic). The production server does it
  /// at start, on a timer and, at most once a minute, after a request —
  /// never inside one (Phase 6a, review m10: it slowed unrelated requests).
  final bool sweepInRequests;

  late final DuelRuns _runs;
  late final DuelMatchmaking _matchmaking;
  late final DuelAbandonment _abandonment;

  /// How much more than the time since the duel was handed out a run may
  /// claim ([DuelRuns.clockMargin]).
  static const clockMargin = DuelRuns.clockMargin;

  /// How many abandoned duels one batch records ([DuelAbandonment.batch]).
  static const abandonedPerRequest = DuelAbandonment.batch;

  /// The shortest time between two sweeps outside requests.
  static const minSweepGap = DuelAbandonment.minSweepGap;

  /// Times the server re-reads and recomputes when a rating moved under it.
  static const maxAttempts = DuelRuns.maxAttempts;

  List<Route> get routes => [
    (method: 'POST', path: '/v1/duels', handler: handleFind),
    (method: 'POST', path: '/v1/duels/open', handler: handleOpen),
    (method: 'POST', path: '/v1/duels/run', handler: handleRun),
    (method: 'POST', path: '/v1/duels/progress', handler: handleProgress),
  ];

  Future<Response> handleFind(Request request) =>
      _guarded(request, _matchmaking.find);

  Future<Response> handleOpen(Request request) =>
      _guarded(request, _matchmaking.open);

  Future<Response> handleRun(Request request) => _guarded(request, _runs.run);

  Future<Response> handleProgress(Request request) =>
      _guarded(request, _runs.progress, sweep: false);

  /// One batch of abandoned duels ([DuelAbandonment.sweepOnce]).
  Future<void> sweepAbandoned() => _abandonment.sweepOnce();

  /// Every abandoned duel, batch after batch ([DuelAbandonment.catchUp]):
  /// how many were recorded.
  Future<int> catchUpAbandoned() => _abandonment.catchUp();

  /// A catch-up outside the requests, at most once a minute
  /// ([DuelAbandonment.sweepSoon]); the server calls it at start too.
  void sweepSoon() => _abandonment.sweepSoon();

  /// The sweep [sweepSoon] started, while it runs (tests await it).
  Future<void>? get sweepRunning => _abandonment.running;

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
      // Plan v3.7: online play needs a linked account — no guests; an
      // unconfirmed email is a guest (Phase 6c commit 3).
      if (user.isGuest) {
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
