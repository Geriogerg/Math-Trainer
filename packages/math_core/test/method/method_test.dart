import 'dart:math';

import 'package:math_core/method/method.dart';
import 'package:math_core/method/method_expr.dart';
import 'package:math_core/method/method_for.dart';
import 'package:math_core/models/exercise.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/models/operation_type.dart';
import 'package:math_core/patterns/pattern_family.dart';
import 'package:math_core/patterns/pattern_questions.dart';
import 'package:math_core/strategies/strategy.dart';
import 'package:math_core/tiers/tier.dart';
import 'package:math_core/tiers/tier_content.dart';
import 'package:test/test.dart';

/// A question whose answer is already on the screen (2¹): one line.
bool _trivial(Exercise e) => e is PowerExercise && e.exponent == 1;

void _expectSound(Method method, Exercise e, {String reason = ''}) {
  final problems = methodProblems(method, e);
  expect(problems, isEmpty, reason: '$reason $e\n${methodDebugText(method)}');
  expect(
    method.lines.length,
    inInclusiveRange(_trivial(e) ? 1 : 2, 4),
    reason: '$reason $e\n${methodDebugText(method)}',
  );
}

ArithmeticExercise _a(int a, int b, OperationType op) =>
    ArithmeticExercise(operandA: a, operandB: b, operationType: op);

void main() {
  group("every family's questions get the family's own Method, every line "
      'true, the last the answer (2,000 each)', () {
    for (final family in PatternFamily.values) {
      test(family.name, () {
        final random = Random(1000 + family.index);
        for (var i = 0; i < 2000; i++) {
          final q = patternQuestion(family, random);
          final method = methodFor(q, family: family);
          expect(method.family, family, reason: '$q');
          _expectSound(method, q, reason: family.name);
        }
      });
    }
  });

  group('every tier of every operation, as v4 and v2/v3 draw them: a sound '
      'Method for every question (3,000 each)', () {
    for (final type in ExerciseType.values) {
      test(type.name, () {
        for (final tier in Tier.values) {
          final random = Random(97 * type.index + tier.index);
          for (var i = 0; i < 3000; i++) {
            final v4 = patternedContent(type, tier, random);
            _expectSound(
              methodFor(v4.exercise, family: v4.family),
              v4.exercise,
              reason: 'v4 ${tier.label}',
            );
            final v2 = standardContent(type, tier, random).exercise;
            _expectSound(methodFor(v2), v2, reason: 'v2 ${tier.label}');
          }
        }
      });
    }
  });

  test("a standard question takes the detector's strategy when one fits, "
      'else the fallback', () {
    final random = Random(5);
    var strategies = 0;
    var fallbacks = 0;
    for (final type in ExerciseType.values) {
      for (final tier in Tier.values) {
        for (var i = 0; i < 300; i++) {
          final q = standardContent(type, tier, random).exercise;
          final method = methodFor(q);
          expect(method.family, isNull);
          final move = bestStrategy(q);
          final belowZero =
              move is SubtractViaRoundMove && move.minuend < move.rounded;
          expect(method.strategy, belowZero ? null : move?.strategy);
          if (method.isFallback) {
            fallbacks++;
          } else {
            strategies++;
          }
        }
      }
    }
    expect(strategies, greaterThan(0));
    expect(fallbacks, greaterThan(0));
  });

  group('the exit example and the layout', () {
    test('a missed 17 × 23 shows (20 − 3)(20 + 3)', () {
      final method = methodFor(
        _a(17, 23, OperationType.multiplication),
        family: PatternFamily.differenceOfSquares,
      );
      expect(
        methodDebugText(method),
        '= (20 − 3)(20 + 3)\n= 20^2 − 3^2\n= 400 − 9\n= 391',
      );
    });

    test('parentheses where precedence needs them or a group asks', () {
      expect(
        methodText(
          Bin(Op.divide, Group(Bin(Op.plus, Num(4000), Num(862))), Num(2)),
        ),
        '(4000 + 862) ÷ 2',
      );
      expect(
        methodText(Bin(Op.times, Bin(Op.divide, Num(64), Num(8)), Num(3))),
        '64 ÷ 8 × 3',
      );
      expect(
        methodText(Bin(Op.minus, Num(9), Bin(Op.plus, Num(1), Num(2)))),
        '9 − (1 + 2)',
      );
      expect(
        methodText(Bin(Op.plus, Num(9), Bin(Op.plus, Num(1), Num(2)))),
        '9 + 1 + 2',
      );
      expect(
        methodText(Bin(Op.times, Num(2), Bin(Op.plus, Num(1), Num(2)))),
        '2 × (1 + 2)',
      );
      expect(methodText(Pow(Num(20), 2)), '20^2');
      expect(methodText(RootOf(1331, index: 3)), '∛1331');
      expect(methodText(const PercentOf(25, 8)), '25 % of 8');
    });

    test('a few Methods as they read', () {
      String text(Exercise e, [PatternFamily? f]) =>
          methodDebugText(methodFor(e, family: f));
      expect(
        text(
          _a(65, 98, OperationType.addition),
          PatternFamily.addJustBelowRound,
        ),
        '= 65 + 100 − 2\n= 165 − 2\n= 163',
      );
      expect(
        text(_a(1000, 357, OperationType.subtraction), PatternFamily.fromRound),
        '= (999 − 357) + 1\n= 642 + 1\n= 643',
      );
      expect(
        text(
          _a(43, 47, OperationType.multiplication),
          PatternFamily.sameTensUnitsTo10,
        ),
        '= 4 × 5 × 100 + 3 × 7\n= 2000 + 21\n= 2021',
      );
      expect(
        text(_a(7344, 8, OperationType.division), PatternFamily.halvingChain),
        '7344 ÷ 2 = 3672\n3672 ÷ 2 = 1836\n1836 ÷ 2 = 918',
      );
      expect(
        text(SquareRootExercise(radicand: 7569)),
        '80^2 < 7569 < 90^2\n7^2 = 49\n85^2 = 7225 < 7569\n√7569 = 87',
      );
      expect(
        text(_a(2082, 6, OperationType.division)),
        '= (1800 + 282) ÷ 6\n= 300 + 47\n= 347',
      );
      expect(text(_a(28, 4, OperationType.division)), '4 × 7 = 28\n28 ÷ 4 = 7');
      expect(
        text(
          IntegralExercise(
            lower: 1,
            upper: 3,
            c0: 0,
            c1: 0,
            c2: -3,
            c3: 0,
            c4: 5,
          ),
        ),
        '= (3^5 − 3^3) − (1^5 − 1^3)\n= 216 − 0\n= 216',
      );
    });
  });

  test('an unsound line is caught: a false relation, a wrong end, an '
      'inexact step', () {
    final e = _a(2, 3, OperationType.addition);
    expect(
      methodProblems(
        Method(
          lines: [
            MethodLine.then([Num(6)]),
          ],
        ),
        e,
      ),
      isNotEmpty,
    );
    expect(
      methodProblems(
        Method(
          lines: [
            MethodLine.then([Bin(Op.divide, Num(11), Num(2))]),
            MethodLine.then([Num(5)]),
          ],
        ),
        e,
      ),
      isNotEmpty,
    );
    expect(
      methodProblems(
        Method(
          lines: [
            MethodLine.then([Bin(Op.plus, Num(2), Num(3))]),
            MethodLine.then([Num(5)]),
          ],
        ),
        e,
      ),
      isEmpty,
    );
    expect(
      () => MethodLine([Num(1)], const [Relation.equals]),
      throwsArgumentError,
    );
  });
}
