import '../leveling/level.dart';
import '../models/exercise_type.dart';
import '../patterns/pattern_family.dart';
import '../tiers/tier.dart';
import 'facts.dart';
import 'item.dart';

/// Whether [item] can be asked at [tier] of its operation (`doc/decisions.md`,
/// "Phase 4"): a fact that tier's standard questions draw ([formsAt]), a
/// skill whose family is available there. The rule behind "weak-spot
/// questions only from the player's current tier".
bool belongsTo(Item item, Tier tier) => switch (item) {
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
/// game: ⌈n / 5⌉ — 1 of 4 or 5, 2 of 10, 4 of 20.
int weakSpotOperationCap(int questions) => (questions + 4) ~/ 5;

/// What is wrong with [items] as the weak spots of a Levelling game of
/// [sequence] at [levels] (rules v7); `null` when nothing is: each item of
/// an operation the game plays, at a tier it belongs to ([belongsTo] — the
/// operation's current tier), once; within [weakSpotGameCap] and
/// [weakSpotOperationCap].
String? weakSpotProblem(
  List<Item> items,
  List<ExerciseType> sequence,
  Map<ExerciseType, Level> levels,
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
    if (!belongsTo(item, tier)) return '$item is not ${tier.label} content';
    used[item.type] = (used[item.type] ?? 0) + 1;
    if (used[item.type]! > weakSpotOperationCap(n)) {
      return 'more than ${weakSpotOperationCap(n)} weak spots of '
          '${item.type.name}';
    }
  }
  return null;
}

/// The weak spots of a new Levelling game (rules v7): the [due] items, the
/// most urgent first, that belong to their operation's current tier, as
/// many as the caps allow — every choice passes [weakSpotProblem].
List<Item> chooseWeakSpots({
  required List<Item> due,
  required List<ExerciseType> sequence,
  required Map<ExerciseType, Level> levels,
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
    if ((used[item.type] ?? 0) >= weakSpotOperationCap(n)) continue;
    if (chosen.contains(item) || !belongsTo(item, Tier.of(level))) continue;
    chosen.add(item);
    used[item.type] = (used[item.type] ?? 0) + 1;
  }
  return chosen;
}
