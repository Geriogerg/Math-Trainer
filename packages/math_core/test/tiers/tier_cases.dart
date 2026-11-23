import 'dart:convert';
import 'dart:math';

import 'package:math_core/generation/game_generator.dart';
import 'package:math_core/generation/question_plan.dart';
import 'package:math_core/leveling/level.dart';
import 'package:math_core/leveling/rules_version.dart';
import 'package:math_core/models/exercise.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/persistence/exercise_codec.dart';
import 'package:math_core/tiers/tier.dart';
import 'package:math_core/tiers/tier_content.dart';

/// Rules v2's pinned cases (`tool/tier_references.dart` writes their
/// output on the VM; `tier_determinism_test.dart` checks it on VM and
/// JavaScript).
const tierSeeds = [1, 2026, 1763510400123];

/// An exercise as stored: its type and operands, one stable string.
String describe(Exercise e) {
  final d = describeExerciseForStorage(e);
  return '${d.operationType}${jsonEncode(d.operands)}';
}

/// Six questions of every tier of [type], from [seed].
String tierSequence(ExerciseType type, int seed) {
  final random = Random(seed);
  return [
    for (final tier in Tier.values)
      for (var i = 0; i < 6; i++) describe(exerciseAt(type, tier, random)),
  ].join(' ');
}

/// The levels of the pinned games: every type, a different tier each.
final Map<ExerciseType, Level> gameLevels = {
  for (final type in ExerciseType.values)
    type: Level.fromHundredths(1234 * (type.index + 1) % 10001),
};

/// A whole game of every type, 5 questions each, as the app plays it.
String gameSequence(int seed) {
  final sequence = shuffledTypeSequence(
    types: gameLevels.keys.toSet(),
    perOperation: 5,
    seed: seed,
  );
  final generator = gameExerciseGenerator(
    rulesVersion: RulesVersion.v2,
    enabledTypes: gameLevels.keys.toSet(),
    levels: gameLevels,
    typeSequence: sequence,
  );
  final random = Random(seed);
  return [for (final _ in sequence) describe(generator.next(random))].join(' ');
}
