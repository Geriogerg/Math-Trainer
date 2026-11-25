import '../leveling/level.dart';
import '../leveling/main_level.dart';
import '../models/exercise_type.dart';
import 'duel_mode.dart';

/// A player's first rating in a mode (plan v3.7), before any duel: Basics =
/// 900 + 15 × main level; Advanced = 900 + 15 × the mean of the four
/// advanced levels (an unplayed one at 0, as in the main level); Get the
/// count = 1300. The server creates the rating with it; the app shows the
/// same value, marked provisional, until the first duel.
///
/// Ratings themselves (Glicko-2) are the server's alone and may be
/// fractional; this is exact: hundredths in, 15 per level.
double startingDuelRating(DuelMode mode, Map<ExerciseType, Level> levels) =>
    switch (mode) {
      DuelMode.basics => 900 + 15 * mainLevelOf(levels),
      DuelMode.advanced =>
        900 + 15 * _meanLevel(DuelMode.advanced.types, levels),
      DuelMode.count => 1300,
    };

double _meanLevel(List<ExerciseType> types, Map<ExerciseType, Level> levels) {
  var sum = 0;
  for (final type in types) {
    sum += (levels[type] ?? Level.zero).hundredths;
  }
  return sum / types.length / 100;
}

/// A rating is provisional ("?") until this many **rated** duels of its
/// mode: practice duels and unrated friend duels do not count.
const provisionalDuelCount = 10;

bool isProvisionalRating(int ratedDuels) => ratedDuels < provisionalDuelCount;

/// A rating as shown and as difficulty reads it: rounded to the point.
int ratingPoints(double rating) => rating.round();
