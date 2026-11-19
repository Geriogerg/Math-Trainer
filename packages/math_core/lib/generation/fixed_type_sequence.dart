import '../models/exercise_type.dart';
import 'type_selection_strategy.dart';

/// A type order decided once and stored with the session (plan, Phase 2
/// commit 1): replaying a session needs only what it stores, never the
/// history that decided the order (`DebtAwareTypeSelectionStrategy` reads
/// the player's per-type counts at the time). Consumes no randomness, like
/// the strategy it replaces, so the questions are the same.
class FixedTypeSequence implements TypeSelectionStrategy {
  FixedTypeSequence(List<ExerciseType> sequence)
    : sequence = List.unmodifiable(sequence) {
    if (sequence.isEmpty) {
      throw ArgumentError.value(sequence, 'sequence', 'must not be empty.');
    }
  }

  final List<ExerciseType> sequence;

  @override
  List<ExerciseType> sequenceFor(List<ExerciseType> sortedEnabledTypes) {
    for (final type in sequence) {
      if (!sortedEnabledTypes.contains(type)) {
        throw ArgumentError.value(
          type,
          'sequence',
          'is not one of the enabled types $sortedEnabledTypes.',
        );
      }
    }
    return sequence;
  }
}
