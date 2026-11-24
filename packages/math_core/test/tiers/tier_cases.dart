import 'dart:convert';
import 'dart:math';

import 'package:math_core/generation/game_generator.dart';
import 'package:math_core/generation/question_plan.dart';
import 'package:math_core/leveling/level.dart';
import 'package:math_core/leveling/rules_version.dart';
import 'package:math_core/models/exercise.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/patterns/pattern_family.dart';
import 'package:math_core/patterns/pattern_questions.dart';
import 'package:math_core/patterns/pattern_questions_v4.dart';
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

/// Rules v4's pinned cases (`test/tiers/tier_references_v4.dart`): six
/// questions of every tier of [type] as v4 draws them, each with its
/// family when it is a pattern question.
String patternedSequence(ExerciseType type, int seed) {
  final random = Random(seed);
  return [
    for (final tier in Tier.values)
      for (var i = 0; i < 6; i++)
        () {
          final q = patternedContent(type, tier, random);
          final family = q.family;
          return '${describe(q.exercise)}'
              '${family == null ? '' : '/${family.name}'}';
        }(),
  ].join(' ');
}

/// Three questions of every pattern family, in the spec's order, from
/// [seed].
String familySequence(int seed) {
  final random = Random(seed);
  return [
    for (final family in PatternFamily.values)
      for (var i = 0; i < 3; i++) describe(patternQuestionV4(family, random)),
  ].join(' ');
}

/// A whole game of every type, 5 questions each, as the app plays it.
String gameSequence(int seed, [RulesVersion rules = RulesVersion.v2]) {
  final sequence = shuffledTypeSequence(
    types: gameLevels.keys.toSet(),
    perOperation: 5,
    seed: seed,
  );
  final generator = gameExerciseGenerator(
    rulesVersion: rules,
    enabledTypes: gameLevels.keys.toSet(),
    levels: gameLevels,
    typeSequence: sequence,
  );
  final random = Random(seed);
  return [for (final _ in sequence) describe(generator.next(random))].join(' ');
}

/// Rules v5's pinned cases (`test/tiers/tier_references_v5.dart`): six
/// questions of every tier of [type] as v5 draws them, with their family.
String patternedSequenceV5(ExerciseType type, int seed) {
  final random = Random(seed);
  return [
    for (final tier in Tier.values)
      for (var i = 0; i < 6; i++)
        () {
          final q = patternedContentV5(type, tier, random);
          final family = q.family;
          return '${describe(q.exercise)}'
              '${family == null ? '' : '/${family.name}'}';
        }(),
  ].join(' ');
}

/// Two questions of every pattern family at every tier from its first, as
/// v5 sizes them, from [seed].
String familySequenceV5(int seed) {
  final random = Random(seed);
  return [
    for (final family in PatternFamily.values)
      for (final tier in Tier.values.skip(family.from.index))
        for (var i = 0; i < 2; i++)
          describe(patternQuestionV5(family, tier, random)),
  ].join(' ');
}

/// Rules v6's pinned cases (`test/tiers/tier_references_v6.dart`).
String patternedSequenceV6(ExerciseType type, int seed) {
  final random = Random(seed);
  return [
    for (final tier in Tier.values)
      for (var i = 0; i < 6; i++)
        () {
          final q = patternedContentV6(type, tier, random);
          final family = q.family;
          return '${describe(q.exercise)}'
              '${family == null ? '' : '/${family.name}'}';
        }(),
  ].join(' ');
}

/// Two questions of every pattern family at every tier from its first, as
/// v6 sizes them, from [seed].
String familySequenceV6(int seed) {
  final random = Random(seed);
  return [
    for (final family in PatternFamily.values)
      for (final tier in Tier.values.skip(family.from.index))
        for (var i = 0; i < 2; i++)
          describe(patternQuestion(family, tier, random)),
  ].join(' ');
}
