import '../leveling/level.dart';
import '../leveling/rules_version.dart';
import '../models/exercise_type.dart';
import '../tiers/game_draws.dart';
import '../tiers/tier_content.dart';
import '../tiers/tiered_game_generator.dart';
import '../weak_spots/item.dart';
import '../weak_spots/levelling.dart';
import 'exercise_generator.dart';

/// The generator of a game (Levelling or Training) under its
/// [rulesVersion], from what the session stores: its operations, frozen
/// levels and type sequence. One place, so the app's game, the server's
/// replay and a duel draw with the same one. Throws for rules v1, retired
/// (`doc/levels.md`, section 4), and for a type sequence naming an
/// operation the game does not play (rule 13). [weakSpots] (rules v7
/// on): the items to re-ask, checked by `weakSpotProblem` under the game's
/// rules — any other rules, or a breach, throws. From rules v9 the
/// generator keeps the game's memory (`DrawsV9`): one generator per game,
/// never shared.
ExerciseGenerator gameExerciseGenerator({
  required RulesVersion rulesVersion,
  required Set<ExerciseType> enabledTypes,
  required Map<ExerciseType, Level> levels,
  required List<ExerciseType> typeSequence,
  List<Item> weakSpots = const [],
}) {
  if (weakSpots.isNotEmpty) {
    if (!rulesVersion.hasWeakSpots) {
      throw ArgumentError.value(
        rulesVersion,
        'rulesVersion',
        'has no weak spots (rules v7 on).',
      );
    }
    if (weakSpotProblem(weakSpots, typeSequence, levels, rulesVersion)
        case final p?) {
      throw ArgumentError.value(weakSpots, 'weakSpots', p);
    }
  }
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
    // v3 moved only the level update: the same questions as v2.
    RulesVersion.v2 || RulesVersion.v3 => TieredGameGenerator(
      sequence: typeSequence,
      levels: levels,
      content: standardContent,
      withReviews: true,
    ),
    RulesVersion.v4 => TieredGameGenerator(
      sequence: typeSequence,
      levels: levels,
      content: patternedContent,
      withReviews: true,
    ),
    // Pattern questions sized by tier; every question from the player's
    // tier (`doc/levels.md` v1.4).
    RulesVersion.v5 => TieredGameGenerator(
      sequence: typeSequence,
      levels: levels,
      content: patternedContentV5,
      withReviews: false,
    ),
    // v5, with √ of powers of 2 sized by its own row (`doc/levels.md`
    // v1.5).
    RulesVersion.v6 => TieredGameGenerator(
      sequence: typeSequence,
      levels: levels,
      content: patternedContentV6,
      withReviews: false,
    ),
    // v6, plus the stored weak spots (Phase 4).
    // v8 changed only the schedule, not the questions.
    RulesVersion.v7 || RulesVersion.v8 => TieredGameGenerator(
      sequence: typeSequence,
      levels: levels,
      content: patternedContentV6,
      withReviews: false,
      weakSpots: weakSpots,
    ),
    // `doc/levels.md` v1.6: the spaces of distinct questions, drawn without
    // repeats by the game's own memory.
    RulesVersion.v9 => TieredGameGenerator(
      sequence: typeSequence,
      levels: levels,
      draws: DrawsV9(weakSpots: weakSpots),
      withReviews: false,
      weakSpots: weakSpots,
    ),
  };
}
