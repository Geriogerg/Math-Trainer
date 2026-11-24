import '../models/exercise.dart';
import '../patterns/pattern_family.dart';
import '../strategies/strategy.dart';
import 'facts.dart';
import 'item.dart';

/// The item a question trains (`doc/decisions.md`, "Phase 4"): a pattern
/// question ([family] set) is its family's skill, even when fact-sized; a
/// standard question is its fact — one some tier draws ([homeTier]; an
/// older game may have asked one no tier draws now, like v2's 30 + 70) —
/// else the skill of its detector strategy ([skillFamilyOf]), else nothing
/// (`null`: not tracked).
///
/// Throws if [family] is not of [exercise]'s operation (rule 13).
Item? itemOf(Exercise exercise, {PatternFamily? family}) {
  if (family != null) {
    if (family.type != exercise.type) {
      throw ArgumentError.value(
        family,
        'family',
        'is not a ${exercise.type.name} family.',
      );
    }
    return SkillItem(family);
  }
  if (factOf(exercise) case final fact? when homeTier(fact) != null) {
    return fact;
  }
  return switch (bestStrategy(exercise)?.strategy) {
    final strategy? => switch (skillFamilyOf(strategy)) {
      final f? => SkillItem(f),
      null => null,
    },
    null => null,
  };
}

/// The family that teaches [strategy] — the first family of its tip on
/// the Tips page — or `null` for splitting a factor, multiplication's
/// general method (not a skill to track).
PatternFamily? skillFamilyOf(Strategy strategy) => switch (strategy) {
  Strategy.compensation => PatternFamily.addJustBelowRound,
  Strategy.subtractViaRound => PatternFamily.subtractJustBelowRound,
  Strategy.doublingHalving => PatternFamily.doublingHalving,
  Strategy.differenceOfSquares => PatternFamily.differenceOfSquares,
  Strategy.squareNearBase => PatternFamily.squaresNear50And100,
  Strategy.swapPercentage => PatternFamily.swap,
  Strategy.splitFactor => null,
};
