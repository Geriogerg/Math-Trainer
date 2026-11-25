import 'dart:convert';

import 'package:math_core/duel/duel_config.dart';
import 'package:math_core/duel/duel_mode.dart';
import 'package:math_core/duel/duel_rating.dart';
import 'package:math_core/duel/duel_run.dart';
import 'package:math_core/duel/duel_validation.dart';
import 'package:math_core/leveling/level.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:shelf/shelf.dart';

import 'http_app.dart';
import 'rating/duel_rating_update.dart';
import 'rating/glicko2.dart';
import 'session_endpoint.dart' show refused;
import 'supabase_gateway.dart';

/// Largest accepted duel body: a Get the count run with many improvements
/// is a few KB.
const maxDuelBytes = 64 * 1024;

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
///   not this player's, not their turn, expired, or the run failed its
///   replay (a `DuelRunProblem` — the duel is void): the app records it and
///   never resends;
/// - 401, 403, 413, 503 (Supabase unavailable, or ratings kept moving): the
///   app retries later.
class DuelEndpoint {
  DuelEndpoint(this.gateway);

  final SupabaseGateway gateway;

  List<Route> get routes => [
    (method: 'POST', path: '/v1/duels/run', handler: handleRun),
  ];

  /// Times the server re-reads and recomputes when a rating moved under it.
  static const maxAttempts = 3;

  Future<Response> handleRun(Request request) => _guarded(request, (
    user,
    body,
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
      final duel = _map(context['duel']);
      final String role;
      if (duel['secondPlayer'] == user.id) {
        role = 'second';
      } else if (duel['firstPlayer'] == user.id) {
        role = 'first';
      } else {
        return refused(409, 'notYourDuel');
      }
      if (context['rejection'] case final Map<Object?, Object?> rejection) {
        return refused(409, '${rejection['reason']}');
      }
      if (context['run'] is Map) {
        return _decided(context, role: role, duplicate: true);
      }
      // Not this player's turn (a friend before the challenger, a decided
      // or void duel): refused before the replay, which would record a
      // refusal and void the duel for someone else's mistake.
      final turn = role == 'first' ? 'awaitingFirst' : 'awaitingSecond';
      if (duel['state'] != turn) return refused(409, 'notOpen');

      final config = DuelConfig.fromJson(duel['config']);
      final DuelRun run;
      try {
        run = DuelRun.fromJson(body['run'], config.mode);
      } on FormatException catch (e) {
        return refused(400, 'badRequest', detail: e.message);
      }
      final verdict = validateDuelRun(config, run);
      switch (verdict) {
        case DuelRunInvalid(:final problem, :final detail):
          await gateway.rpc('record_duel_run_refused', {
            'p_duel_id': duelId,
            'p_player_id': user.id,
            'p_reason': problem.name,
            'p_detail': detail,
            'p_payload': run.toJson(),
          });
          return refused(409, problem.name);
        case DuelRunValid(:final score, :final lane, :final flags):
          final start = _startRating(config.mode, context['levels']);
          double? result;
          Map<String, Object?>? ratings;
          if (role == 'second') {
            final theirs = DuelLane.fromJson(duel['firstLane'], config.mode);
            result = duelResult(score, theirs.score);
            ratings = _ratingUpdates(context, user.id, start, result);
          }
          final rows = _rows(
            await gateway.rpc('apply_duel_run', {
              'p_duel_id': duelId,
              'p_player_id': user.id,
              'p_payload': run.toJson(),
              'p_lane': lane.toJson(),
              'p_score': score.toJson(),
              'p_flags': [for (final f in flags) f.name],
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
            case 'notOpen':
            case 'expired':
              return refused(409, '$outcome');
            case 'stale':
              continue;
          }
          throw StateError('apply_duel_run: $outcome');
      }
    }
    return jsonResponse(503, {'error': 'busy'});
  });

  /// Authentication, linked account, body size and JSON object; then
  /// [handle]. Supabase failing anywhere is a 503 (logged).
  Future<Response> _guarded(
    Request request,
    Future<Response> Function(AuthenticatedUser user, Map<String, Object?> body)
    handle,
  ) async {
    final path = '/${request.url.path}';
    try {
      final user = await bearerUser(gateway, request);
      if (user == null) return jsonResponse(401, {'error': 'unauthorized'});
      // Plan v3.7: online play needs a linked account — no guests.
      if (user.isAnonymous) {
        return jsonResponse(403, {'error': 'account_required'});
      }
      final length = request.contentLength;
      if (length != null && length > maxDuelBytes) {
        return jsonResponse(413, {'error': 'too_large'});
      }
      final text = await request.readAsString();
      if (text.length > maxDuelBytes) {
        return jsonResponse(413, {'error': 'too_large'});
      }
      final Object? body;
      try {
        body = text.isEmpty ? const <String, Object?>{} : jsonDecode(text);
      } on FormatException {
        return refused(400, 'badRequest', detail: 'not JSON');
      }
      if (body is! Map) return refused(400, 'badRequest', detail: 'body');
      return await handle(user, body.cast<String, Object?>());
    } on GatewayUnavailable catch (e) {
      // ignore: avoid_print
      print('503 on POST $path: ${e.detail}');
      return jsonResponse(503, {'error': 'unavailable'});
    }
  }
}

/// The rating rows `apply_duel_run` writes for a rated duel — both
/// players' new Glicko-2 ratings with the versions they were computed from
/// — or `null` when the duel is not rated (plan v3.7): practice never; a
/// challenge only if no other challenge between the pair was rated today in
/// this mode; a pool duel always. The second player ([me]) without a rating
/// yet starts at [start] (`apply_duel_run` creates it at version 0).
Map<String, Object?>? _ratingUpdates(
  Map<Object?, Object?> context,
  String me,
  Glicko2Rating start,
  double result,
) {
  final duel = _map(context['duel']);
  final rated = switch (duel['kind']) {
    'pool' => true,
    'challenge' => context['pairRatedToday'] != true,
    _ => false,
  };
  if (!rated) return null;
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

List<Map<String, Object?>> _rows(Object? result) => switch (result) {
  final List<Object?> list => [
    for (final row in list)
      if (row is Map) row.cast<String, Object?>(),
  ],
  final Map<Object?, Object?> row => [row.cast<String, Object?>()],
  _ => const [],
};
