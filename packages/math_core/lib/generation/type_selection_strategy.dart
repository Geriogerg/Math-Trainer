import '../models/exercise_type.dart';

/// Decides the sequence of exercise types in a session — the extension
/// point between solo (debt rotation, depends on the player's history) and
/// future duels (fixed quotas, independent of history so that two players
/// get the same sequence for equal `(seed, config)` without sharing their
/// local data). See `doc/decisions.md`.
abstract class TypeSelectionStrategy {
  /// [sortedEnabledTypes] is already sorted by `.index` (never drawn
  /// directly from a `Set`). The length of the result sets the number of
  /// questions in the session.
  List<ExerciseType> sequenceFor(List<ExerciseType> sortedEnabledTypes);
}
