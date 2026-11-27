part of 'method_for.dart';

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

bool _isPowerOf10(int n) {
  if (n < 1) return false;
  while (n % 10 == 0) {
    n ~/= 10;
  }
  return n == 1;
}

/// The power of 10 nearest [n] (n ≥ 1): 100 for 97, 1 000 for 1 009.
int _nearestPowerOf10(int n) {
  final below = _placeOf(n);
  return n - below <= 10 * below - n ? below : 10 * below;
}

/// The round number [n] sits 1 to [maxGap] below (a multiple of [step]).
int? _roundAbove(int n, int step, int maxGap) {
  for (var k = 1; k <= maxGap; k++) {
    if ((n + k) % step == 0) return n + k;
  }
  return null;
}

/// Significant digits: trailing zeros of a round number don't count.
int _significant(int n) {
  var m = n.abs();
  if (m == 0) return 1;
  while (m % 10 == 0) {
    m ~/= 10;
  }
  return '$m'.length;
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

/// a ÷ d (`doc/levels.md` v1.6 section 9: "long division splits the
/// dividend into parts each divisible at sight, down to the answer"):
///
/// - a one-digit quotient — or a round one (560 ÷ 8 = 70) — is the
///   multiplication: d × q = a;
/// - a two-digit quotient: the dividend split by the quotient's places
///   (522 ÷ 6 = 480 ÷ 6 + 42 ÷ 6 = 80 + 7);
/// - larger: parts taken off the dividend, the largest first, each either d
///   × a one-digit number × 10ᵏ (4 000 = 4 × 1 000) or a round number d
///   divides into a short quotient (1 000 ÷ 4 = 250), until what is left
///   has a two-digit quotient (5 104 ÷ 4 = 4 000 ÷ 4 + 1 000 ÷ 4 + 104 ÷ 4
///   = 1 000 + 250 + 26).
(MethodFallback, List<MethodLine>) _splitDividend(int dividend, int divisor) {
  final q = dividend ~/ divisor;
  if (q < 10 || _oneSignificant(q)) {
    return (
      MethodFallback.thinkMultiplication,
      [
        _eq([_mul(divisor, q), dividend]),
        _eq([_div(dividend, divisor), q]),
      ],
    );
  }
  final parts = <int>[];
  if (q < 100) {
    final tens = q - q % 10;
    parts.addAll([divisor * tens, divisor * (q % 10)]);
  } else {
    var left = dividend;
    while (left ~/ divisor >= 100) {
      var best = 0;
      for (var place = 10; place <= left; place *= 10) {
        for (var m = 1; m <= 9; m++) {
          final multiple = divisor * m * place;
          if (multiple <= left && multiple > best) best = multiple;
          final round = m * place;
          if (round <= left &&
              round > best &&
              round % divisor == 0 &&
              _significant(round ~/ divisor) <= 2) {
            best = round;
          }
        }
      }
      parts.add(best);
      left -= best;
    }
    if (left > 0) parts.add(left);
  }
  return (
    MethodFallback.splitDividend,
    [
      _then([
        _sum([for (final p in parts) _div(p, divisor)]),
      ]),
      _then([
        _sum([for (final p in parts) p ~/ divisor]),
      ]),
      _then([q]),
    ],
  );
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

/// [p] % of [base] built from 100 %, 50 %, 25 %, 10 %, 5 % and 1 % — each
/// part a whole number, the largest first (`doc/levels.md` v1.6 section 9:
/// "build from 50 %, 25 %, 10 %, 5 % and 1 %, never p × base ÷ 100"), as
/// (percent, how many) pairs; `null` when no whole build exists.
List<(int, int)>? _build(int p, int base) {
  final parts = <(int, int)>[];
  var left = p;
  for (final block in const [100, 50, 25, 10, 5, 1]) {
    if (block * base % 100 != 0) continue;
    final n = left ~/ block;
    if (n > 0) {
      parts.add((block, n));
      left -= n * block;
    }
  }
  return left == 0 ? parts : null;
}

/// The lines of a build ([_build]) of [base]: each part as "25 % of 140"
/// (100 % as the base itself, so many of one as "2 × 10 % of 300"), then
/// their values, then [answer].
List<MethodLine> _buildLines(List<(int, int)> parts, int base, int answer) {
  Expr named(int block, int n) {
    final one = block == 100 ? Num(base) : PercentOf(block, base);
    return n == 1 ? one : _mul(n, one);
  }

  Expr valued(int block, int n) {
    final one = block * base ~/ 100;
    return n == 1 ? Num(one) : _mul(n, one);
  }

  final single = parts.length == 1 && parts.single.$2 == 1;
  return [
    _then([
      _sum([for (final (b, n) in parts) named(b, n)]),
    ]),
    if (!single)
      _then([
        _sum([for (final (b, n) in parts) valued(b, n)]),
      ]),
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
