import 'package:math_core/duel/duel_config.dart';
import 'package:math_core/duel/duel_mode.dart';
import 'package:math_core/duel/duel_rating.dart';
import 'package:math_core/leveling/level.dart';
import 'package:math_core/models/exercise_type.dart';

import '../rating/duel_rating_update.dart';
import '../rating/glicko2.dart';
import 'duel_json.dart';

/// Which duels move ratings, and by how much (split out of
/// `duel_endpoint.dart` at the 6a close-out, plan v4.0).

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
Map<String, Object?>? ratingUpdates(
  Map<Object?, Object?> context,
  String me,
  Glicko2Rating start,
  double result, {
  required bool secondFlagged,
}) {
  final duel = jsonMap(context['duel']);
  final chosen = duel['chosen'] == true || duel['kind'] == 'challenge';
  final rated = switch (duel['kind']) {
    'pool' || 'challenge' => !(chosen && context['pairRatedToday'] == true),
    _ => false,
  };
  if (!rated) return null;
  if (secondFlagged && result > 0) return null;
  if (reviewFlags(context['firstFlags']).isNotEmpty && result < 1) return null;
  final rows = jsonMap(context['ratings']);
  final first = duel['firstPlayer'];
  final firstRow = rows[first];
  // A run's owner has a rating since that run was accepted; none would be
  // a broken invariant — the duel then stays unrated rather than guessed.
  if (firstRow is! Map || first is! String) return null;
  final secondRow = rows[me];
  final before = (
    first: ratingOf(firstRow),
    second: secondRow is Map ? ratingOf(secondRow) : start,
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

/// A stored rating row as Glicko-2 numbers.
Glicko2Rating ratingOf(Map<Object?, Object?> row) => Glicko2Rating(
  rating: (row['rating'] as num).toDouble(),
  deviation: (row['deviation'] as num).toDouble(),
  volatility: (row['volatility'] as num).toDouble(),
);

/// The difficulty a new duel at [rating] gets (a tier or a count band): a
/// rematch looks for the opponent's run closest to it.
int difficultyFor(DuelMode mode, double rating) => DuelConfig.forRating(
  mode: mode,
  seed: 0,
  rating: ratingPoints(rating),
).difficulty;

/// The starting rating from the player's server levels (`duel_context`'s
/// `levels`, hundredths by type), at Glicko-2's new-player deviation and
/// volatility.
Glicko2Rating startRating(DuelMode mode, Object? levels) {
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

/// The flags of a run that wait for the owner's review: not the marks of a
/// loss the server recorded itself.
List<String> reviewFlags(Object? flags) => [
  if (flags is List)
    for (final f in flags)
      if (f is String && f != 'abandoned' && f != 'forfeited') f,
];
