import 'package:math_core/method/method.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/patterns/pattern_family.dart';
import 'package:math_core/patterns/pattern_spaces_v9.dart';
import 'package:math_core/tiers/tier.dart';
import 'package:math_core/tiers/tip_band.dart';
import 'package:test/test.dart';

import 'method_pin_cases.dart';
import 'method_pins.dart';

/// `doc/levels.md` v1.6 section 9: "every family and fallback has a pinned
/// example per tier band whose lines are compared word for word" (Phase 6b
/// commit 3). The pins are what a player reads: a change to one is a change
/// to the Method, read and regenerated on purpose (`tool/method_pins.dart`),
/// never to make a test pass.
void main() {
  final cases = methodPinCases();

  test('every pinned Method reads exactly as pinned', () {
    expect(cases.keys.toSet(), methodPins.keys.toSet());
    for (final MapEntry(:key, :value) in methodPins.entries) {
      expect(cases[key], value, reason: key);
    }
  });

  test('a pin for every family in every band where rules v9 draws it', () {
    for (final family in PatternFamily.values) {
      for (final band in TipBand.values) {
        final drawn = [
          for (var t = band.low.index; t <= band.high.index; t++)
            if (t >= family.from.index &&
                familiesAtV9(family.type, Tier.values[t]).contains(family))
              t,
        ];
        expect(
          methodPins.containsKey('${family.name} | ${band.name}'),
          drawn.isNotEmpty,
          reason: '${family.name} ${band.name}',
        );
      }
    }
  });

  test("a fallback pin for every operation in every band", () {
    // Each fallback kind belongs to one operation; every operation has its
    // fallback pinned in each band.
    const kinds = <ExerciseType, List<MethodFallback>>{
      ExerciseType.addition: [
        MethodFallback.makeTen,
        MethodFallback.nearDouble,
        MethodFallback.countOn,
        MethodFallback.placeValue,
      ],
      ExerciseType.subtraction: [
        MethodFallback.thinkAddition,
        MethodFallback.countUp,
        MethodFallback.takeAwayInParts,
      ],
      ExerciseType.multiplication: [
        MethodFallback.timesOneOrTen,
        MethodFallback.fives,
        MethodFallback.repeatedAddition,
        MethodFallback.tensFirst,
        MethodFallback.splitFactor,
      ],
      ExerciseType.division: [
        MethodFallback.thinkMultiplication,
        MethodFallback.splitDividend,
      ],
      ExerciseType.power: [
        MethodFallback.nearestTen,
        MethodFallback.squareTens,
        MethodFallback.multiplyOut,
      ],
      ExerciseType.squareRoot: [
        MethodFallback.knownPower,
        MethodFallback.lastDigitBracket,
      ],
      ExerciseType.percentage: [
        MethodFallback.friendlyFraction,
        MethodFallback.wholeAndRest,
        MethodFallback.buildPercentage,
        MethodFallback.swapAndBuild,
      ],
      ExerciseType.integral: [MethodFallback.antiderivative],
    };
    expect({
      for (final list in kinds.values) ...list,
    }, MethodFallback.values.toSet()..remove(MethodFallback.productOver100));
    for (final MapEntry(key: type, value: list) in kinds.entries) {
      for (final band in TipBand.values) {
        expect(
          list.any((k) => methodPins.containsKey('${k.name} | ${band.name}')),
          isTrue,
          reason: '${type.name} ${band.name}',
        );
      }
    }
  });
}
