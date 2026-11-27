import 'dart:math';

import 'package:math_core/duel/duel_config.dart';
import 'package:math_core/duel/duel_mode.dart';
import 'package:math_core/duel/duel_rating.dart';
import 'package:math_core/duel/practice_lane.dart';
import 'package:shelf/shelf.dart';

import '../http_app.dart';
import '../rate_limit.dart';
import '../session_endpoint.dart' show refused;
import '../supabase_gateway.dart';
import 'duel_json.dart';
import 'duel_ratings.dart';

/// Most duels handed out to one player over a rolling 24 hours (plan v3.9,
/// Phase 6a): a duel takes a minute or more, and each one is a row.
const maxDuelsPerDay = 200;

/// Handing out duels: matchmaking, rematches, challenges, and opening a
/// challenge (split out of `duel_endpoint.dart` at the 6a close-out, plan
/// v4.0). The answers are described on `DuelEndpoint`.
class DuelMatchmaking {
  /// [_seeds] draws each new duel's seed, [_newId] its id.
  DuelMatchmaking(this.gateway, this._seeds, this._newId);

  final SupabaseGateway gateway;
  final Random _seeds;
  final String Function() _newId;

  /// A duel's seed: positive and under 2³¹, the same on every platform
  /// that will draw from it.
  int _seed() => _seeds.nextInt(1 << 31);

  /// `POST /v1/duels`.
  Future<Response> find(
    AuthenticatedUser user,
    Map<String, Object?> body,
  ) async {
    final DuelMode mode;
    try {
      mode = DuelMode.parse(body['mode']);
    } on FormatException catch (e) {
      return refused(400, 'badRequest', detail: e.message);
    }
    final me = await _player(user.id, mode);
    if (me == null) return refused(409, 'notLinked');
    // The owner suspended the account: no new duel (a hidden player still
    // plays, against practice opponents — `duel_take_run`).
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
      final duel = jsonMap(context['duel']);
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
          'p_difficulty': difficultyFor(mode, rating),
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
  }

  /// `POST /v1/duels/open`.
  Future<Response> open(
    AuthenticatedUser user,
    Map<String, Object?> body,
  ) async {
    final duelId = body['duelId'];
    if (duelId is! String) return refused(400, 'badRequest', detail: 'duelId');
    final context = await gateway.rpc('duel_context', {
      'p_duel_id': duelId,
      'p_player_id': user.id,
    });
    if (context is! Map) return refused(404, 'unknownDuel');
    final duel = jsonMap(context['duel']);
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
    final theirs = jsonMap(context['ratings'])[first];
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
  }

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
          : startRating(mode, json['levels']).rating,
      ratedDuels: row is Map ? row['ratedDuels'] as int : 0,
      name: json['name'] as String?,
      duelsToday: json['duelsToday'] as int? ?? 0,
      banned: json['moderation'] == 'banned',
    );
  }
}
