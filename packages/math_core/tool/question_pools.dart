// The question pools of rules v8 and v9 (Phase 6b commit 1, review M10):
// per operation and tier, how many distinct standard questions a tier
// draws and how often a 10-question game of one operation repeats one;
// which v9 pattern families are skipped (fewer than 4 questions).
//
//   dart run tool/question_pools.dart
//
// v8's counts are sampled (200,000 draws; "≥" when the second half still
// found new ones); v9's are exact (its spaces list every question) or
// estimated from the tuples for the long sums ("~").

import 'dart:math';

import 'package:math_core/generation/game_generator.dart';
import 'package:math_core/leveling/level.dart';
import 'package:math_core/leveling/rules_version.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/patterns/pattern_family.dart';
import 'package:math_core/patterns/pattern_spaces_v9.dart';
import 'package:math_core/tiers/question_space.dart';
import 'package:math_core/tiers/standard_v9.dart';
import 'package:math_core/tiers/tier.dart';
import 'package:math_core/tiers/tier_content.dart';

void main() {
  print('== distinct standard questions per tier (v8 sampled / v9)');
  print(
    '  operation       ${[for (final t in Tier.values) t.label.padLeft(17)].join()}',
  );
  for (final type in ExerciseType.values) {
    final cells = [
      for (final tier in Tier.values)
        '${_v8Distinct(type, tier)} / ${_v9Distinct(type, tier)}'.padLeft(17),
    ];
    print('  ${type.name.padRight(16)}${cells.join()}');
  }
  print('');
  print(
    '== 10-question games of one operation with a repeated question, % '
    '(2,000 games each; v8 / v9)',
  );
  print(
    '  operation       ${[for (final t in Tier.values) t.label.padLeft(9)].join()}',
  );
  for (final type in ExerciseType.values) {
    final cells = [
      for (final tier in Tier.values)
        '${_repeats(type, tier, RulesVersion.v8)}/${_repeats(type, tier, RulesVersion.v9)}'
            .padLeft(9),
    ];
    print('  ${type.name.padRight(16)}${cells.join()}');
  }
  print('');
  print(
    '== v9 pattern families skipped (fewer than $minDistinctFamily questions at the tier)',
  );
  for (final family in PatternFamily.values) {
    final skipped = [
      for (final tier in Tier.values.skip(family.from.index))
        if (familySpaceV9(family, tier).distinct < minDistinctFamily)
          '${tier.label} (${familySpaceV9(family, tier).distinct})',
    ];
    if (skipped.isNotEmpty) print('  ${family.name}: ${skipped.join(', ')}');
  }
}

String _v8Distinct(ExerciseType type, Tier tier) {
  final random = Random(7);
  final seen = <Object>{};
  var lateNew = 0;
  const draws = 200000;
  for (var i = 0; i < draws; i++) {
    final key = canonicalOf(standardQuestionV4(type, tier, random));
    if (seen.add(key) && i >= draws ~/ 2) lateNew++;
  }
  return lateNew == 0 ? '${seen.length}' : '≥${_short(seen.length.toDouble())}';
}

String _v9Distinct(ExerciseType type, Tier tier) {
  final space = standardSpaceV9(type, tier);
  return space.approximateDistinct > listLimit
      ? '~${_short(space.approximateDistinct)}'
      : '${space.distinct}';
}

String _short(double n) {
  if (n < 1e4) return n.round().toString();
  var e = 0;
  var m = n;
  while (m >= 10) {
    m /= 10;
    e++;
  }
  return '${m.toStringAsFixed(1)}e$e';
}

/// The share of 10-question games of [type] at [tier] that ask a question
/// twice (commutative forms the same).
int _repeats(ExerciseType type, Tier tier, RulesVersion rules) {
  final random = Random(11 + 31 * type.index + tier.index);
  var games = 0;
  for (var g = 0; g < 2000; g++) {
    final generator = gameExerciseGenerator(
      rulesVersion: rules,
      enabledTypes: {type},
      levels: {type: Level.whole(10 * tier.index)},
      typeSequence: List.filled(10, type),
    );
    final asked = <Object>{};
    var repeated = false;
    for (var i = 0; i < 10; i++) {
      if (!asked.add(canonicalOf(generator.next(random)))) repeated = true;
    }
    if (repeated) games++;
  }
  return (100 * games / 2000).round();
}
