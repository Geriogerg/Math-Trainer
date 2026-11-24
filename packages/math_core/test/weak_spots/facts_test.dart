import 'package:math_core/models/exercise.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/models/operation_type.dart';
import 'package:math_core/patterns/pattern_family.dart';
import 'package:math_core/strategies/strategy.dart';
import 'package:math_core/tiers/tier.dart';
import 'package:math_core/weak_spots/facts.dart';
import 'package:math_core/weak_spots/item.dart';
import 'package:math_core/weak_spots/item_of.dart';
import 'package:test/test.dart';

ArithmeticExercise _op(int a, int b, OperationType op) =>
    ArithmeticExercise(operandA: a, operandB: b, operationType: op);

const _add = OperationType.addition;
const _sub = OperationType.subtraction;
const _mul = OperationType.multiplication;
const _div = OperationType.division;

void main() {
  group('the catalogue (plan v3.5, "Facts")', () {
    int count(ExerciseType type) =>
        allFacts.where((f) => f.type == type).length;

    test('holds the plan\'s list, one entry per commutative pair', () {
      // Bonds a + b ≤ 20 with a ≤ b: 100; complements to 100: 50.
      expect(count(ExerciseType.addition), 100 + 50);
      // s − a, 2 ≤ s ≤ 20 (190), and 100 − a (99).
      expect(count(ExerciseType.subtraction), 190 + 99);
      // 1–20 × 1–20, unordered: 20 · 21 / 2.
      expect(count(ExerciseType.multiplication), 210);
      // (a × b) ÷ b, ordered.
      expect(count(ExerciseType.division), 400);
      // 30 squares, 10 cubes, 2¹–2¹² without 2² and 2³ (already in).
      expect(count(ExerciseType.power), 30 + 10 + 10);
      // √ of 1²–30², 32², 64²; ∛ of 1³–10³.
      expect(count(ExerciseType.squareRoot), 32 + 10);
      expect(count(ExerciseType.integral), 0);
    });

    test('every fact is its own questions\' fact, and its key parses back', () {
      for (final fact in allFacts) {
        for (final exercise in exercisesOf(fact)) {
          expect(factOf(exercise), fact, reason: '$exercise');
        }
        expect(Item.parse(fact.key), fact);
      }
    });

    test('commutative facts merge; subtraction and division do not', () {
      expect(factOf(_op(7, 8, _mul)), factOf(_op(8, 7, _mul)));
      expect(factOf(_op(7, 8, _mul))!.key, 'fact:multiplication:7,8');
      expect(factOf(_op(8, 7, _add)), factOf(_op(7, 8, _add)));
      expect(exercisesOf(factOf(_op(8, 7, _mul))!), hasLength(2));
      expect(exercisesOf(factOf(_op(7, 7, _mul))!), hasLength(1));
      expect(factOf(_op(56, 8, _div)), isNot(factOf(_op(56, 7, _div))));
      expect(factOf(_op(15, 7, _sub)), isNot(factOf(_op(15, 8, _sub))));
    });

    test('questions outside the list are no facts', () {
      for (final exercise in <Exercise>[
        _op(13, 8, _add), // 21
        _op(37, 64, _add), // 101
        _op(21, 3, _mul),
        _op(42, 21, _div), // divisor 21
        _op(21, 1, _sub),
        _op(100, 100, _sub), // 0
        PowerExercise(base: 31, exponent: 2),
        PowerExercise(base: 11, exponent: 3),
        PowerExercise(base: 2, exponent: 13),
        PowerExercise(base: 3, exponent: 4),
        SquareRootExercise(radicand: 31 * 31),
        SquareRootExercise(radicand: 11 * 11 * 11, index: 3),
        PercentageExercise(percent: 25, base: 64), // not round
        PercentageExercise(percent: 15, base: 200),
        PercentageExercise(percent: 12, base: 64, tenths: 5),
        IntegralExercise(lower: 0, upper: 4, c0: 3, c1: 0, c2: 0, c3: 0),
        ArithmeticExercise(
          operandA: 2,
          operandB: 3,
          operandC: 4,
          operationType: _add,
        ),
      ]) {
        expect(factOf(exercise), isNull, reason: '$exercise');
      }
    });

    test('a key that is no item throws (rule 13)', () {
      for (final key in [
        'fact:multiplication:8,7', // not canonical
        'fact:multiplication:21,2',
        'fact:addition:7',
        'fact:integral:1,2',
        'fact:nothing:1,2',
        'skill:nothing',
        'skill',
        '',
      ]) {
        expect(() => Item.parse(key), throwsFormatException, reason: key);
      }
      expect(
        () => FactItem(ExerciseType.multiplication, [8, 7]),
        throwsArgumentError,
      );
      for (final family in PatternFamily.values) {
        expect(Item.parse('skill:${family.name}'), SkillItem(family));
      }
    });
  });

  group('the tiers of a fact', () {
    test(
      'every fact a tier draws is listed once, in a form the tier draws',
      () {
        for (final type in ExerciseType.values) {
          for (final tier in Tier.values) {
            final forms = factsAt(type, tier);
            expect(
              forms.toSet(),
              hasLength(forms.length),
              reason: '$type $tier',
            );
            for (final form in forms) {
              expect(formsAt(factOf(form)!, tier), contains(form));
            }
          }
        }
      },
    );

    test('7 × 8 is T1\'s, in both orders; 12 × 7 is T2\'s and T4\'s', () {
      final fact = factOf(_op(7, 8, _mul))!;
      expect(homeTier(fact), Tier.t1);
      expect(formsAt(fact, Tier.t1), [_op(7, 8, _mul), _op(8, 7, _mul)]);
      expect(formsAt(fact, Tier.t2), isEmpty);
      final twelve = factOf(_op(12, 7, _mul))!;
      expect(homeTier(twelve), Tier.t2);
      expect(formsAt(twelve, Tier.t4), [_op(12, 7, _mul)]);
      expect(formsAt(twelve, Tier.t3), isEmpty);
    });

    test('the facts no tier draws as a standard question', () {
      // Never keyed (a standard question is the only way to a fact), so
      // never scheduled: kept in the catalogue as the plan lists them.
      // Pinned so a change to section 5's tables shows here: 15 − 3 (no
      // borrow), 11 × 16 (T3's 16–25 × 2–9), 130 ÷ 10, 2¹¹, 10 % of 1 000…
      final untiered = <ExerciseType, int>{};
      for (final fact in allFacts) {
        if (homeTier(fact) == null) {
          untiered[fact.type] = (untiered[fact.type] ?? 0) + 1;
        }
      }
      expect(untiered, {
        ExerciseType.addition: 6, // 10 + 10 and the round complements
        ExerciseType.subtraction: 109,
        ExerciseType.multiplication: 4, // 1 × 16 … 1 × 19
        ExerciseType.division: 82,
        ExerciseType.power: 2, // 2¹¹, 2¹²
        ExerciseType.percentage: 5, // of 1 000
      });
      for (final key in [
        'fact:power:2,11',
        'fact:subtraction:15,3',
        'fact:percentage:25,1000',
      ]) {
        expect(homeTier(Item.parse(key) as FactItem), isNull, reason: key);
      }
      for (final key in [
        'fact:subtraction:15,7',
        'fact:subtraction:100,37',
        'fact:division:56,8',
        'fact:squareRoot:2,4096',
        'fact:percentage:75,980',
      ]) {
        expect(homeTier(Item.parse(key) as FactItem), isNotNull, reason: key);
      }
    });

    test('every tier from T0 to T2 has facts in every operation but '
        'integrals', () {
      for (final type in ExerciseType.values) {
        if (type == ExerciseType.integral) continue;
        for (final tier in [Tier.t0, Tier.t1, Tier.t2]) {
          expect(factsAt(type, tier), isNotEmpty, reason: '$type $tier');
        }
      }
    });
  });

  group('the item of a question', () {
    test('a pattern question is its family\'s skill, even fact-sized', () {
      expect(
        itemOf(
          PowerExercise(base: 2, exponent: 8),
          family: PatternFamily.powersOf2,
        ),
        SkillItem(PatternFamily.powersOf2),
      );
      expect(
        itemOf(
          _op(17, 23, _mul),
          family: PatternFamily.differenceOfSquares,
        )!.key,
        'skill:differenceOfSquares',
      );
    });

    test('a standard question: its fact first', () {
      expect(itemOf(_op(8, 7, _mul)), factOf(_op(7, 8, _mul)));
      // 8 + 7 is a bond, though compensation fits it.
      expect(itemOf(_op(8, 7, _add)), isA<FactItem>());
      // A fact no tier draws now (v2's tens + tens): never keyed as one.
      expect(itemOf(_op(30, 70, _add)), isNull);
      expect(itemOf(_op(15, 3, _sub)), isNull);
    });

    test('else its strategy\'s family; splitting a factor is untracked', () {
      expect(
        itemOf(_op(47, 68, _add)),
        SkillItem(PatternFamily.addJustBelowRound),
      );
      expect(
        itemOf(_op(603, 298, _sub)),
        SkillItem(PatternFamily.subtractJustBelowRound),
      );
      expect(
        itemOf(_op(47, 53, _mul)),
        SkillItem(PatternFamily.differenceOfSquares),
      );
      expect(
        itemOf(PowerExercise(base: 48, exponent: 2)),
        SkillItem(PatternFamily.squaresNear50And100),
      );
      expect(
        itemOf(PercentageExercise(percent: 8, base: 25)),
        SkillItem(PatternFamily.swap),
      );
      expect(itemOf(_op(7, 46, _mul)), isNull); // split factor
      expect(itemOf(_op(522, 6, _div)), isNull);
      expect(
        itemOf(
          IntegralExercise(lower: 0, upper: 4, c0: 3, c1: 0, c2: 0, c3: 0),
        ),
        isNull,
      );
    });

    test('every strategy but splitting a factor has a family of its '
        'operation', () {
      for (final strategy in Strategy.values) {
        final family = skillFamilyOf(strategy);
        if (strategy == Strategy.splitFactor) {
          expect(family, isNull);
        } else {
          expect(family, isNotNull, reason: '$strategy');
        }
      }
    });

    test('a family of another operation throws (rule 13)', () {
      expect(
        () => itemOf(_op(7, 8, _mul), family: PatternFamily.doubles),
        throwsArgumentError,
      );
    });
  });
}
