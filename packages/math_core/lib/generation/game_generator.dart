import '../leveling/level.dart';
import '../leveling/rules_version.dart';
import '../models/exercise_type.dart';
import '../tiers/tiered_game_generator.dart';
import 'exercise_generator.dart';

/// The generator of a game (Levelling or Training) under its
/// [rulesVersion], from what the session stores: its operations, frozen
/// levels and type sequence. One place, so the app's game, the server's
/// replay and a duel draw with the same one. Throws for rules v1, retired
/// (`doc/levels.md`, section 4), and for a type sequence naming an
/// operation the game does not play (rule 13).
ExerciseGenerator gameExerciseGenerator({
  required RulesVersion rulesVersion,
  required Set<ExerciseType> enabledTypes,
  required Map<ExerciseType, Level> levels,
  required List<ExerciseType> typeSequence,
}) {
  for (final type in typeSequence) {
    if (!enabledTypes.contains(type)) {
      throw ArgumentError.value(
        type,
        'typeSequence',
        'is not one of the enabled types $enabledTypes.',
      );
    }
  }
  return switch (rulesVersion) {
    RulesVersion.v1 => throw ArgumentError.value(
      rulesVersion,
      'rulesVersion',
      'is retired: its questions are never drawn again.',
    ),
    RulesVersion.v2 => TieredGameGenerator(
      sequence: typeSequence,
      levels: levels,
    ),
  };
}
