import '../leveling/level.dart';
import '../leveling/rules_version.dart';
import '../models/exercise_type.dart';
import '../tiers/tiered_game_generator.dart';
import 'composite_exercise_generator.dart';
import 'exercise_generator.dart';
import 'fixed_type_sequence.dart';

/// The generator of a game (Levelling or Training) under its
/// [rulesVersion], from what the session stores: its operations, frozen
/// levels and type sequence. One place, so the app's game and the
/// server's replay draw with the same one.
ExerciseGenerator gameExerciseGenerator({
  required RulesVersion rulesVersion,
  required Set<ExerciseType> enabledTypes,
  required Map<ExerciseType, Level> levels,
  required List<ExerciseType> typeSequence,
}) => switch (rulesVersion) {
  RulesVersion.v1 => CompositeExerciseGenerator(
    enabledTypes: enabledTypes,
    levels: levels,
    strategy: FixedTypeSequence(typeSequence),
  ),
  RulesVersion.v2 => TieredGameGenerator(
    sequence: FixedTypeSequence(
      typeSequence,
    ).sequenceFor([...enabledTypes]..sort((a, b) => a.index - b.index)),
    levels: levels,
  ),
};
