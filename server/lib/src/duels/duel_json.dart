import 'package:math_core/duel/duel_mode.dart';
import 'package:math_core/duel/duel_rating.dart';
import 'package:math_core/duel/duel_run.dart';
import 'package:shelf/shelf.dart';

import '../http_app.dart';

/// Reading the database's JSON and shaping the duel endpoints' answers
/// (split out of `duel_endpoint.dart` at the 6a close-out, plan v4.0).

/// [value] as a map, or an empty one: a missing object reads as nothing.
Map<Object?, Object?> jsonMap(Object? value) =>
    value is Map ? value : const <Object?, Object?>{};

/// A function's rows: a list of objects, or a single object.
List<Map<String, Object?>> jsonRows(Object? result) => switch (result) {
  final List<Object?> list => [
    for (final row in list)
      if (row is Map) row.cast<String, Object?>(),
  ],
  final Map<Object?, Object?> row => [row.cast<String, Object?>()],
  _ => const [],
};

/// A decided run, from `duel_context`: what the app shows on its result
/// screen. For the second player: the result, both scores, and their own
/// rating before and after (none when unrated); for a challenger: waiting.
Response decidedResponse(
  Map<Object?, Object?> context, {
  required String role,
  required bool duplicate,
}) {
  final duel = jsonMap(context['duel']);
  final run = jsonMap(context['run']);
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
  final myRatings = jsonMap(
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
