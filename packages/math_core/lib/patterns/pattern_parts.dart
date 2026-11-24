import 'dart:math';

import '../models/exercise.dart';
import '../models/operation_type.dart';
import '../strategies/strategy.dart';
import '../tiers/draw.dart';

// The parts pattern questions are built from (`doc/levels.md` section 5b),
// shared by rules v4 (`patternQuestionV4`) and v5 (`patternQuestion`).
// A change here moves v4's questions: its pinned references
// (`test/tiers/tier_references_v4.dart`) catch it.

ArithmeticExercise sumOf(int a, int b) => ArithmeticExercise(
  operandA: a,
  operandB: b,
  operationType: OperationType.addition,
);

/// 27 + 46 + 73: [a] and [c] complements, [b] between them.
ArithmeticExercise threeTermsOf(int a, int b, int c) => ArithmeticExercise(
  operandA: a,
  operandB: b,
  operandC: c,
  operationType: OperationType.addition,
);

ArithmeticExercise differenceOf(int a, int b) => ArithmeticExercise(
  operandA: a,
  operandB: b,
  operationType: OperationType.subtraction,
);

ArithmeticExercise productOf(int a, int b) => ArithmeticExercise(
  operandA: a,
  operandB: b,
  operationType: OperationType.multiplication,
);

/// [divisor] × [quotient] ÷ [divisor]: exact by construction.
ArithmeticExercise quotientOf(int divisor, int quotient) => ArithmeticExercise(
  operandA: divisor * quotient,
  operandB: divisor,
  operationType: OperationType.division,
);

SquareRootExercise squareRootOf(int root) =>
    SquareRootExercise(radicand: root * root);

IntegralExercise integralOf(
  int lower,
  int upper, {
  int c1 = 0,
  int c2 = 0,
  int c3 = 0,
}) =>
    IntegralExercise(lower: lower, upper: upper, c0: 0, c1: c1, c2: c2, c3: c3);

/// 1 to [max] away from 0, either side.
int drawSigned(Random r, int max) =>
    drawCoin(r) ? drawBetween(r, 1, max) : -drawBetween(r, 1, max);

int powerOf2(int exponent) {
  var p = 1;
  for (var i = 0; i < exponent; i++) {
    p *= 2;
  }
  return p;
}

/// A quotient that makes `divisor × quotient` exactly [digits] digits long.
int quotientWithDigits(Random r, int divisor, int digits) {
  var low = 1;
  for (var i = 1; i < digits; i++) {
    low *= 10;
  }
  return drawBetween(
    r,
    (low + divisor - 1) ~/ divisor,
    (10 * low - 1) ~/ divisor,
  );
}

/// Percentages whose swap with 25 % or 50 % is whole and not already a
/// friendly one (8 % of 25 = 25 % of 8).
final swapWith25 = [
  for (var p = 4; p <= 96; p += 4)
    if (!friendlyPercentages.contains(p)) p,
];
final swapWith50 = [
  for (var p = 2; p <= 98; p += 2)
    if (!friendlyPercentages.contains(p)) p,
];

/// 5 %, 15 % … 95 %, but 50 % (a half is the T2 family's).
final multiplesOf5 = [
  for (var p = 5; p <= 95; p += 5)
    if (p != 50) p,
];

/// 10^[exponent], by multiplication (rule 18: no `pow`).
int pow10(int exponent) {
  var p = 1;
  for (var i = 0; i < exponent; i++) {
    p *= 10;
  }
  return p;
}
