import 'dart:math';

import 'package:math_core/models/exercise.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/models/operation_type.dart';
import 'package:math_core/patterns/pattern_family.dart';
import 'package:math_core/patterns/pattern_questions.dart';
import 'package:math_core/patterns/pattern_questions_v4.dart';
import 'package:math_core/strategies/strategy.dart';
import 'package:math_core/tiers/tier.dart';
import 'package:math_core/tiers/tier_content.dart';
import 'package:test/test.dart';

bool _in(int n, int min, int max) => n >= min && n <= max;

bool _arith(
  Exercise e,
  OperationType op,
  bool Function(int a, int b) f, {
  bool third = false,
}) =>
    e is ArithmeticExercise &&
    e.operationType == op &&
    (e.operandC != null) == third &&
    f(e.operandA, e.operandB);

bool _add(Exercise e, bool Function(int a, int b) f) =>
    _arith(e, OperationType.addition, f);
bool _sub(Exercise e, bool Function(int a, int b) f) =>
    _arith(e, OperationType.subtraction, f);
bool _mul(Exercise e, bool Function(int a, int b) f) =>
    _arith(e, OperationType.multiplication, f);

/// A division as (quotient, divisor), exact.
bool _div(Exercise e, bool Function(int q, int d) f) =>
    _arith(e, OperationType.division, (a, d) => a % d == 0 && f(a ~/ d, d));

bool _pow(Exercise e, bool Function(int base, int exponent) f) =>
    e is PowerExercise && f(e.base, e.exponent);

/// A root as (root, index), the radicand its exact power.
bool _root(Exercise e, bool Function(int root, int index) f) =>
    e is SquareRootExercise &&
    _power(e.correctAnswer, e.index) == e.radicand &&
    f(e.correctAnswer, e.index);

bool _pct(Exercise e, bool Function(int percent, int base) f) =>
    e is PercentageExercise &&
    e.tenths == 0 &&
    e.percent * e.base % 100 == 0 &&
    f(e.percent, e.base);

/// ∫ of a single term `c·x^k` from [lower] to [upper].
bool _int(Exercise e, int k, int c, bool Function(int lower, int upper) f) =>
    e is IntegralExercise &&
    [
          for (var i = 0; i < 5; i++)
            if (e.coefficients[i] != 0) (i, e.coefficients[i]),
        ].toString() ==
        [(k, c)].toString() &&
    f(e.lower, e.upper);

int _power(int b, int n) {
  var r = 1;
  for (var i = 0; i < n; i++) {
    r *= b;
  }
  return r;
}

int _digits(int n) => '$n'.length;

bool _signedWithin(int d, int max) => d != 0 && d.abs() <= max;

/// The round number [b] sits 1 to [maxGap] below, if any.
int? _roundAbove(int b, int step, int maxGap) {
  for (var k = 1; k <= maxGap; k++) {
    if ((b + k) % step == 0) return b + k;
  }
  return null;
}

/// Each family's questions, as the spec describes them (section 5b) — the
/// exact support of its generator.
final Map<PatternFamily, bool Function(Exercise)> _support = {
  PatternFamily.doubles: (e) => _add(
    e,
    (a, b) =>
        _in(b - a, 0, 1) &&
        (_in(a, 6, 99) || (a % 10 == 0 && _in(a, 100, 500))),
  ),
  PatternFamily.complements: (e) => _add(
    e,
    (a, b) =>
        (a + b == 100 && _in(a, 11, 89) && a % 10 != 0) ||
        (a + b == 1000 && _in(a, 101, 899) && a % 100 != 0),
  ),
  PatternFamily.addJustBelowRound: (e) => _add(e, (a, b) {
    final round = _roundAbove(b, 100, 3);
    return _in(a, 10, 999) && round != null && _in(round, 100, 900);
  }),
  PatternFamily.roundNumbers: (e) => _add(
    e,
    (a, b) => [100, 1000, 10000].any(
      (u) =>
          a % u == 0 &&
          b % u == 0 &&
          _in(a ~/ u, 11, 99) &&
          _in(b ~/ u, 11, 99),
    ),
  ),
  PatternFamily.threeTerms: (e) =>
      _arith(e, OperationType.addition, third: true, (a, b) {
        final c = (e as ArithmeticExercise).operandC!;
        return a + c == 100 && _in(a, 11, 89) && a % 10 != 0 && _in(b, 11, 99);
      }),
  PatternFamily.addJustBelowPowerOf10: (e) => _add(
    e,
    (a, b) => [
      1000,
      10000,
      100000,
    ].any((p) => _in(p - b, 1, 3) && _in(a, p, 10 * p - 1)),
  ),
  PatternFamily.subtractJustBelowRound: (e) => _sub(e, (a, b) {
    final round = _roundAbove(b, 100, 4);
    if (round == null) return false;
    return (round <= 900 && _in(a, round, 999)) ||
        (round == 1000 && _in(a, 1000, 9999));
  }),
  PatternFamily.fromRound: (e) => _sub(
    e,
    (a, b) => (a == 1000 || a == 10000) && _in(b, 101, a - 1) && b % 10 != 0,
  ),
  PatternFamily.acrossRound: (e) => _sub(e, (a, b) {
    final round = _roundAbove(b, 100, 9);
    return round != null && _in(round, 100, 9900) && _in(a - round, 1, 9);
  }),
  PatternFamily.sameGapShift: (e) => _sub(e, (a, b) {
    final round = _roundAbove(b, 100, 9);
    return round != null && _in(round, 200, 900) && _in(a, round + 1, 999);
  }),
  PatternFamily.subtractJustBelowPowerOf10: (e) => _sub(
    e,
    (a, b) => [
      1000,
      10000,
      100000,
    ].any((p) => _in(p - b, 1, 3) && _in(a, p, 10 * p - 1)),
  ),
  PatternFamily.times5: (e) => _mul(
    e,
    (a, b) => (b == 5 && _in(a, 11, 9999)) || (b == 50 && _in(a, 11, 999)),
  ),
  PatternFamily.times11: (e) => _mul(e, (a, b) => b == 11 && _in(a, 12, 999)),
  PatternFamily.nearBase: (e) =>
      _mul(e, (a, b) => _signedWithin(a - 100, 5) && _in(b, 2, 9)),
  PatternFamily.times25: (e) =>
      _mul(e, (a, b) => (b == 25 || b == 125) && _in(a, 12, 99)),
  PatternFamily.differenceOfSquares: (e) => _mul(e, (a, b) {
    final middle = (a + b) ~/ 2;
    return (a + b).isEven &&
        middle % 10 == 0 &&
        _in(middle, 20, 90) &&
        _in((b - a) ~/ 2, 1, 9);
  }),
  PatternFamily.doublingHalving: (e) => _mul(
    e,
    (a, b) => a.isEven && _in(a, 12, 48) && b % 10 == 5 && _in(b, 15, 95),
  ),
  PatternFamily.times9s: (e) =>
      _mul(e, (a, b) => [9, 99, 999].contains(b) && _in(a, 12, 999)),
  PatternFamily.sameTensUnitsTo10: (e) => _mul(
    e,
    (a, b) =>
        a ~/ 10 == b ~/ 10 &&
        _in(a ~/ 10, 1, 9) &&
        _in(a % 10, 1, 9) &&
        a % 10 + b % 10 == 10,
  ),
  PatternFamily.times101: (e) => _mul(e, (a, b) => b == 101 && _in(a, 11, 99)),
  PatternFamily.powersOf2Product: (e) {
    final powers = [for (var i = 3; i <= 9; i++) _power(2, i)];
    return _mul(e, (a, b) => powers.contains(a) && powers.contains(b));
  },
  PatternFamily.bothNear100: (e) =>
      _mul(e, (a, b) => _signedWithin(a - 100, 9) && _signedWithin(b - 100, 9)),
  PatternFamily.differenceOfSquaresHundreds: (e) => _mul(e, (a, b) {
    final middle = (a + b) ~/ 2;
    return (a + b).isEven &&
        middle % 100 == 0 &&
        _in(middle, 100, 500) &&
        _in((b - a) ~/ 2, 1, 9);
  }),
  PatternFamily.halveBig: (e) => _div(e, (q, d) => d == 2 && _in(q, 500, 4999)),
  PatternFamily.roundDivision: (e) => _div(
    e,
    (q, d) =>
        ((d % 10 == 0 && _in(d ~/ 10, 2, 9)) ||
            (d % 100 == 0 && _in(d ~/ 100, 2, 9))) &&
        (_in(q, 2, 12) || (q % 10 == 0 && _in(q ~/ 10, 2, 12))),
  ),
  PatternFamily.bigBy3To5: (e) =>
      _div(e, (q, d) => _in(d, 3, 5) && _digits(q * d) == 6),
  PatternFamily.by25: (e) => _div(
    e,
    (q, d) => (d == 25 && _in(q, 40, 399)) || (d == 125 && _in(q, 8, 79)),
  ),
  PatternFamily.by11: (e) => _div(e, (q, d) => d == 11 && _in(q, 12, 99)),
  PatternFamily.halvingChain: (e) =>
      _div(e, (q, d) => (d == 8 || d == 16) && _digits(q * d) == 4),
  PatternFamily.bigBy6To9: (e) =>
      _div(e, (q, d) => _in(d, 6, 9) && _in(_digits(q * d), 4, 7)),
  PatternFamily.powersOf2: (e) => _pow(e, (b, n) => b == 2 && _in(n, 7, 20)),
  PatternFamily.squaresEndingIn5: (e) =>
      _pow(e, (b, n) => n == 2 && b % 10 == 5 && _in(b, 15, 195)),
  PatternFamily.powersOf3To5: (e) => _pow(
    e,
    (b, n) =>
        (b == 3 && _in(n, 4, 9)) ||
        (b == 4 && _in(n, 3, 7)) ||
        (b == 5 && _in(n, 3, 6)),
  ),
  PatternFamily.squaresNear50And100: (e) => _pow(
    e,
    (b, n) => n == 2 && (_signedWithin(b - 50, 5) || _signedWithin(b - 100, 5)),
  ),
  PatternFamily.repunits: (e) => _pow(
    e,
    (b, n) => [(11, 2), (11, 3), (11, 4), (111, 2), (1111, 2)].contains((b, n)),
  ),
  PatternFamily.squaresNear1000: (e) =>
      _pow(e, (b, n) => n == 2 && _signedWithin(b - 1000, 9)),
  PatternFamily.rootsOfPowersOf2: (e) => _root(
    e,
    (root, i) =>
        i == 2 && [for (var k = 4; k <= 10; k++) _power(2, k)].contains(root),
  ),
  PatternFamily.rootsEndingIn25: (e) =>
      _root(e, (root, i) => i == 2 && root % 10 == 5 && _in(root, 15, 195)),
  PatternFamily.rootsNear100: (e) =>
      _root(e, (root, i) => i == 2 && _signedWithin(root - 100, 9)),
  PatternFamily.cubeRootsRepunitAndRound: (e) => _root(
    e,
    (root, i) =>
        i == 3 && (root == 11 || (root % 10 == 0 && _in(root, 20, 90))),
  ),
  PatternFamily.rootsNear1000: (e) =>
      _root(e, (root, i) => i == 2 && _signedWithin(root - 1000, 9)),
  PatternFamily.halfAndQuarterOfBig: (e) => _pct(
    e,
    (p, b) =>
        (p == 50 && b.isEven && _in(b, 1000, 9998)) ||
        (p == 25 && b % 4 == 0 && _in(b, 1000, 9996)),
  ),
  PatternFamily.swap: (e) => _pct(
    e,
    (p, b) =>
        !friendlyPercentages.contains(p) &&
        ((b == 25 && p % 4 == 0 && _in(p, 4, 96)) ||
            (b == 50 && p.isEven && _in(p, 2, 98))),
  ),
  PatternFamily.percentOfBigRound: (e) => _pct(
    e,
    (p, b) =>
        p % 5 == 0 &&
        p != 50 &&
        _in(p, 5, 95) &&
        [1000, 10000, 100000].any((u) => b % u == 0 && _in(b ~/ u, 11, 99)),
  ),
  PatternFamily.nearHundredPercent: (e) => _pct(
    e,
    (p, b) =>
        ((p == 99 || p == 101) && b % 100 == 0 && _in(b, 100, 900)) ||
        (p == 125 && b % 4 == 0 && _in(b, 12, 200)) ||
        (p == 200 && _in(b, 11, 999)),
  ),
  PatternFamily.twoXFromZero: (e) =>
      _int(e, 1, 2, (lo, hi) => lo == 0 && _in(hi, 5, 20)),
  PatternFamily.threeXSquaredFromZero: (e) =>
      _int(e, 2, 3, (lo, hi) => lo == 0 && _in(hi, 2, 10)),
  PatternFamily.twoXDifferenceOfSquares: (e) => _int(e, 1, 2, (lo, hi) {
    final middle = (lo + hi) ~/ 2;
    return (lo + hi).isEven &&
        middle % 10 == 0 &&
        _in(middle, 10, 90) &&
        _in((hi - lo) ~/ 2, 1, 9);
  }),
  PatternFamily.fourXCubedFromZero: (e) =>
      _int(e, 3, 4, (lo, hi) => lo == 0 && _in(hi, 2, 9)),
};

ArithmeticExercise _a(int a, int b, OperationType op) =>
    ArithmeticExercise(operandA: a, operandB: b, operationType: op);

IntegralExercise _integral(
  int lo,
  int hi, {
  int c1 = 0,
  int c2 = 0,
  int c3 = 0,
}) => IntegralExercise(lower: lo, upper: hi, c0: 0, c1: c1, c2: c2, c3: c3);

const _add2 = OperationType.addition;
const _sub2 = OperationType.subtraction;
const _mul2 = OperationType.multiplication;
const _div2 = OperationType.division;

/// The spec's examples (section 5b), as the questions they are.
final Map<PatternFamily, List<Exercise>> _examples = {
  PatternFamily.doubles: [_a(48, 49, _add2), _a(250, 251, _add2)],
  PatternFamily.complements: [_a(37, 63, _add2), _a(418, 582, _add2)],
  PatternFamily.addJustBelowRound: [_a(65, 98, _add2), _a(347, 199, _add2)],
  PatternFamily.roundNumbers: [
    _a(3500, 4500, _add2),
    _a(250000, 750000, _add2),
  ],
  PatternFamily.threeTerms: [
    ArithmeticExercise(
      operandA: 27,
      operandB: 46,
      operandC: 73,
      operationType: OperationType.addition,
    ),
  ],
  PatternFamily.addJustBelowPowerOf10: [
    _a(4562, 998, _add2),
    _a(73845, 9999, _add2),
  ],
  PatternFamily.subtractJustBelowRound: [
    _a(742, 198, _sub2),
    _a(9856, 996, _sub2),
  ],
  PatternFamily.fromRound: [_a(1000, 357, _sub2), _a(10000, 2486, _sub2)],
  PatternFamily.acrossRound: [_a(5003, 4997, _sub2)],
  PatternFamily.sameGapShift: [_a(803, 497, _sub2)],
  PatternFamily.subtractJustBelowPowerOf10: [_a(84312, 9998, _sub2)],
  PatternFamily.times5: [_a(4864, 5, _mul2)],
  PatternFamily.times11: [_a(43, 11, _mul2), _a(352, 11, _mul2)],
  PatternFamily.nearBase: [_a(98, 7, _mul2), _a(103, 8, _mul2)],
  PatternFamily.times25: [_a(36, 25, _mul2), _a(88, 125, _mul2)],
  PatternFamily.differenceOfSquares: [_a(17, 23, _mul2), _a(47, 53, _mul2)],
  PatternFamily.doublingHalving: [_a(16, 35, _mul2)],
  PatternFamily.times9s: [_a(47, 99, _mul2), _a(236, 999, _mul2)],
  PatternFamily.sameTensUnitsTo10: [_a(43, 47, _mul2)],
  PatternFamily.times101: [_a(47, 101, _mul2)],
  PatternFamily.powersOf2Product: [_a(64, 32, _mul2)],
  PatternFamily.bothNear100: [_a(97, 96, _mul2), _a(98, 102, _mul2)],
  PatternFamily.differenceOfSquaresHundreds: [_a(195, 205, _mul2)],
  PatternFamily.halveBig: [_a(4862, 2, _div2)],
  PatternFamily.roundDivision: [_a(36000, 400, _div2)],
  PatternFamily.bigBy3To5: [_a(123456, 3, _div2), _a(864312, 4, _div2)],
  PatternFamily.by25: [_a(4875, 25, _div2)],
  PatternFamily.by11: [_a(473, 11, _div2)],
  PatternFamily.halvingChain: [_a(7344, 8, _div2)],
  PatternFamily.bigBy6To9: [_a(7254, 6, _div2), _a(2450245, 7, _div2)],
  PatternFamily.powersOf2: [
    const PowerExercise(base: 2, exponent: 10),
    const PowerExercise(base: 2, exponent: 16),
  ],
  PatternFamily.squaresEndingIn5: [
    const PowerExercise(base: 35, exponent: 2),
    const PowerExercise(base: 105, exponent: 2),
  ],
  PatternFamily.powersOf3To5: [
    const PowerExercise(base: 3, exponent: 8),
    const PowerExercise(base: 4, exponent: 5),
    const PowerExercise(base: 5, exponent: 4),
  ],
  PatternFamily.squaresNear50And100: [
    const PowerExercise(base: 48, exponent: 2),
    const PowerExercise(base: 103, exponent: 2),
  ],
  PatternFamily.repunits: [
    const PowerExercise(base: 111, exponent: 2),
    const PowerExercise(base: 11, exponent: 3),
  ],
  PatternFamily.squaresNear1000: [const PowerExercise(base: 997, exponent: 2)],
  PatternFamily.rootsOfPowersOf2: [
    SquareRootExercise(radicand: 1024),
    SquareRootExercise(radicand: 65536),
  ],
  PatternFamily.rootsEndingIn25: [SquareRootExercise(radicand: 7225)],
  PatternFamily.rootsNear100: [SquareRootExercise(radicand: 10201)],
  PatternFamily.cubeRootsRepunitAndRound: [
    SquareRootExercise(radicand: 1331, index: 3),
    SquareRootExercise(radicand: 8000, index: 3),
  ],
  PatternFamily.rootsNear1000: [SquareRootExercise(radicand: 994009)],
  PatternFamily.halfAndQuarterOfBig: [
    PercentageExercise(percent: 50, base: 9876),
    PercentageExercise(percent: 25, base: 4864),
  ],
  PatternFamily.swap: [
    PercentageExercise(percent: 8, base: 25),
    PercentageExercise(percent: 12, base: 50),
  ],
  PatternFamily.percentOfBigRound: [
    PercentageExercise(percent: 15, base: 2400000),
  ],
  PatternFamily.nearHundredPercent: [
    PercentageExercise(percent: 99, base: 300),
    PercentageExercise(percent: 125, base: 64),
  ],
  PatternFamily.twoXFromZero: [_integral(0, 9, c1: 2)],
  PatternFamily.threeXSquaredFromZero: [_integral(0, 5, c2: 3)],
  PatternFamily.twoXDifferenceOfSquares: [_integral(19, 21, c1: 2)],
  PatternFamily.fourXCubedFromZero: [_integral(0, 3, c3: 4)],
};

/// Each family's kind of question at any size (rules v5 sizes them by tier;
/// the sizes themselves are the spec-conformance test's): the shape that
/// makes the shortcut work, nothing about how big.
final _kind = <PatternFamily, bool Function(Exercise)>{
  PatternFamily.doubles: (e) => _add(e, (a, b) => _in(b - a, 0, 1)),
  PatternFamily.complements: (e) =>
      _add(e, (a, b) => _isPowerOf10(a + b) && a + b >= 100),
  PatternFamily.addJustBelowRound: (e) =>
      _add(e, (a, b) => _justBelowRound(b, 3)),
  PatternFamily.roundNumbers: (e) => _add(
    e,
    (a, b) =>
        a % 10 == 0 &&
        b % 10 == 0 &&
        _significant(a) <= 2 &&
        _significant(b) <= 2,
  ),
  PatternFamily.threeTerms: (e) =>
      e is ArithmeticExercise &&
      e.operandC != null &&
      _isPowerOf10(e.operandA + e.operandC!) &&
      e.operandA + e.operandC! >= 100,
  PatternFamily.addJustBelowPowerOf10: (e) =>
      _add(e, (a, b) => _in(_nextPowerOf10(b) - b, 1, 3) && a > b),
  PatternFamily.subtractJustBelowRound: (e) =>
      _sub(e, (a, b) => _justBelowRound(b, 4) && a > b),
  PatternFamily.fromRound: (e) =>
      _sub(e, (a, b) => _isPowerOf10(a) && b % 10 != 0 && b < a),
  PatternFamily.acrossRound: (e) => _sub(e, (a, b) {
    final round = _roundAbove(b, 100, 9);
    return round != null && _in(a - round, 1, 9);
  }),
  PatternFamily.sameGapShift: (e) =>
      _sub(e, (a, b) => _justBelowRound(b, 9) && a > b),
  PatternFamily.subtractJustBelowPowerOf10: (e) =>
      _sub(e, (a, b) => _in(_nextPowerOf10(b) - b, 1, 3) && a > b),
  PatternFamily.times5: (e) => _mul(e, (a, b) => b == 5 || b == 50),
  PatternFamily.times11: (e) => _mul(e, (a, b) => b == 11),
  PatternFamily.nearBase: (e) => _mul(
    e,
    (a, b) =>
        (_signedWithin(a - 100, 9) || _signedWithin(a - 1000, 9)) &&
        _in(b, 2, 19),
  ),
  PatternFamily.times25: (e) => _mul(e, (a, b) => b == 25 || b == 125),
  PatternFamily.differenceOfSquares: (e) => _mul(e, (a, b) {
    final middle = (a + b) ~/ 2;
    return (a + b).isEven && middle % 10 == 0 && _in((b - a) ~/ 2, 1, 9);
  }),
  PatternFamily.doublingHalving: (e) =>
      _mul(e, (a, b) => a.isEven && b % 10 == 5),
  PatternFamily.times9s: (e) => _mul(e, (a, b) => [9, 99, 999].contains(b)),
  PatternFamily.sameTensUnitsTo10: (e) => _mul(
    e,
    (a, b) => a ~/ 10 == b ~/ 10 && _in(a % 10, 1, 9) && a % 10 + b % 10 == 10,
  ),
  PatternFamily.times101: (e) => _mul(e, (a, b) => b == 101),
  PatternFamily.powersOf2Product: (e) =>
      _mul(e, (a, b) => a >= 8 && b >= 8 && _isPowerOf2(a) && _isPowerOf2(b)),
  PatternFamily.bothNear100: (e) =>
      _mul(e, (a, b) => _signedWithin(a - 100, 9) && _signedWithin(b - 100, 9)),
  PatternFamily.differenceOfSquaresHundreds: (e) => _mul(e, (a, b) {
    final middle = (a + b) ~/ 2;
    return (a + b).isEven && middle % 100 == 0 && _in((b - a) ~/ 2, 1, 9);
  }),
  PatternFamily.halveBig: (e) => _div(e, (q, d) => d == 2),
  PatternFamily.roundDivision: (e) => _div(
    e,
    (q, d) => d % 10 == 0 && _significant(d) == 1 && _significant(q) <= 2,
  ),
  PatternFamily.bigBy3To5: (e) => _div(e, (q, d) => _in(d, 3, 5)),
  PatternFamily.by25: (e) => _div(e, (q, d) => d == 25 || d == 125),
  PatternFamily.by11: (e) => _div(e, (q, d) => d == 11),
  PatternFamily.halvingChain: (e) => _div(e, (q, d) => d == 8 || d == 16),
  PatternFamily.bigBy6To9: (e) => _div(e, (q, d) => _in(d, 6, 9)),
  PatternFamily.powersOf2: (e) => _pow(e, (b, n) => b == 2),
  PatternFamily.squaresEndingIn5: (e) =>
      _pow(e, (b, n) => n == 2 && b % 10 == 5),
  PatternFamily.powersOf3To5: (e) => _pow(e, (b, n) => _in(b, 3, 5)),
  PatternFamily.squaresNear50And100: (e) => _pow(
    e,
    (b, n) => n == 2 && (_signedWithin(b - 50, 9) || _signedWithin(b - 100, 9)),
  ),
  PatternFamily.repunits: (e) => _pow(e, (b, n) => [11, 111, 1111].contains(b)),
  PatternFamily.squaresNear1000: (e) =>
      _pow(e, (b, n) => n == 2 && _signedWithin(b - 1000, 9)),
  PatternFamily.rootsOfPowersOf2: (e) =>
      _root(e, (root, i) => i == 2 && _isPowerOf2(root)),
  PatternFamily.rootsEndingIn25: (e) =>
      _root(e, (root, i) => i == 2 && root % 10 == 5),
  PatternFamily.rootsNear100: (e) =>
      _root(e, (root, i) => i == 2 && _signedWithin(root - 100, 9)),
  PatternFamily.cubeRootsRepunitAndRound: (e) =>
      _root(e, (root, i) => i == 3 && (root == 11 || root % 10 == 0)),
  PatternFamily.rootsNear1000: (e) =>
      _root(e, (root, i) => i == 2 && _signedWithin(root - 1000, 9)),
  PatternFamily.halfAndQuarterOfBig: (e) =>
      _pct(e, (p, b) => p == 50 || p == 25),
  PatternFamily.swap: (e) => _pct(e, (p, b) => b == 25 || b == 50),
  PatternFamily.percentOfBigRound: (e) => _pct(
    e,
    (p, b) => p % 5 == 0 && p != 50 && b % 100 == 0 && _significant(b) <= 2,
  ),
  PatternFamily.nearHundredPercent: (e) =>
      _pct(e, (p, b) => [99, 101, 125, 200].contains(p)),
  PatternFamily.twoXFromZero: (e) => _int(e, 1, 2, (lo, hi) => lo == 0),
  PatternFamily.threeXSquaredFromZero: (e) =>
      _int(e, 2, 3, (lo, hi) => lo == 0),
  PatternFamily.twoXDifferenceOfSquares: (e) => _int(e, 1, 2, (lo, hi) {
    final middle = (lo + hi) ~/ 2;
    return (lo + hi).isEven && middle % 10 == 0 && _in((hi - lo) ~/ 2, 1, 9);
  }),
  PatternFamily.fourXCubedFromZero: (e) => _int(e, 3, 4, (lo, hi) => lo == 0),
};

bool _isPowerOf10(int n) {
  if (n < 1) return false;
  while (n % 10 == 0) {
    n ~/= 10;
  }
  return n == 1;
}

bool _isPowerOf2(int n) => n > 0 && n & (n - 1) == 0;

int _nextPowerOf10(int n) {
  var p = 1;
  while (p <= n) {
    p *= 10;
  }
  return p;
}

/// 98, 199, 3 997, 28: [maxGap] or less below a round number m × 10ᵏ.
bool _justBelowRound(int n, int maxGap) {
  for (var k = 1; k <= maxGap; k++) {
    final round = n + k;
    var unit = 1;
    while (unit * 10 <= round) {
      unit *= 10;
    }
    if (round >= 10 && round % unit == 0) return true;
  }
  return false;
}

int _significant(int n) {
  var m = n.abs();
  if (m == 0) return 1;
  while (m % 10 == 0) {
    m ~/= 10;
  }
  return _digits(m);
}

/// The spec's "From" column (section 5b, v1.4: √ of powers of 2 from T3;
/// rules v4 drew it from T2).
const _from = {
  PatternFamily.doubles: 1,
  PatternFamily.complements: 2,
  PatternFamily.addJustBelowRound: 2,
  PatternFamily.roundNumbers: 3,
  PatternFamily.threeTerms: 4,
  PatternFamily.addJustBelowPowerOf10: 5,
  PatternFamily.subtractJustBelowRound: 3,
  PatternFamily.fromRound: 4,
  PatternFamily.acrossRound: 4,
  PatternFamily.sameGapShift: 5,
  PatternFamily.subtractJustBelowPowerOf10: 6,
  PatternFamily.times5: 2,
  PatternFamily.times11: 3,
  PatternFamily.nearBase: 4,
  PatternFamily.times25: 5,
  PatternFamily.differenceOfSquares: 5,
  PatternFamily.doublingHalving: 5,
  PatternFamily.times9s: 5,
  PatternFamily.sameTensUnitsTo10: 6,
  PatternFamily.times101: 6,
  PatternFamily.powersOf2Product: 6,
  PatternFamily.bothNear100: 7,
  PatternFamily.differenceOfSquaresHundreds: 9,
  PatternFamily.halveBig: 2,
  PatternFamily.roundDivision: 4,
  PatternFamily.bigBy3To5: 5,
  PatternFamily.by25: 5,
  PatternFamily.by11: 6,
  PatternFamily.halvingChain: 6,
  PatternFamily.bigBy6To9: 7,
  PatternFamily.powersOf2: 1,
  PatternFamily.squaresEndingIn5: 3,
  PatternFamily.powersOf3To5: 4,
  PatternFamily.squaresNear50And100: 5,
  PatternFamily.repunits: 6,
  PatternFamily.squaresNear1000: 9,
  PatternFamily.rootsOfPowersOf2: 3,
  PatternFamily.rootsEndingIn25: 3,
  PatternFamily.rootsNear100: 5,
  PatternFamily.cubeRootsRepunitAndRound: 6,
  PatternFamily.rootsNear1000: 9,
  PatternFamily.halfAndQuarterOfBig: 2,
  PatternFamily.swap: 3,
  PatternFamily.percentOfBigRound: 5,
  PatternFamily.nearHundredPercent: 7,
  PatternFamily.twoXFromZero: 1,
  PatternFamily.threeXSquaredFromZero: 4,
  PatternFamily.twoXDifferenceOfSquares: 5,
  PatternFamily.fourXCubedFromZero: 7,
};

void main() {
  test("the spec's families: 6 + 5 + 12 + 7 + 6 + 5 + 4 + 4, each from its "
      'tier, of its operation', () {
    expect(PatternFamily.values, hasLength(49));
    for (final family in PatternFamily.values) {
      expect(family.from.index, _from[family], reason: family.name);
    }
    final perType = {
      for (final t in ExerciseType.values)
        t: PatternFamily.values.where((f) => f.type == t).length,
    };
    expect(perType, {
      ExerciseType.addition: 6,
      ExerciseType.subtraction: 5,
      ExerciseType.multiplication: 12,
      ExerciseType.division: 7,
      ExerciseType.power: 6,
      ExerciseType.squareRoot: 5,
      ExerciseType.percentage: 4,
      ExerciseType.integral: 4,
    });
  });

  group("every family's examples are its kind of question", () {
    for (final family in PatternFamily.values) {
      test(family.name, () {
        final examples = _examples[family]!;
        expect(examples, isNotEmpty);
        for (final e in examples) {
          expect(e.type, family.type);
          expect(_support[family]!(e), isTrue, reason: 'v4: $e');
          expect(_kind[family]!(e), isTrue, reason: 'v5: $e');
        }
      });
    }
  });

  test("v4 questions are their family's kind too: _kind is only looser "
      'about size (1,000 draws a family)', () {
    for (final family in PatternFamily.values) {
      final random = Random(family.index);
      for (var i = 0; i < 1000; i++) {
        final e = patternQuestionV4(family, random);
        expect(_kind[family]!(e), isTrue, reason: '${family.name}: $e');
      }
    }
  });

  group('v4: every family generates only its kind, whole and exact, at most '
      '10 digits (3,000 draws)', () {
    for (final family in PatternFamily.values) {
      test(family.name, () {
        final random = Random(family.index + 1);
        final seen = <Exercise>{};
        for (var i = 0; i < 3000; i++) {
          final e = patternQuestionV4(family, random);
          seen.add(e);
          expect(e.type, family.type);
          expect(_support[family]!(e), isTrue, reason: '$e');
          expect(e.correctAnswer, greaterThan(0), reason: '$e');
          expect(e.correctAnswer, lessThan(10000000000), reason: '$e');
        }
        // Not one question over and over (repunits has exactly 5).
        expect(seen.length, greaterThanOrEqualTo(5));
      });
    }
  });

  group('rules v4 content', () {
    test('v4 drew √ of powers of 2 from T2, v5 from T3', () {
      expect(PatternFamily.availableAtV4(ExerciseType.squareRoot, Tier.t2), [
        PatternFamily.rootsOfPowersOf2,
      ]);
      expect(
        PatternFamily.availableAt(ExerciseType.squareRoot, Tier.t2),
        isEmpty,
      );
      for (final family in PatternFamily.values) {
        if (family == PatternFamily.rootsOfPowersOf2) continue;
        for (final tier in Tier.values) {
          expect(
            PatternFamily.availableAtV4(family.type, tier).contains(family),
            PatternFamily.availableAt(family.type, tier).contains(family),
          );
        }
      }
    });

    test('families are available from their tier on, in the spec order', () {
      expect(
        PatternFamily.availableAt(ExerciseType.addition, Tier.t0),
        isEmpty,
      );
      expect(PatternFamily.availableAt(ExerciseType.addition, Tier.t2), [
        PatternFamily.doubles,
        PatternFamily.complements,
        PatternFamily.addJustBelowRound,
      ]);
      expect(
        PatternFamily.availableAt(ExerciseType.multiplication, Tier.t9),
        hasLength(12),
      );
    });

    test('about 40 % pattern questions where a family is available, none '
        'where none is; only available families (10,000 draws a tier)', () {
      for (final type in ExerciseType.values) {
        for (final tier in Tier.values) {
          final random = Random(31 * type.index + tier.index);
          var patterns = 0;
          for (var i = 0; i < 10000; i++) {
            final q = patternedContent(type, tier, random);
            expect(q.exercise.type, type);
            final family = q.family;
            if (family == null) continue;
            patterns++;
            expect(family.type, type);
            expect(PatternFamily.availableAtV4(type, tier), contains(family));
            expect(_support[family]!(q.exercise), isTrue);
          }
          final share = patterns / 10000;
          if (PatternFamily.availableAtV4(type, tier).isEmpty) {
            expect(share, 0, reason: '${type.name} ${tier.label}');
          } else {
            expect(
              share,
              inInclusiveRange(0.38, 0.42),
              reason: '${type.name} ${tier.label}',
            );
          }
        }
      }
    });
  });
  group(
    'rules v6 (current): every family at every tier from its first generates only '
    'its kind, whole and exact, at most 10 digits (3,000 draws a tier)',
    () {
      for (final family in PatternFamily.values) {
        test(family.name, () {
          for (final tier in Tier.values.skip(family.from.index)) {
            final random = Random(100 * family.index + tier.index);
            final seen = <Exercise>{};
            for (var i = 0; i < 3000; i++) {
              final e = patternQuestion(family, tier, random);
              seen.add(e);
              final reason = '${tier.label} $e';
              expect(e.type, family.type, reason: reason);
              expect(_kind[family]!(e), isTrue, reason: reason);
              expect(e.correctAnswer, greaterThan(0), reason: reason);
              expect(e.correctAnswer, lessThan(10000000000), reason: reason);
            }
            // √ of powers of 2 has one question in each of its bands but the
            // last (√64 at T3–T4, the mirror of 2⁵–2⁶).
            expect(seen, isNotEmpty);
          }
        });
      }
    },
  );

  test('rules v6: a family drawn below its first tier throws (rule 13)', () {
    for (final family in PatternFamily.values) {
      for (final tier in Tier.values.take(family.from.index)) {
        expect(
          () => patternQuestion(family, tier, Random(1)),
          throwsArgumentError,
          reason: '${family.name} ${tier.label}',
        );
      }
    }
  });

  test('rules v6: a family grows with the tier — the digits of its smallest '
      'and of its largest question never shrink from one tier to the next '
      '(2,000 draws a tier)', () {
    for (final family in PatternFamily.values) {
      int? lastLow;
      int? lastHigh;
      for (final tier in Tier.values.skip(family.from.index)) {
        final random = Random(7 * family.index + tier.index);
        var low = 1 << 40;
        var high = 0;
        for (var i = 0; i < 2000; i++) {
          final size = _digits(_size(patternQuestion(family, tier, random)));
          low = min(low, size);
          high = max(high, size);
        }
        final reason = '${family.name} ${tier.label}';
        if (lastLow != null) {
          expect(low, greaterThanOrEqualTo(lastLow), reason: reason);
          expect(high, greaterThanOrEqualTo(lastHigh!), reason: reason);
        }
        lastLow = low;
        lastHigh = high;
      }
    }
  });

  test('rules v5: about 40 % pattern questions at every tier where a family '
      'is available — its first included — none where none is (10,000 '
      'draws a tier)', () {
    for (final type in ExerciseType.values) {
      for (final tier in Tier.values) {
        final random = Random(37 * type.index + tier.index);
        var patterns = 0;
        for (var i = 0; i < 10000; i++) {
          final q = patternedContentV5(type, tier, random);
          expect(q.exercise.type, type);
          final family = q.family;
          if (family == null) continue;
          patterns++;
          expect(PatternFamily.availableAt(type, tier), contains(family));
        }
        final share = patterns / 10000;
        final reason = '${type.name} ${tier.label}';
        if (PatternFamily.availableAt(type, tier).isEmpty) {
          expect(share, 0, reason: reason);
        } else {
          expect(share, inInclusiveRange(0.38, 0.42), reason: reason);
        }
      }
    }
  });
}

/// A question's size: the largest number it shows or answers (a power's
/// value, a root's radicand).
int _size(Exercise e) => switch (e) {
  ArithmeticExercise(:final operandA, :final operandB, :final operandC) => [
    operandA,
    operandB,
    ?operandC,
    e.correctAnswer,
  ].reduce(max),
  PowerExercise() => e.correctAnswer,
  SquareRootExercise(:final radicand) => radicand,
  PercentageExercise(:final base) => max(base, e.correctAnswer),
  IntegralExercise(:final upper) => max(upper, e.correctAnswer),
};
