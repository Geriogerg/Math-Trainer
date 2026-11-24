import 'dart:math';

import '../generation/exercise_generator.dart';
import '../leveling/level.dart';
import '../models/exercise.dart';
import '../models/exercise_type.dart';
import '../patterns/pattern_family.dart';
import '../patterns/pattern_questions.dart';
import '../tiers/draw.dart';
import '../tiers/tier.dart';
import '../tiers/tier_content.dart';
import 'facts.dart';
import 'item.dart';

/// Questions in a Weak spots game (Phase 4): at most this many.
const weakSpotsGameLength = 10;

/// Questions in a Drill game (Phase 4).
const drillGameLength = 10;

/// Whether a Weak spots game may ask [item] of a player at [level] of its
/// operation (plan v3.5: "any tier up to their own"): a fact whose home
/// tier is at or below the player's, a skill whose family has started by
/// the player's tier.
bool practisable(Item item, Level level) {
  final tier = Tier.of(level);
  return switch (item) {
    FactItem() => switch (homeTier(item)) {
      final home? => home.index <= tier.index,
      null => false,
    },
    SkillItem(:final family) => family.from.index <= tier.index,
  };
}

/// A Weak spots game's items: the [due] ones, most urgent first, that the
/// player can practise ([practisable], at [levels]), at most [max].
List<Item> chooseWeakSpotsGame({
  required List<Item> due,
  required Map<ExerciseType, Level> levels,
  int max = weakSpotsGameLength,
}) => [
  for (final item in due)
    if (practisable(item, levels[item.type] ?? Level.zero)) item,
].take(max).toList();

/// What is wrong with a stored Weak spots game; `null` when nothing is:
/// one question per item, in order, 1 to [weakSpotsGameLength]
/// questions, each item practisable at its operation's stored level.
String? weakSpotsGameProblem(
  List<Item> items,
  List<ExerciseType> sequence,
  Map<ExerciseType, Level> levels,
) {
  if (items.isEmpty || items.length > weakSpotsGameLength) {
    return '${items.length} items';
  }
  if (sequence.length != items.length) return 'one question per item';
  for (final (i, item) in items.indexed) {
    if (sequence[i] != item.type) return 'question $i is not ${item.type}';
    final level = levels[item.type];
    if (level == null) return 'no level for ${item.type.name}';
    if (!practisable(item, level)) return '$item above the player\'s tier';
  }
  return null;
}

/// A Weak spots game's questions: each item in turn — a fact in a form of
/// its home tier, a skill as a new question of its family at the player's
/// tier ([levels]). The caller checks [weakSpotsGameProblem] first.
class WeakSpotsGameGenerator implements ExerciseGenerator {
  WeakSpotsGameGenerator({
    required List<Item> items,
    required Map<ExerciseType, Level> levels,
  }) : _items = List.unmodifiable(items),
       _levels = Map.unmodifiable(levels);

  final List<Item> _items;
  final Map<ExerciseType, Level> _levels;
  int _position = 0;

  /// The family of the last question; `null` for a fact.
  PatternFamily? get lastFamily => _lastFamily;
  PatternFamily? _lastFamily;

  @override
  Exercise next(Random random) {
    if (_position >= _items.length) {
      throw StateError('All ${_items.length} items asked.');
    }
    final item = _items[_position++];
    switch (item) {
      case FactItem():
        _lastFamily = null;
        return drawOne(random, formsAt(item, homeTier(item)!));
      case SkillItem(:final family):
        _lastFamily = family;
        return patternQuestion(
          family,
          Tier.of(_levels[item.type] ?? Level.zero),
          random,
        );
    }
  }
}

/// The tier a Drill of [families] of [type] is played at by a player at
/// [playerTier] (`doc/decisions.md`, "Phase 4"): the player's own, or the
/// lowest tier one of the families starts at when the player is below all
/// of them. Without families, the player's tier brought into the tip's
/// band [bandLow]–[bandHigh].
Tier drillTier({
  required List<PatternFamily> families,
  required Tier playerTier,
  required Tier bandLow,
  required Tier bandHigh,
}) {
  if (families.isEmpty) {
    final i = playerTier.index.clamp(bandLow.index, bandHigh.index);
    return Tier.values[i];
  }
  final lowest = families.map((f) => f.from.index).reduce(min);
  return Tier.values[max(playerTier.index, lowest)];
}

/// What is wrong with a stored Drill: [drillGameLength] questions of one
/// operation, its families of that operation, at least one available at
/// the stored tier; `null` when nothing is.
String? drillProblem(
  List<Item> families,
  List<ExerciseType> sequence,
  Map<ExerciseType, Level> levels,
) {
  if (sequence.length != drillGameLength || sequence.toSet().length != 1) {
    return 'not $drillGameLength questions of one operation';
  }
  final type = sequence.first;
  final level = levels[type];
  if (level == null || levels.length != 1) return 'one level, for $type';
  for (final item in families) {
    if (item is! SkillItem || item.type != type) return '$item: not a family';
  }
  if (families.toSet().length != families.length) return 'a family twice';
  if (families.isNotEmpty &&
      !families.any(
        (f) => (f as SkillItem).family.from.index <= Tier.of(level).index,
      )) {
    return 'no family available at ${Tier.of(level).label}';
  }
  return null;
}

/// A Drill's questions (Phase 4): with families, one drawn uniformly
/// among those available at the tier for each question, at that tier's
/// size; without, the operation's standard questions of the tier.
class DrillGenerator implements ExerciseGenerator {
  DrillGenerator({
    required this.type,
    required this.tier,
    required List<PatternFamily> families,
  }) : _available = [
         for (final f in families)
           if (f.from.index <= tier.index) f,
       ];

  final ExerciseType type;
  final Tier tier;
  final List<PatternFamily> _available;

  PatternFamily? get lastFamily => _lastFamily;
  PatternFamily? _lastFamily;

  @override
  Exercise next(Random random) {
    if (_available.isEmpty) {
      _lastFamily = null;
      return standardQuestionV4(type, tier, random);
    }
    final family = drawOne(random, _available);
    _lastFamily = family;
    return patternQuestion(family, tier, random);
  }
}
