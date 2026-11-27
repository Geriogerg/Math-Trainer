import '../leveling/level.dart';
import '../leveling/rules_version.dart';
import '../models/exercise_type.dart';
import '../patterns/pattern_family.dart';
import '../patterns/pattern_spaces_v9.dart';
import '../tiers/game_draws.dart';
import '../tiers/tier.dart';
import 'facts.dart';
import 'item.dart';

/// Whether [item] can be asked at [tier] of its operation under [rules]
/// (`doc/decisions.md`, "Phase 4"): a fact that tier's standard questions
/// draw, a skill whose family is drawn there. The rule behind "weak-spot
/// questions only from the player's current tier". Rules v7–v8 read their
/// tables ([formsAt], `PatternFamily.availableAt`); v9 its own
/// (`factAtV9`, `familiesAtV9`: a family skipped at a tier is not asked
/// there).
bool belongsTo(Item item, Tier tier, RulesVersion rules) =>
    rules.drawsWithoutRepeats
    ? switch (item) {
        FactItem() => factAtV9(item, tier),
        SkillItem(:final family) => familiesAtV9(
          family.type,
          tier,
        ).contains(family),
      }
    : switch (item) {
        FactItem() => formsAt(item, tier).isNotEmpty,
        SkillItem(:final family) => PatternFamily.availableAt(
          family.type,
          tier,
        ).contains(family),
      };

/// At most this many weak-spot questions in a Levelling game of
/// [questions] questions (plan v3.5: "up to 20 %"): ⌊N / 5⌋.
int weakSpotGameCap(int questions) => questions ~/ 5;

/// At most this many for one operation of [questions] questions in the
/// game under [rules]: from rules v9 ⌊n / 5⌋ — strictly 20 % (plan v3.9,
/// review m5): none of 4, 1 of 5, 2 of 10, 4 of 20; rules v7–v8 ⌈n / 5⌉,
/// 1 of 4.
int weakSpotOperationCap(int questions, RulesVersion rules) =>
    rules.drawsWithoutRepeats ? questions ~/ 5 : (questions + 4) ~/ 5;

/// What is wrong with [items] as the weak spots of a Levelling game of
/// [sequence] at [levels] under [rules] (v7 on); `null` when nothing is:
/// each item of an operation the game plays, at a tier it belongs to
/// ([belongsTo] — the operation's current tier), once; within
/// [weakSpotGameCap] and [weakSpotOperationCap].
String? weakSpotProblem(
  List<Item> items,
  List<ExerciseType> sequence,
  Map<ExerciseType, Level> levels,
  RulesVersion rules,
) {
  final perOperation = <ExerciseType, int>{};
  for (final type in sequence) {
    perOperation[type] = (perOperation[type] ?? 0) + 1;
  }
  if (items.length > weakSpotGameCap(sequence.length)) {
    return '${items.length} weak spots in ${sequence.length} questions';
  }
  if (items.toSet().length != items.length) return 'an item twice';
  final used = <ExerciseType, int>{};
  for (final item in items) {
    final n = perOperation[item.type];
    final level = levels[item.type];
    if (n == null || level == null) {
      return '$item: ${item.type.name} is not played';
    }
    final tier = Tier.of(level);
    if (!belongsTo(item, tier, rules)) {
      return '$item is not ${tier.label} content';
    }
    used[item.type] = (used[item.type] ?? 0) + 1;
    if (used[item.type]! > weakSpotOperationCap(n, rules)) {
      return 'more than ${weakSpotOperationCap(n, rules)} weak spots of '
          '${item.type.name}';
    }
  }
  return null;
}

/// The weak spots of a new Levelling game under [rules] (v7 on): the [due]
/// items, the most urgent first, that belong to their operation's current
/// tier, as many as the caps allow — every choice passes
/// [weakSpotProblem].
List<Item> chooseWeakSpots({
  required List<Item> due,
  required List<ExerciseType> sequence,
  required Map<ExerciseType, Level> levels,
  required RulesVersion rules,
}) {
  final perOperation = <ExerciseType, int>{};
  for (final type in sequence) {
    perOperation[type] = (perOperation[type] ?? 0) + 1;
  }
  final cap = weakSpotGameCap(sequence.length);
  final chosen = <Item>[];
  final used = <ExerciseType, int>{};
  for (final item in due) {
    if (chosen.length >= cap) break;
    final n = perOperation[item.type];
    final level = levels[item.type];
    if (n == null || level == null) continue;
    if ((used[item.type] ?? 0) >= weakSpotOperationCap(n, rules)) continue;
    if (chosen.contains(item) || !belongsTo(item, Tier.of(level), rules)) {
      continue;
    }
    chosen.add(item);
    used[item.type] = (used[item.type] ?? 0) + 1;
  }
  return chosen;
}
