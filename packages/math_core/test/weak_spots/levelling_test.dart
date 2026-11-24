import 'package:math_core/generation/question_plan.dart';
import 'package:math_core/leveling/level.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/patterns/pattern_family.dart';
import 'package:math_core/tiers/tier.dart';
import 'package:math_core/weak_spots/facts.dart';
import 'package:math_core/weak_spots/item.dart';
import 'package:math_core/weak_spots/levelling.dart';
import 'package:test/test.dart';

const _mul = ExerciseType.multiplication;
const _add = ExerciseType.addition;

List<ExerciseType> _sequence(Map<ExerciseType, int> counts) => [
  for (final MapEntry(key: type, value: n) in counts.entries)
    for (var i = 0; i < n; i++) type,
];

void main() {
  final sevenEight = Item.parse('fact:multiplication:7,8');
  final twelveSeven = Item.parse('fact:multiplication:7,12');
  const squares = SkillItem(PatternFamily.differenceOfSquares);

  group('an item belongs to a tier (current tier only)', () {
    test('a fact: the tiers whose standard questions draw it', () {
      expect(
        [
          for (final t in Tier.values)
            if (belongsTo(sevenEight, t)) t,
        ],
        [Tier.t1],
      );
      expect(
        [
          for (final t in Tier.values)
            if (belongsTo(twelveSeven, t)) t,
        ],
        [Tier.t2, Tier.t4],
      );
    });

    test('a skill: every tier where its family is available', () {
      expect(
        [
          for (final t in Tier.values)
            if (belongsTo(squares, t)) t,
        ],
        [Tier.t5, Tier.t6, Tier.t7, Tier.t8, Tier.t9],
      );
    });

    test('every fact of the catalogue belongs exactly to the tiers listing '
        'it', () {
      for (final fact in allFacts) {
        for (final tier in Tier.values) {
          expect(
            belongsTo(fact, tier),
            factsAt(fact.type, tier).any((q) => factOf(q) == fact),
          );
        }
      }
    });
  });

  group('caps (plan v3.5: up to 20 %)', () {
    test('a game: ⌊N / 5⌋; an operation: ⌈n / 5⌉', () {
      expect(
        [
          for (final n in [4, 5, 8, 10, 16, 20, 80]) weakSpotGameCap(n),
        ],
        [0, 1, 1, 2, 3, 4, 16],
      );
      expect(
        [for (final n in questionsPerOperationChoices) weakSpotOperationCap(n)],
        [1, 1, 2, 4],
      );
    });

    test('never above 20 % of any game the setup allows', () {
      for (var ops = 1; ops <= 8; ops++) {
        for (final n in questionsPerOperationChoices) {
          final total = ops * n;
          expect(weakSpotGameCap(total) * 5, lessThanOrEqualTo(total));
        }
      }
    });
  });

  group('choosing a game\'s weak spots', () {
    test('only items of the current tier, most urgent first, within the '
        'caps', () {
      final sequence = _sequence({_mul: 10});
      // Level 15: T1. 12 × 7 is T2 and T4 content, the skill T5 on.
      final chosen = chooseWeakSpots(
        due: [twelveSeven, squares, sevenEight],
        sequence: sequence,
        levels: {_mul: Level.whole(15)},
      );
      expect(chosen, [sevenEight]);
      expect(
        weakSpotProblem(chosen, sequence, {_mul: Level.whole(15)}),
        isNull,
      );
      // Level 45: T4 — 12 × 7 yes, 7 × 8 no, the skill no.
      expect(
        chooseWeakSpots(
          due: [sevenEight, squares, twelveSeven],
          sequence: sequence,
          levels: {_mul: Level.whole(45)},
        ),
        [twelveSeven],
      );
    });

    test('a 4-question game gets none; 10 questions, at most 2', () {
      final t1Facts = {
        for (final q in factsAt(_mul, Tier.t1)) factOf(q)!,
      }.toList();
      expect(
        chooseWeakSpots(
          due: t1Facts,
          sequence: _sequence({_mul: 4}),
          levels: {_mul: Level.whole(12)},
        ),
        isEmpty,
      );
      expect(
        chooseWeakSpots(
          due: t1Facts,
          sequence: _sequence({_mul: 10}),
          levels: {_mul: Level.whole(12)},
        ),
        t1Facts.take(2),
      );
    });

    test('two operations of 4: one weak spot in the game, of either', () {
      final bond = Item.parse('fact:addition:7,8');
      final chosen = chooseWeakSpots(
        due: [bond, sevenEight],
        sequence: _sequence({_add: 4, _mul: 4}),
        levels: {_add: Level.whole(12), _mul: Level.whole(12)},
      );
      expect(chosen, [bond]);
    });

    test('an operation the game does not play is skipped', () {
      expect(
        chooseWeakSpots(
          due: [sevenEight],
          sequence: _sequence({_add: 10}),
          levels: {_add: Level.whole(15)},
        ),
        isEmpty,
      );
    });
  });

  group('a stored choice checked (the replay)', () {
    final sequence = _sequence({_mul: 10});
    final levels = {_mul: Level.whole(15)};

    test('a lower tier\'s item is refused', () {
      expect(
        weakSpotProblem([sevenEight], sequence, {_mul: Level.whole(25)}),
        contains('not T2 content'),
      );
    });

    test('over a cap, twice, another operation: refused', () {
      final t1 = {for (final q in factsAt(_mul, Tier.t1)) factOf(q)!}.toList();
      expect(weakSpotProblem(t1.take(3).toList(), sequence, levels), isNotNull);
      expect(
        weakSpotProblem([sevenEight, sevenEight], sequence, levels),
        isNotNull,
      );
      expect(
        weakSpotProblem([Item.parse('fact:addition:7,8')], sequence, levels),
        isNotNull,
      );
      expect(weakSpotProblem(t1.take(2).toList(), sequence, levels), isNull);
    });
  });
}
