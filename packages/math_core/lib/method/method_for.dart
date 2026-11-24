import '../models/exercise.dart';
import '../models/operation_type.dart';
import '../patterns/pattern_family.dart';
import '../strategies/strategy.dart';
import 'method.dart';
import 'method_expr.dart';

/// The Method for [exercise] (`doc/levels.md` section 9): the pattern
/// [family]'s own strategy for a pattern question (its family recomputed by
/// replay, never guessed), else the detector's best strategy
/// ([bestStrategy]), else the operation's fallback — so every question has
/// one. Integers only; every line checked by `methodProblems` in tests.
Method methodFor(Exercise exercise, {PatternFamily? family}) {
  if (family != null) {
    final lines = _familyLines(family, exercise);
    if (lines != null) return Method(lines: lines, family: family);
  }
  final move = bestStrategy(exercise);
  // 9 − 8 as 9 − 10 + 2 would pass below zero: no shortcut there.
  final belowZero = move is SubtractViaRoundMove && move.minuend < move.rounded;
  if (move != null && !belowZero) {
    return Method(lines: _strategyLines(move), strategy: move.strategy);
  }
  return Method(lines: _fallback(exercise));
}

// ── Building blocks ──────────────────────────────────────────────────────

Expr _x(Object o) => switch (o) {
  final int n => Num(n),
  final Expr e => e,
  _ => throw ArgumentError.value(o, 'term', 'is not an int or an Expr.'),
};

Expr _add(Object a, Object b) => Bin(Op.plus, _x(a), _x(b));
Expr _sub(Object a, Object b) => Bin(Op.minus, _x(a), _x(b));
Expr _mul(Object a, Object b) => Bin(Op.times, _x(a), _x(b));
Expr _div(Object a, Object b) => Bin(Op.divide, _x(a), _x(b));
Expr _group(Object e) => Group(_x(e));
Expr _pow(int base, int exponent) => Pow(Num(base), exponent);

/// A sum of [parts], left to right; one part is itself.
Expr _sum(List<Object> parts) =>
    parts.skip(1).fold(_x(parts.first), (acc, p) => _add(acc, p));

/// "= a = b …" following on.
MethodLine _then(List<Object> terms) =>
    MethodLine.then([for (final t in terms) _x(t)]);

/// "a = b …" standing alone.
MethodLine _eq(List<Object> terms) =>
    MethodLine.equal([for (final t in terms) _x(t)]);

/// "a < b < c".
MethodLine _lt(List<Object> terms) => MethodLine(
  [for (final t in terms) _x(t)],
  [for (var i = 1; i < terms.length; i++) Relation.lessThan],
);

int _power(int b, int n) {
  var r = 1;
  for (var i = 0; i < n; i++) {
    r *= b;
  }
  return r;
}

/// The largest power of 10 not above [n] (n ≥ 1).
int _placeOf(int n) {
  var p = 1;
  while (p * 10 <= n) {
    p *= 10;
  }
  return p;
}

/// The round number [n] sits 1 to [maxGap] below (a multiple of [step]).
bool _isPowerOf10(int n) {
  if (n < 1) return false;
  while (n % 10 == 0) {
    n ~/= 10;
  }
  return n == 1;
}

int? _roundAbove(int n, int step, int maxGap) {
  for (var k = 1; k <= maxGap; k++) {
    if ((n + k) % step == 0) return n + k;
  }
  return null;
}

// ── Shared moves ─────────────────────────────────────────────────────────

/// a + (R − k) = a + R − k: add the round number, give back the gap.
List<MethodLine> _addViaRound(int kept, int round, int gap) => [
  _then([_sub(_add(kept, round), gap)]),
  _then([_sub(kept + round, gap)]),
  _then([kept + round - gap]),
];

/// a − (R ∓ k) = a − R ± k: take off the round number, correct the gap.
List<MethodLine> _subtractViaRound(int minuend, int round, int correction) {
  final back = correction >= 0
      ? _add(_sub(minuend, round), correction)
      : _sub(_sub(minuend, round), -correction);
  final next = correction >= 0
      ? _add(minuend - round, correction)
      : _sub(minuend - round, -correction);
  return [
    _then([back]),
    _then([next]),
    _then([minuend - round + correction]),
  ];
}

/// (m − g)(m + g) = m² − g².
List<MethodLine> _differenceOfSquares(int middle, int gap) => [
  _then([_mul(_group(_sub(middle, gap)), _group(_add(middle, gap)))]),
  _then([_sub(_pow(middle, 2), _pow(gap, 2))]),
  _then([_sub(middle * middle, gap * gap)]),
  _then([middle * middle - gap * gap]),
];

/// (B ± d)² = B² ± 2 × B × d + d², d > 0, the lines after "n² ".
List<Expr> _squareNear(int base, int offset) {
  final d = offset.abs();
  final cross = _mul(_mul(2, base), d);
  final first = offset > 0
      ? _add(_pow(base, 2), cross)
      : _sub(_pow(base, 2), cross);
  final second = offset > 0
      ? _add(base * base, 2 * base * d)
      : _sub(base * base, 2 * base * d);
  return [_add(first, _pow(d, 2)), _add(second, d * d)];
}

/// n² from the nearest base: three lines.
List<MethodLine> _squareFromBase(int base, int offset) {
  final [symbolic, numbers] = _squareNear(base, offset);
  final n = base + offset;
  return [
    _then([symbolic]),
    _then([numbers]),
    _then([n * n]),
  ];
}

/// root² written from its base, the square, then √: three lines.
List<MethodLine> _rootFromBase(int radicand, int base, int offset) {
  final root = base + offset;
  final [symbolic, _] = _squareNear(base, offset);
  return [
    _eq([_pow(root, 2), symbolic]),
    _then([radicand]),
    _eq([RootOf(radicand), root]),
  ];
}

/// a ÷ d by splitting the dividend along the quotient's leading place:
/// (d·q1 + d·q2) ÷ d = q1 + q2. A one-digit quotient: the multiplication
/// first.
List<MethodLine> _splitDividend(int dividend, int divisor) {
  final q = dividend ~/ divisor;
  final place = _placeOf(q);
  final q1 = q - q % place;
  final q2 = q % place;
  if (q < 10 || q2 == 0) {
    return [
      _eq([_mul(divisor, q), dividend]),
      _eq([_div(dividend, divisor), q]),
    ];
  }
  return [
    _then([_div(_group(_add(divisor * q1, divisor * q2)), divisor)]),
    _then([_add(q1, q2)]),
    _then([q]),
  ];
}

/// ∫ₐᵇ p(x) dx as F(b) − F(a), F the antiderivative with whole
/// coefficients (`IntegralExercise`'s invariant).
List<MethodLine> _antiderivative(IntegralExercise e) {
  // F's terms, highest power first: (coefficient, power).
  final terms = <(int, int)>[
    for (var k = 4; k >= 0; k--)
      if (e.coefficients[k] != 0) (e.coefficients[k] ~/ (k + 1), k + 1),
  ];
  Expr term(int coefficient, int power, int x) {
    final xp = power == 1 ? Num(x) : _pow(x, power);
    return coefficient.abs() == 1 ? xp : _mul(coefficient.abs(), xp);
  }

  Expr f(int x) {
    var expr = term(terms.first.$1, terms.first.$2, x);
    for (final (c, p) in terms.skip(1)) {
      expr = c > 0 ? _add(expr, term(c, p, x)) : _sub(expr, term(c, p, x));
    }
    return expr;
  }

  int fValue(int x) {
    var v = 0;
    for (final (c, p) in terms) {
      v += c * _power(x, p);
    }
    return v;
  }

  final fb = fValue(e.upper);
  final fa = fValue(e.lower);
  if (e.lower == 0) {
    return [
      _then([f(e.upper)]),
      _then([fb]),
    ];
  }
  return [
    _then([_sub(_group(f(e.upper)), _group(f(e.lower)))]),
    _then([fa >= 0 ? _sub(fb, fa) : _add(fb, -fa)]),
    _then([fb - fa]),
  ];
}

// ── The families (doc/levels.md section 5b) ──────────────────────────────

/// [family]'s own lines for [e]; `null` when [e] is not that family's kind
/// (a replay never gives one, but a caller might).
List<MethodLine>? _familyLines(PatternFamily family, Exercise e) {
  if (e.type != family.type) return null;
  return switch (e) {
    ArithmeticExercise() => _arithmeticFamily(family, e),
    PowerExercise() => _powerFamily(family, e),
    SquareRootExercise() => _rootFamily(family, e),
    PercentageExercise() => _percentageFamily(family, e),
    IntegralExercise() => _integralFamily(family, e),
  };
}

List<MethodLine>? _arithmeticFamily(
  PatternFamily family,
  ArithmeticExercise e,
) {
  final a = e.operandA;
  final b = e.operandB;
  final answer = e.correctAnswer;
  switch (family) {
    case PatternFamily.doubles:
      if ((b - a).abs() > 1) return null;
      final small = a < b ? a : b;
      if (a == b) {
        return [
          _then([_mul(2, a)]),
          _then([answer]),
        ];
      }
      return [
        _then([_add(_mul(2, small), 1)]),
        _then([_add(2 * small, 1)]),
        _then([answer]),
      ];
    case PatternFamily.complements:
      // 37 + 63 = 100, 418 + 582 = 1 000 … any power of 10 (rules v5
      // sizes them by tier).
      final unit = answer ~/ 10;
      if (answer < 100 || !_isPowerOf10(answer)) return null;
      final ra = a % unit;
      final rb = b % unit;
      return [
        _then([_add(_group(_add(a - ra, b - rb)), _group(_add(ra, rb)))]),
        _then([_add(a - ra + b - rb, ra + rb)]),
        _then([answer]),
      ];
    case PatternFamily.addJustBelowRound:
    case PatternFamily.addJustBelowPowerOf10:
      // 98 → 100 (v4); 28 → 30 at T2 under v5.
      final step = family == PatternFamily.addJustBelowRound ? 100 : 1000;
      final round = _roundAbove(b, step, 3) ?? _roundAbove(b, 10, 3);
      if (round == null) return null;
      return _addViaRound(a, round, round - b);
    case PatternFamily.roundNumbers:
      // 3 500 + 4 500 by hundreds; 350 + 450 by tens (T3) up to
      // 25 000 000 + 75 000 000 (T9) under v5.
      // The largest unit both share.
      for (final unit in [10000000, 1000000, 100000, 10000, 1000, 100, 10]) {
        if (a % unit == 0 && b % unit == 0) {
          return [
            _then([_mul(_group(_add(a ~/ unit, b ~/ unit)), unit)]),
            _then([_mul((a + b) ~/ unit, unit)]),
            _then([answer]),
          ];
        }
      }
      return null;
    case PatternFamily.threeTerms:
      // 27 + 46 + 73: a + c = 100; 1 000 and up from T6 under v5.
      final c = e.operandC;
      if (c == null || a + c < 100 || !_isPowerOf10(a + c)) return null;
      return [
        _then([_add(_group(_add(a, c)), b)]),
        _then([_add(a + c, b)]),
        _then([answer]),
      ];
    case PatternFamily.subtractJustBelowRound:
    case PatternFamily.subtractJustBelowPowerOf10:
      final step = family == PatternFamily.subtractJustBelowRound ? 100 : 1000;
      final round = _roundAbove(b, step, 4);
      if (round == null) return null;
      return _subtractViaRound(a, round, round - b);
    case PatternFamily.fromRound:
      // 1 000 − 357 = (999 − 357) + 1: no borrow at all.
      return [
        _then([_add(_group(_sub(a - 1, b)), 1)]),
        _then([_add(a - 1 - b, 1)]),
        _then([answer]),
      ];
    case PatternFamily.acrossRound:
      final round = _roundAbove(b, 100, 9);
      if (round == null || a <= round) return null;
      return [
        _then([_add(_group(_sub(round, b)), _group(_sub(a, round)))]),
        _then([_add(round - b, a - round)]),
        _then([answer]),
      ];
    case PatternFamily.sameGapShift:
      final round = _roundAbove(b, 100, 9);
      if (round == null) return null;
      final k = round - b;
      return [
        _then([_sub(_group(_add(a, k)), _group(_add(b, k)))]),
        _then([_sub(a + k, round)]),
        _then([answer]),
      ];
    case PatternFamily.times5:
      // × 5 = × 10 ÷ 2; × 50 = × 100 ÷ 2.
      final round = b * 2;
      return [
        _then([_div(_mul(a, round), 2)]),
        _then([_div(a * round, 2)]),
        _then([answer]),
      ];
    case PatternFamily.times11:
      return [
        _then([_add(_mul(a, 10), a)]),
        _then([_add(a * 10, a)]),
        _then([answer]),
      ];
    case PatternFamily.nearBase:
      final offset = a - 100;
      final d = offset.abs();
      return [
        _then([_mul(_group(offset > 0 ? _add(100, d) : _sub(100, d)), b)]),
        _then([offset > 0 ? _add(100 * b, d * b) : _sub(100 * b, d * b)]),
        _then([answer]),
      ];
    case PatternFamily.times25:
      // × 25 = × 100 ÷ 4; × 125 = × 1 000 ÷ 8.
      final (round, by) = b == 25 ? (100, 4) : (1000, 8);
      return [
        _then([_div(_mul(a, round), by)]),
        _then([_div(a * round, by)]),
        _then([answer]),
      ];
    case PatternFamily.differenceOfSquares:
    case PatternFamily.differenceOfSquaresHundreds:
      if ((a + b).isOdd || a == b) return null;
      final lo = a < b ? a : b;
      final hi = a < b ? b : a;
      return _differenceOfSquares((lo + hi) ~/ 2, (hi - lo) ~/ 2);
    case PatternFamily.doublingHalving:
      final (even, five) = a.isEven ? (a, b) : (b, a);
      if (even.isOdd) return null;
      return [
        _then([_mul(even ~/ 2, five * 2)]),
        _then([answer]),
      ];
    case PatternFamily.times9s:
      final round = b + 1;
      return [
        _then([_sub(_mul(a, round), a)]),
        _then([_sub(a * round, a)]),
        _then([answer]),
      ];
    case PatternFamily.sameTensUnitsTo10:
      final tens = a ~/ 10;
      return [
        _then([_add(_mul(_mul(tens, tens + 1), 100), _mul(a % 10, b % 10))]),
        _then([_add(tens * (tens + 1) * 100, (a % 10) * (b % 10))]),
        _then([answer]),
      ];
    case PatternFamily.times101:
      return [
        _then([_add(_mul(a, 100), a)]),
        _then([_add(a * 100, a)]),
        _then([answer]),
      ];
    case PatternFamily.powersOf2Product:
      final i = _log2(a);
      final j = _log2(b);
      if (i == null || j == null) return null;
      return [
        _then([_mul(_pow(2, i), _pow(2, j))]),
        _then([_pow(2, i + j)]),
        _then([answer]),
      ];
    case PatternFamily.bothNear100:
      final d1 = a - 100;
      final d2 = b - 100;
      final shifted = d2 >= 0 ? _add(a, d2) : _sub(a, -d2);
      final product = d1 * d2;
      final corr = _mul(d1.abs(), d2.abs());
      return [
        _then([
          product >= 0
              ? _add(_mul(100, _group(shifted)), corr)
              : _sub(_mul(100, _group(shifted)), corr),
        ]),
        _then([
          product >= 0
              ? _add(100 * (a + d2), product)
              : _sub(100 * (a + d2), -product),
        ]),
        _then([answer]),
      ];
    case PatternFamily.halveBig:
    case PatternFamily.bigBy3To5:
    case PatternFamily.bigBy6To9:
      return _splitDividend(a, b);
    case PatternFamily.roundDivision:
      var x = a;
      var y = b;
      while (x % 10 == 0 && y % 10 == 0) {
        x ~/= 10;
        y ~/= 10;
      }
      return [
        _then([_div(x, y)]),
        _then([answer]),
      ];
    case PatternFamily.by25:
      final (by, round) = b == 25 ? (4, 100) : (8, 1000);
      return [
        _then([_div(_mul(a, by), round)]),
        _then([_div(a * by, round)]),
        _then([answer]),
      ];
    case PatternFamily.by11:
      return [
        _eq([_mul(answer, 11), _add(answer * 10, answer), a]),
        _eq([_div(a, 11), answer]),
      ];
    case PatternFamily.halvingChain:
      if (b == 8) {
        return [
          _eq([_div(a, 2), a ~/ 2]),
          _eq([_div(a ~/ 2, 2), a ~/ 4]),
          _eq([_div(a ~/ 4, 2), answer]),
        ];
      }
      return [
        _eq([_div(_div(a, 2), 2), a ~/ 4]),
        _eq([_div(_div(a ~/ 4, 2), 2), answer]),
      ];
    default:
      // Another operation's family: `_familyLines` never asks. A new
      // family of this operation fails the Method tests until it has lines.
      return null;
  }
}

int? _log2(int n) {
  var k = 0;
  var p = 1;
  while (p < n) {
    p *= 2;
    k++;
  }
  return p == n ? k : null;
}

List<MethodLine>? _powerFamily(PatternFamily family, PowerExercise e) {
  final n = e.base;
  final x = e.exponent;
  final answer = e.correctAnswer;
  switch (family) {
    case PatternFamily.powersOf2:
      if (n != 2) return null;
      if (x <= 10) {
        return [
          _then([_mul(_pow(2, x - 1), 2)]),
          _then([_mul(_power(2, x - 1), 2)]),
          _then([answer]),
        ];
      }
      return [
        _then([_mul(_pow(2, 10), _pow(2, x - 10))]),
        _then([_mul(1024, _power(2, x - 10))]),
        _then([answer]),
      ];
    case PatternFamily.squaresEndingIn5:
      if (x != 2 || n % 10 != 5) return null;
      final t = n ~/ 10;
      return [
        _then([_add(_mul(_mul(t, t + 1), 100), 25)]),
        _then([_add(t * (t + 1) * 100, 25)]),
        _then([answer]),
      ];
    case PatternFamily.powersOf3To5:
      if (n == 4) {
        return [
          _then([_pow(2, 2 * x)]),
          _then([answer]),
        ];
      }
      final h = x ~/ 2;
      return [
        _then([_mul(_pow(n, h), _pow(n, x - h))]),
        _then([_mul(_power(n, h), _power(n, x - h))]),
        _then([answer]),
      ];
    case PatternFamily.squaresNear50And100:
    case PatternFamily.squaresNear1000:
      if (x != 2) return null;
      final base = family == PatternFamily.squaresNear1000
          ? 1000
          : (n < 75 ? 50 : 100);
      if (n == base) return null;
      return _squareFromBase(base, n - base);
    case PatternFamily.repunits:
      if (n == 11) {
        if (x == 2) {
          return [
            _then([_add(110, 11)]),
            _then([answer]),
          ];
        }
        final before = _power(11, x - 1);
        return [
          _then([_mul(before, 11)]),
          _then([_add(before * 10, before)]),
          _then([answer]),
        ];
      }
      // 111² = 11 100 + 1 110 + 111: n × n, digit by digit of the repunit.
      final digits = '$n'.length;
      return [
        _then([
          _sum([for (var i = digits - 1; i >= 0; i--) n * _power(10, i)]),
        ]),
        _then([answer]),
      ];
    default:
      // Another operation's family: `_familyLines` never asks. A new
      // family of this operation fails the Method tests until it has lines.
      return null;
  }
}

List<MethodLine>? _rootFamily(PatternFamily family, SquareRootExercise e) {
  final r = e.correctAnswer;
  final radicand = e.radicand;
  switch (family) {
    case PatternFamily.rootsOfPowersOf2:
      final k = _log2(r);
      if (k == null || e.index != 2) return null;
      return [
        _eq([radicand, _pow(2, 2 * k)]),
        _eq([RootOf(radicand), _pow(2, k)]),
        _then([r]),
      ];
    case PatternFamily.rootsEndingIn25:
      if (e.index != 2 || r % 10 != 5) return null;
      final t = r ~/ 10;
      return [
        _eq([_pow(r, 2), _add(_mul(_mul(t, t + 1), 100), 25)]),
        _then([radicand]),
        _eq([RootOf(radicand), r]),
      ];
    case PatternFamily.rootsNear100:
    case PatternFamily.rootsNear1000:
      final base = family == PatternFamily.rootsNear100 ? 100 : 1000;
      if (e.index != 2 || r == base) return null;
      return _rootFromBase(radicand, base, r - base);
    case PatternFamily.cubeRootsRepunitAndRound:
      if (e.index != 3) return null;
      if (r % 10 == 0) {
        return [
          _eq([_pow(r, 3), _mul(_pow(r ~/ 10, 3), 1000)]),
          _then([radicand]),
          _eq([RootOf(radicand, index: 3), r]),
        ];
      }
      return [
        _eq([_pow(r, 3), _mul(r * r, r)]),
        _then([radicand]),
        _eq([RootOf(radicand, index: 3), r]),
      ];
    default:
      // Another operation's family: `_familyLines` never asks. A new
      // family of this operation fails the Method tests until it has lines.
      return null;
  }
}

List<MethodLine>? _percentageFamily(
  PatternFamily family,
  PercentageExercise e,
) {
  final p = e.percent;
  final base = e.base;
  final answer = e.correctAnswer;
  if (e.tenths != 0) return null;
  switch (family) {
    case PatternFamily.halfAndQuarterOfBig:
      if (p == 50) {
        return [
          _then([_div(base, 2)]),
          _then([answer]),
        ];
      }
      if (p != 25) return null;
      return [
        _then([_div(_div(base, 2), 2)]),
        _then([_div(base ~/ 2, 2)]),
        _then([answer]),
      ];
    case PatternFamily.swap:
      return [
        _then([PercentOf(base, p)]),
        _then([_div(p, 100 ~/ base)]),
        _then([answer]),
      ];
    case PatternFamily.percentOfBigRound:
      return _fromTensFivesOnes(p, base);
    case PatternFamily.nearHundredPercent:
      return switch (p) {
        99 => [
          _then([_sub(base, base ~/ 100)]),
          _then([answer]),
        ],
        101 => [
          _then([_add(base, base ~/ 100)]),
          _then([answer]),
        ],
        125 => [
          _then([_add(base, _div(base, 4))]),
          _then([_add(base, base ~/ 4)]),
          _then([answer]),
        ],
        200 => [
          _then([_mul(2, base)]),
          _then([answer]),
        ],
        _ => null,
      };
    default:
      // Another operation's family: `_familyLines` never asks. A new
      // family of this operation fails the Method tests until it has lines.
      return null;
  }
}

List<MethodLine>? _integralFamily(PatternFamily family, IntegralExercise e) {
  final terms = [
    for (var k = 0; k < 5; k++)
      if (e.coefficients[k] != 0) (k, e.coefficients[k]),
  ];
  if (terms.length != 1) return null;
  final (k, c) = terms.single;
  final a = e.lower;
  final b = e.upper;
  final answer = e.correctAnswer;
  switch (family) {
    case PatternFamily.twoXFromZero:
    case PatternFamily.threeXSquaredFromZero:
    case PatternFamily.fourXCubedFromZero:
      // ∫₀ᵇ (k + 1)xᵏ dx = bᵏ⁺¹.
      if (a != 0 || c != k + 1) return null;
      return [
        _then([_pow(b, k + 1)]),
        _then([answer]),
      ];
    case PatternFamily.twoXDifferenceOfSquares:
      if (k != 1 || c != 2) return null;
      return [
        _then([_sub(_pow(b, 2), _pow(a, 2))]),
        _then([_mul(_group(_sub(b, a)), _group(_add(b, a)))]),
        _then([_mul(b - a, b + a)]),
        _then([answer]),
      ];
    default:
      // Another operation's family: `_familyLines` never asks. A new
      // family of this operation fails the Method tests until it has lines.
      return null;
  }
}

// ── The detector's strategies (Phase 5.1) ────────────────────────────────

List<MethodLine> _strategyLines(StrategyMove move) => switch (move) {
  CompensationMove(:final kept, :final rounded, :final adjustment) =>
    _addViaRound(kept, rounded, adjustment),
  SubtractViaRoundMove(:final minuend, :final rounded, :final correction) =>
    _subtractViaRound(minuend, rounded, correction),
  DoublingHalvingMove(:final round, :final other) => [
    _then([_mul(other, round)]),
    _then([other * round]),
  ],
  SplitFactorMove(:final digit, :final tens, :final units) => [
    _then([_add(_mul(digit, tens), _mul(digit, units))]),
    _then([_add(digit * tens, digit * units)]),
    _then([move.result]),
  ],
  SquareNearBaseMove(:final base, :final offset) => _squareFromBase(
    base,
    offset,
  ),
  DifferenceOfSquaresMove(:final middle, :final gap) => _differenceOfSquares(
    middle,
    gap,
  ),
  SwapPercentageMove(:final percent, :final base) => [
    _then([PercentOf(percent, base)]),
    _then([move.result]),
  ],
};

// ── Fallbacks (doc/levels.md section 9's table) ──────────────────────────

List<MethodLine> _fallback(Exercise e) => switch (e) {
  ArithmeticExercise() => switch (e.operationType) {
    OperationType.addition => _additionFallback(e),
    OperationType.subtraction => _subtractionFallback(e.operandA, e.operandB),
    OperationType.multiplication => _multiplicationFallback(
      e.operandA,
      e.operandB,
    ),
    OperationType.division => _splitDividend(e.operandA, e.operandB),
  },
  PowerExercise() => _powerFallback(e.base, e.exponent),
  SquareRootExercise() => _rootFallback(e.radicand, e.index),
  PercentageExercise() => _percentageFallback(e),
  IntegralExercise() => _antiderivative(e),
};

/// By place value, left to right: digit columns up to 3 digits, groups of
/// three digits (thousands, millions) beyond — "column with carries" for
/// long numbers, one line per stage. Under 10 + 10: make 10.
List<MethodLine> _additionFallback(ArithmeticExercise e) {
  final addends = [e.operandA, e.operandB, ?e.operandC];
  final answer = e.correctAnswer;
  final largest = addends.reduce((x, y) => x > y ? x : y);
  if (largest < 10) {
    final [a, b, ...] = addends;
    final big = a > b ? a : b;
    final small = a > b ? b : a;
    if (addends.length == 2 && big + small > 10) {
      // Make 10: 8 + 7 = 8 + 2 + 5.
      final toTen = 10 - big;
      return [
        _then([_add(_add(big, toTen), small - toTen)]),
        _then([_add(10, small - toTen)]),
        _then([answer]),
      ];
    }
    // From the larger, then the fact.
    return [
      _then([
        _sum([big, small, ...addends.skip(2)]),
      ]),
      _then([answer]),
    ];
  }
  final unit = largest < 1000 ? 10 : 1000;
  // Places, highest first: each place's parts of the addends.
  final places = <List<int>>[];
  for (var place = _placeAtUnit(largest, unit); place >= 1; place ~/= unit) {
    final parts = [
      for (final n in addends)
        if (n ~/ place % unit != 0) n ~/ place % unit * place,
    ];
    if (parts.isNotEmpty) places.add(parts);
  }
  final grouped = [
    for (final parts in places)
      parts.length == 1 ? _x(parts.single) : _group(_sum(parts)),
  ];
  final sums = [
    for (final parts in places) parts.fold<int>(0, (s, p) => s + p),
  ];
  if (grouped.length == 1) {
    return [
      _then([grouped.single]),
      _then([answer]),
    ];
  }
  return [
    _then([_sum(grouped)]),
    _then([_sum(sums)]),
    _then([answer]),
  ];
}

/// The highest power of [unit] not above [n].
int _placeAtUnit(int n, int unit) {
  var p = 1;
  while (p * unit <= n) {
    p *= unit;
  }
  return p;
}

/// Count up from the smaller number through a round one; within 10, the
/// addition it undoes; else by place value.
List<MethodLine> _subtractionFallback(int a, int b) {
  final answer = a - b;
  if (a <= 10) {
    return [
      _eq([_add(b, answer), a]),
      _eq([_sub(a, b), answer]),
    ];
  }
  final digitsB = '$b'.length;
  for (var p = digitsB <= 1 ? 10 : _power(10, digitsB - 1); p >= 10; p ~/= 10) {
    final round = (b ~/ p + 1) * p;
    if (round > b && round < a) {
      return [
        _then([_add(_group(_sub(round, b)), _group(_sub(a, round)))]),
        _then([_add(round - b, a - round)]),
        _then([answer]),
      ];
    }
  }
  // b's leading place first, then the rest.
  final place = _placeOf(b);
  final high = b - b % place;
  final low = b % place;
  if (low == 0) {
    return [
      _then([_sub(a, b)]),
      _then([answer]),
    ];
  }
  return [
    _then([_sub(_sub(a, high), low)]),
    _then([_sub(a - high, low)]),
    _then([answer]),
  ];
}

/// Split the larger factor by place value; tables by fives.
List<MethodLine> _multiplicationFallback(int a, int b) {
  final answer = a * b;
  final large = a >= b ? a : b;
  final small = a >= b ? b : a;
  if (small == 1 || small == 10 || small == 0) {
    return [
      _then([_mul(small, large)]),
      _then([answer]),
    ];
  }
  if (large < 10) {
    if (large >= 6) {
      // 8 × 7 = 8 × 5 + 8 × 2.
      return [
        _then([_add(_mul(small, 5), _mul(small, large - 5))]),
        _then([_add(small * 5, small * (large - 5))]),
        _then([answer]),
      ];
    }
    return [
      _then([
        _sum([for (var i = 0; i < small; i++) large]),
      ]),
      _then([answer]),
    ];
  }
  final parts = [
    for (var place = _placeOf(large); place >= 1; place ~/= 10)
      if (large ~/ place % 10 != 0) large ~/ place % 10 * place,
  ];
  if (parts.length == 1) {
    // 70 × 8 = 7 × 8 × 10.
    final place = _placeOf(large);
    final digit = large ~/ place;
    return [
      _then([_mul(_mul(digit, small), place)]),
      _then([_mul(digit * small, place)]),
      _then([answer]),
    ];
  }
  return [
    _then([_mul(_group(_sum(parts)), small)]),
    _then([
      _sum([for (final p in parts) p * small]),
    ]),
    _then([answer]),
  ];
}

/// (a + b)² from the nearest ten; small squares and other powers by
/// multiplying on.
List<MethodLine> _powerFallback(int n, int x) {
  final answer = _power(n, x);
  if (x == 1) {
    return [
      _then([n]),
    ];
  }
  if (x == 2 && n >= 11 && n % 10 != 0) {
    final base = (n + 5) ~/ 10 * 10;
    return _squareFromBase(base, n - base);
  }
  if (x == 2 && n % 10 == 0 && n > 0) {
    final t = n ~/ 10;
    return [
      _then([_mul(_mul(t, t), 100)]),
      _then([answer]),
    ];
  }
  if (x == 2) {
    return [
      _then([_mul(n, n)]),
      _then([answer]),
    ];
  }
  final before = _power(n, x - 1);
  return [
    _then([_mul(_pow(n, x - 1), n)]),
    _then([_mul(before, n)]),
    _then([answer]),
  ];
}

/// The last digit, then bracket between known squares (or cubes).
List<MethodLine> _rootFallback(int radicand, int index) {
  final root = RootOf(radicand, index: index).value;
  Expr powerOf(int x) => _pow(x, index);
  final rootLine = _eq([RootOf(radicand, index: index), root]);
  if (root <= 10 || root % 10 == 0) {
    return [
      _eq([powerOf(root), radicand]),
      rootLine,
    ];
  }
  final low = root ~/ 10 * 10;
  final units = root % 10;
  final bracket = _lt([powerOf(low), radicand, powerOf(low + 10)]);
  final lastDigit = _eq([powerOf(units), _power(units, index)]);
  if (index == 3 || units == 5) {
    // A cube's last digit gives the root's; …25 gives 5.
    return [bracket, lastDigit, rootLine];
  }
  // Two candidates end right (3 and 7 for …9): the middle square decides.
  final middle = low + 5;
  final middleSquare = middle * middle;
  final decide = root > middle
      ? MethodLine(
          [_pow(middle, 2), Num(middleSquare), Num(radicand)],
          const [Relation.equals, Relation.lessThan],
        )
      : MethodLine(
          [Num(radicand), Num(middleSquare), _pow(middle, 2)],
          const [Relation.lessThan, Relation.equals],
        );
  return [bracket, lastDigit, decide, rootLine];
}

/// Friendly fractions; 10 %, 5 % and 1 % for a round base; above 100 %:
/// the whole and the rest; else the product over 100.
List<MethodLine> _percentageFallback(PercentageExercise e) {
  final p = e.percent;
  final base = e.base;
  final answer = e.correctAnswer;
  if (e.tenths != 0) {
    // Eighths: 37.5 % = 3 eighths.
    final eighths = (p * 10 + e.tenths) ~/ 125;
    return [
      _then([_mul(_div(base, 8), eighths)]),
      _then([_mul(base ~/ 8, eighths)]),
      _then([answer]),
    ];
  }
  switch (p) {
    case 50:
      return [
        _then([_div(base, 2)]),
        _then([answer]),
      ];
    case 25:
      return [
        _then([_div(base, 4)]),
        _then([answer]),
      ];
    case 20:
      return [
        _then([_div(base, 5)]),
        _then([answer]),
      ];
    case 10:
      return [
        _then([_div(base, 10)]),
        _then([answer]),
      ];
    case 1:
      return [
        _then([_div(base, 100)]),
        _then([answer]),
      ];
    case 75:
      return [
        _then([_mul(_div(base, 4), 3)]),
        _then([_mul(base ~/ 4, 3)]),
        _then([answer]),
      ];
  }
  if (p > 100) {
    final rest = p - 100;
    return [
      _then([_add(base, PercentOf(rest, base))]),
      _then([_add(base, rest * base ~/ 100)]),
      _then([answer]),
    ];
  }
  if (base % 100 == 0) return _fromTensFivesOnes(p, base);
  return [
    _then([_div(_mul(p, base), 100)]),
    _then([_div(p * base, 100)]),
    _then([answer]),
  ];
}

/// p % of a base divisible by 100: so many tens of percent, a five, so
/// many ones ("15 % = 10 % + 5 %").
List<MethodLine> _fromTensFivesOnes(int p, int base) {
  final ten = base ~/ 10;
  final five = base ~/ 20;
  final one = base ~/ 100;
  final tens = p ~/ 10;
  final fives = p % 10 >= 5 ? 1 : 0;
  final ones = p % 10 - 5 * fives;
  final parts = <Expr>[
    if (tens == 1) Num(ten) else if (tens > 1) _mul(tens, ten),
    if (fives == 1) Num(five),
    if (ones == 1) Num(one) else if (ones > 1) _mul(ones, one),
  ];
  final values = [
    if (tens > 0) tens * ten,
    if (fives == 1) five,
    if (ones > 0) ones * one,
  ];
  final answer = p * base ~/ 100;
  if (parts.length == 1 && parts.single is Num) {
    // 10 %, 5 % or 1 % alone: the division itself.
    final by = tens == 1 ? 10 : (fives == 1 ? 20 : 100);
    return [
      _then([_div(base, by)]),
      _then([answer]),
    ];
  }
  final hasProducts = parts.any((x) => x is Bin);
  return [
    _then([_sum(parts)]),
    if (hasProducts && values.length > 1) _then([_sum(values)]),
    _then([answer]),
  ];
}
