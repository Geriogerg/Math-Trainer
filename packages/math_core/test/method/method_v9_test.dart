import 'dart:math';

import 'package:math_core/method/method.dart';
import 'package:math_core/method/method_expr.dart';
import 'package:math_core/method/method_for.dart';
import 'package:math_core/models/exercise.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/models/operation_type.dart';
import 'package:math_core/patterns/pattern_family.dart';
import 'package:math_core/patterns/pattern_spaces_v9.dart';
import 'package:math_core/strategies/strategy.dart';
import 'package:math_core/tiers/question_space.dart';
import 'package:math_core/tiers/standard_v9.dart';
import 'package:math_core/tiers/tier.dart';
import 'package:test/test.dart';

/// `doc/levels.md` v1.6 section 9, "A method must make the question easier"
/// (Phase 6b commit 3, review M11), on the questions rules v9 draws.

/// Up to [n] questions of [space]: all of a listed one (capped), else drawn.
List<Exercise> _questions(QuestionSpace space, {int n = 3000}) {
  if (space.approximateDistinct <= listLimit) {
    final all = space.questions;
    if (all.length <= n) return all;
    final step = all.length / n;
    return [for (var i = 0; i < n; i++) all[(i * step).floor()]];
  }
  final random = Random(11);
  return [for (var i = 0; i < n; i++) space.draw(random, const {})];
}

int _significant(int n) {
  var m = n.abs();
  if (m == 0) return 1;
  while (m % 10 == 0) {
    m ~/= 10;
  }
  return '$m'.length;
}

/// The numbers a question shows, and its answer.
List<int> _questionNumbers(Exercise e) => [
  ...switch (e) {
    ArithmeticExercise(:final operandA, :final operandB, :final operandC) => [
      operandA,
      operandB,
      ?operandC,
    ],
    PowerExercise(:final base) => [base],
    SquareRootExercise(:final radicand) => [radicand],
    PercentageExercise(:final percent, :final base) => [percent, base],
    IntegralExercise(:final lower, :final upper, :final coefficients) => [
      lower,
      upper,
      for (final c in coefficients)
        if (c != 0) c,
    ],
  },
  e.correctAnswer,
];

/// What is wrong with [m] for [e] beyond arithmetic truth; `null` if
/// nothing: no number in a line with more significant digits than the
/// question's largest number or its answer, plus one — the answer counted
/// by its length (a round answer is not a smaller question: ∫₁⁷ 4x³ dx =
/// 2 401 − 1 = 2 400).
String? _tooLarge(Method m, Exercise e) {
  final limit =
      max(
        _questionNumbers(e).map(_significant).reduce(max),
        '${e.correctAnswer.abs()}'.length,
      ) +
      1;
  for (final line in m.lines) {
    for (final term in line.terms) {
      for (final token in exprTokens(term)) {
        if (token is NumberToken && _significant(token.value) > limit) {
          return '${token.value} has more than $limit significant digits';
        }
      }
    }
  }
  return null;
}

void _expectGood(Method m, Exercise e, String reason) {
  expect(
    methodProblems(m, e),
    isEmpty,
    reason: '$reason $e\n${methodDebugText(m)}',
  );
  expect(_tooLarge(m, e), isNull, reason: '$reason $e\n${methodDebugText(m)}');
}

ArithmeticExercise _op(int a, int b, OperationType op) =>
    ArithmeticExercise(operandA: a, operandB: b, operationType: op);

void main() {
  group("every family at every tier v9 draws it: the family's own Method, "
      'every line true, no number larger than the question allows', () {
    for (final family in PatternFamily.values) {
      test(family.name, () {
        for (final tier in Tier.values.skip(family.from.index)) {
          if (!familiesAtV9(family.type, tier).contains(family)) continue;
          for (final q in _questions(familySpaceV9(family, tier))) {
            final m = methodFor(q, family: family);
            expect(m.family, family, reason: '${tier.label}: $q');
            _expectGood(m, q, '${family.name} ${tier.label}');
          }
        }
      });
    }
  });

  group('every standard question of every v9 tier: a sound Method, no '
      'number larger than the question allows, a named fallback', () {
    for (final type in ExerciseType.values) {
      test(type.name, () {
        for (final tier in Tier.values) {
          for (final q in _questions(standardSpaceV9(type, tier))) {
            final m = methodFor(q);
            _expectGood(m, q, '${type.name} ${tier.label}');
            expect(m.isFallback, m.fallback != null, reason: '$q');
            // "never p × base ÷ 100" (v1.6).
            expect(m.fallback, isNot(MethodFallback.productOver100));
          }
        }
      });
    }
  });

  group('a strategy only where it makes the question easier', () {
    test('compensation: a number of two digits or more, within 3 of a '
        'one-significant-digit number — 47 + 68 yes; 7 + 2 and 4 157 + '
        '9 449 no', () {
      expect(
        methodFor(_op(47, 68, OperationType.addition)).strategy,
        Strategy.compensation,
      );
      expect(methodFor(_op(7, 2, OperationType.addition)).strategy, isNull);
      expect(
        methodFor(_op(4157, 9449, OperationType.addition)).strategy,
        isNull,
      );
      expect(
        offersMethod(
          const CompensationMove(kept: 2, rounded: 10, adjustment: 3),
        ),
        isFalse,
      );
    });

    test('no step that restates the question: 10 − 7 is not 10 − 10 + 3; '
        '742 − 198 is 742 − 200 + 2', () {
      final restated = methodFor(_op(10, 7, OperationType.subtraction));
      expect(restated.strategy, isNull);
      expect(restated.fallback, MethodFallback.thinkAddition);
      expect(
        methodFor(_op(742, 198, OperationType.subtraction)).strategy,
        Strategy.subtractViaRound,
      );
    });
  });

  // The review's examples (M11) and spec v1.6's, word for word.
  group('the examples, word for word', () {
    String text(Exercise e, {PatternFamily? family}) =>
        methodDebugText(methodFor(e, family: family));

    test('near a base: 1 009 × 16 from 1 000, not from 100', () {
      expect(
        text(
          _op(1009, 16, OperationType.multiplication),
          family: PatternFamily.nearBase,
        ),
        '= (1000 + 9) × 16\n= 16000 + 144\n= 16144',
      );
      expect(
        text(
          _op(98, 7, OperationType.multiplication),
          family: PatternFamily.nearBase,
        ),
        '= (100 − 2) × 7\n= 700 − 14\n= 686',
      );
    });

    test('long division: parts divisible at sight, down to the answer', () {
      expect(
        text(_op(5104, 4, OperationType.division)),
        '= 4000 ÷ 4 + 1000 ÷ 4 + 104 ÷ 4\n= 1000 + 250 + 26\n= 1276',
      );
      expect(
        text(_op(522, 6, OperationType.division)),
        '= 480 ÷ 6 + 42 ÷ 6\n= 80 + 7\n= 87',
      );
      expect(
        text(_op(56, 8, OperationType.division)),
        '8 × 7 = 56\n56 ÷ 8 = 7',
      );
    });

    test('compensation where it simplifies, place value where it does not', () {
      expect(
        text(_op(47, 68, OperationType.addition)),
        '= 47 + 70 − 2\n= 117 − 2\n= 115',
      );
      expect(text(_op(7, 2, OperationType.addition)), '= 7 + 1 + 1\n= 9');
      expect(
        text(_op(4157, 9449, OperationType.addition)),
        '= (4000 + 9000) + (157 + 449)\n= 13000 + 606\n= 13606',
      );
      expect(
        text(_op(10, 7, OperationType.subtraction)),
        '7 + 3 = 10\n10 − 7 = 3',
      );
    });

    test('percentages built from 50 %, 25 %, 10 %, 5 % and 1 %, never '
        'p × base ÷ 100', () {
      expect(
        text(PercentageExercise(percent: 35, base: 140)),
        '= 25 % of 140 + 10 % of 140\n= 35 + 14\n= 49',
      );
      expect(
        text(PercentageExercise(percent: 64, base: 175)),
        '= 175 % of 64\n= 64 + 50 % of 64 + 25 % of 64\n= 64 + 32 + 16\n= 112',
      );
    });

    test('the name matches the lines: 2³ is multiplied out, not from the '
        'nearest ten; a split dividend is not "think of the '
        'multiplication"', () {
      expect(
        methodFor(const PowerExercise(base: 2, exponent: 3)).fallback,
        MethodFallback.multiplyOut,
      );
      expect(
        methodFor(_op(2082, 6, OperationType.division)).fallback,
        MethodFallback.splitDividend,
      );
      expect(
        methodFor(_op(56, 8, OperationType.division)).fallback,
        MethodFallback.thinkMultiplication,
      );
    });
  });
}
