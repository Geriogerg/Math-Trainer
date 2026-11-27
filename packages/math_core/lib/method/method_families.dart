part of 'method_for.dart';

// ── The families (doc/levels.md section 5b) ──────────────────────────────

/// [family]'s own lines for [e]; `null` when [e] is not that family's kind
/// (a replay never gives one, but a caller might). One exhaustive switch on
/// the family (review n6: no `default`) — a new family does not compile
/// until it has lines.
List<MethodLine>? _familyLines(PatternFamily family, Exercise e) {
  if (e.type != family.type) return null;
  List<MethodLine>? arithmetic(
    List<MethodLine>? Function(ArithmeticExercise) lines,
  ) => e is ArithmeticExercise ? lines(e) : null;
  List<MethodLine>? power(List<MethodLine>? Function(PowerExercise) lines) =>
      e is PowerExercise ? lines(e) : null;
  List<MethodLine>? root(
    List<MethodLine>? Function(SquareRootExercise) lines,
  ) => e is SquareRootExercise ? lines(e) : null;
  List<MethodLine>? percentage(
    List<MethodLine>? Function(PercentageExercise) lines,
  ) => e is PercentageExercise && e.tenths == 0 ? lines(e) : null;
  List<MethodLine>? integral(
    List<MethodLine>? Function(IntegralExercise) lines,
  ) => e is IntegralExercise ? lines(e) : null;

  return switch (family) {
    PatternFamily.doubles => arithmetic(_doubles),
    PatternFamily.complements => arithmetic(_complements),
    PatternFamily.addJustBelowRound => arithmetic((a) => _addJustBelow(a, 100)),
    PatternFamily.addJustBelowPowerOf10 => arithmetic(
      (a) => _addJustBelow(a, 1000),
    ),
    PatternFamily.roundNumbers => arithmetic(_roundNumbers),
    PatternFamily.threeTerms => arithmetic(_threeTerms),
    PatternFamily.subtractJustBelowRound => arithmetic(
      (a) => _subtractJustBelow(a, 100),
    ),
    PatternFamily.subtractJustBelowPowerOf10 => arithmetic(
      (a) => _subtractJustBelow(a, 1000),
    ),
    PatternFamily.fromRound => arithmetic(_fromRound),
    PatternFamily.acrossRound => arithmetic(_acrossRound),
    PatternFamily.sameGapShift => arithmetic(_sameGapShift),
    PatternFamily.times5 => arithmetic(_times5),
    PatternFamily.times11 => arithmetic((a) => _timesRoundPlusOne(a, 10)),
    PatternFamily.nearBase => arithmetic(_nearBase),
    PatternFamily.times25 => arithmetic(_times25),
    PatternFamily.differenceOfSquares ||
    PatternFamily.differenceOfSquaresHundreds => arithmetic(
      _differenceOfSquaresFamily,
    ),
    PatternFamily.doublingHalving => arithmetic(_doublingHalving),
    PatternFamily.times9s => arithmetic(_times9s),
    PatternFamily.sameTensUnitsTo10 => arithmetic(_sameTensUnitsTo10),
    PatternFamily.times101 => arithmetic((a) => _timesRoundPlusOne(a, 100)),
    PatternFamily.powersOf2Product => arithmetic(_powersOf2Product),
    PatternFamily.bothNear100 => arithmetic(_bothNear100),
    PatternFamily.halveBig ||
    PatternFamily.bigBy3To5 ||
    PatternFamily.bigBy6To9 => arithmetic(
      (a) => _splitDividend(a.operandA, a.operandB).$2,
    ),
    PatternFamily.roundDivision => arithmetic(_roundDivision),
    PatternFamily.by25 => arithmetic(_by25),
    PatternFamily.by11 => arithmetic(_by11),
    PatternFamily.halvingChain => arithmetic(_halvingChain),
    PatternFamily.powersOf2 => power(_powersOf2),
    PatternFamily.squaresEndingIn5 => power(_squaresEndingIn5),
    PatternFamily.powersOf3To5 => power(_powersOf3To5),
    PatternFamily.squaresNear50And100 => power(
      (p) => _squareNearBaseFamily(p, p.base < 75 ? 50 : 100),
    ),
    PatternFamily.squaresNear1000 => power(
      (p) => _squareNearBaseFamily(p, 1000),
    ),
    PatternFamily.repunits => power(_repunits),
    PatternFamily.rootsOfPowersOf2 => root(_rootsOfPowersOf2),
    PatternFamily.rootsEndingIn25 => root(_rootsEndingIn25),
    PatternFamily.rootsNear100 => root((r) => _rootNearBase(r, 100)),
    PatternFamily.rootsNear1000 => root((r) => _rootNearBase(r, 1000)),
    PatternFamily.cubeRootsRepunitAndRound => root(_knownCubes),
    PatternFamily.halfAndQuarterOfBig => percentage(_halfAndQuarter),
    PatternFamily.swap => percentage(_swap),
    PatternFamily.percentOfBigRound => percentage(
      (p) => _fromTensFivesOnes(p.percent, p.base),
    ),
    PatternFamily.nearHundredPercent => percentage(_nearHundredPercent),
    PatternFamily.twoXFromZero ||
    PatternFamily.threeXSquaredFromZero ||
    PatternFamily.fourXCubedFromZero => integral(_powerRuleFromZero),
    PatternFamily.twoXDifferenceOfSquares => integral(_twoXDifferenceOfSquares),
  };
}

// ── Addition ──────────────────────────────────────────────────────────────

List<MethodLine>? _doubles(ArithmeticExercise e) {
  final a = e.operandA;
  final b = e.operandB;
  if (e.operandC != null || (b - a).abs() > 1) return null;
  final small = a < b ? a : b;
  if (a == b) {
    return [
      _then([_mul(2, a)]),
      _then([e.correctAnswer]),
    ];
  }
  return [
    _then([_add(_mul(2, small), 1)]),
    _then([_add(2 * small, 1)]),
    _then([e.correctAnswer]),
  ];
}

/// 37 + 63 = 100, 418 + 582 = 1 000 … any power of 10.
List<MethodLine>? _complements(ArithmeticExercise e) {
  final answer = e.correctAnswer;
  if (e.operandC != null || answer < 100 || !_isPowerOf10(answer)) return null;
  final unit = answer ~/ 10;
  final ra = e.operandA % unit;
  final rb = e.operandB % unit;
  return [
    _then([
      _add(
        _group(_add(e.operandA - ra, e.operandB - rb)),
        _group(_add(ra, rb)),
      ),
    ]),
    _then([_add(e.operandA - ra + e.operandB - rb, ra + rb)]),
    _then([answer]),
  ];
}

/// 65 + 98 = 65 + 100 − 2 (to [step], or to the ten for small sums).
List<MethodLine>? _addJustBelow(ArithmeticExercise e, int step) {
  final b = e.operandB;
  final round = _roundAbove(b, step, 3) ?? _roundAbove(b, 10, 3);
  if (e.operandC != null || round == null) return null;
  return _addViaRound(e.operandA, round, round - b);
}

/// 3 500 + 4 500 by hundreds: the largest unit both share.
List<MethodLine>? _roundNumbers(ArithmeticExercise e) {
  final a = e.operandA;
  final b = e.operandB;
  if (e.operandC != null) return null;
  for (final unit in const [10000000, 1000000, 100000, 10000, 1000, 100, 10]) {
    if (a % unit == 0 && b % unit == 0) {
      return [
        _then([_mul(_group(_add(a ~/ unit, b ~/ unit)), unit)]),
        _then([_mul((a + b) ~/ unit, unit)]),
        _then([e.correctAnswer]),
      ];
    }
  }
  return null;
}

/// 27 + 46 + 73: a + c a power of 10 first.
List<MethodLine>? _threeTerms(ArithmeticExercise e) {
  final a = e.operandA;
  final c = e.operandC;
  if (c == null || a + c < 100 || !_isPowerOf10(a + c)) return null;
  return [
    _then([_add(_group(_add(a, c)), e.operandB)]),
    _then([_add(a + c, e.operandB)]),
    _then([e.correctAnswer]),
  ];
}

// ── Subtraction ───────────────────────────────────────────────────────────

/// 742 − 198 = 742 − 200 + 2.
List<MethodLine>? _subtractJustBelow(ArithmeticExercise e, int step) {
  final b = e.operandB;
  final round = _roundAbove(b, step, 4);
  if (round == null) return null;
  return _subtractViaRound(e.operandA, round, round - b);
}

/// 1 000 − 357 = (999 − 357) + 1: no borrow at all.
List<MethodLine> _fromRound(ArithmeticExercise e) => [
  _then([_add(_group(_sub(e.operandA - 1, e.operandB)), 1)]),
  _then([_add(e.operandA - 1 - e.operandB, 1)]),
  _then([e.correctAnswer]),
];

/// 5 003 − 4 997 = (5 000 − 4 997) + (5 003 − 5 000).
List<MethodLine>? _acrossRound(ArithmeticExercise e) {
  final a = e.operandA;
  final b = e.operandB;
  final round = _roundAbove(b, 100, 9);
  if (round == null || a <= round) return null;
  return [
    _then([_add(_group(_sub(round, b)), _group(_sub(a, round)))]),
    _then([_add(round - b, a - round)]),
    _then([e.correctAnswer]),
  ];
}

/// 803 − 497 = (803 + 3) − (497 + 3).
List<MethodLine>? _sameGapShift(ArithmeticExercise e) {
  final a = e.operandA;
  final b = e.operandB;
  final round = _roundAbove(b, 100, 9);
  if (round == null) return null;
  final k = round - b;
  return [
    _then([_sub(_group(_add(a, k)), _group(_add(b, k)))]),
    _then([_sub(a + k, round)]),
    _then([e.correctAnswer]),
  ];
}

// ── Multiplication ────────────────────────────────────────────────────────

/// × 5 = × 10 ÷ 2; × 50 = × 100 ÷ 2.
List<MethodLine> _times5(ArithmeticExercise e) {
  final a = e.operandA;
  final round = e.operandB * 2;
  return [
    _then([_div(_mul(a, round), 2)]),
    _then([_div(a * round, 2)]),
    _then([e.correctAnswer]),
  ];
}

/// × 11 = × 10 + itself; × 101 = × 100 + itself.
List<MethodLine> _timesRoundPlusOne(ArithmeticExercise e, int round) {
  final a = e.operandA;
  return [
    _then([_add(_mul(a, round), a)]),
    _then([_add(a * round, a)]),
    _then([e.correctAnswer]),
  ];
}

/// 98 × 7 = (100 − 2) × 7, 1 009 × 16 = (1 000 + 9) × 16: the nearest
/// power of 10 (`doc/levels.md` v1.6: "near a base uses the nearest power
/// of 10"; review M11 — 1 009 × 16 was explained from 100).
List<MethodLine> _nearBase(ArithmeticExercise e) {
  final a = e.operandA;
  final b = e.operandB;
  final base = _nearestPowerOf10(a);
  final offset = a - base;
  final d = offset.abs();
  return [
    _then([_mul(_group(offset > 0 ? _add(base, d) : _sub(base, d)), b)]),
    _then([offset > 0 ? _add(base * b, d * b) : _sub(base * b, d * b)]),
    _then([e.correctAnswer]),
  ];
}

/// × 25 = × 100 ÷ 4; × 125 = × 1 000 ÷ 8.
List<MethodLine> _times25(ArithmeticExercise e) {
  final a = e.operandA;
  final (round, by) = e.operandB == 25 ? (100, 4) : (1000, 8);
  return [
    _then([_div(_mul(a, round), by)]),
    _then([_div(a * round, by)]),
    _then([e.correctAnswer]),
  ];
}

List<MethodLine>? _differenceOfSquaresFamily(ArithmeticExercise e) {
  final a = e.operandA;
  final b = e.operandB;
  if ((a + b).isOdd || a == b) return null;
  final lo = a < b ? a : b;
  final hi = a < b ? b : a;
  return _differenceOfSquares((lo + hi) ~/ 2, (hi - lo) ~/ 2);
}

/// 16 × 35 = 8 × 70.
List<MethodLine>? _doublingHalving(ArithmeticExercise e) {
  final (even, five) = e.operandA.isEven
      ? (e.operandA, e.operandB)
      : (e.operandB, e.operandA);
  if (even.isOdd) return null;
  return [
    _then([_mul(even ~/ 2, five * 2)]),
    _then([e.correctAnswer]),
  ];
}

/// 47 × 99 = 47 × 100 − 47.
List<MethodLine> _times9s(ArithmeticExercise e) {
  final a = e.operandA;
  final round = e.operandB + 1;
  return [
    _then([_sub(_mul(a, round), a)]),
    _then([_sub(a * round, a)]),
    _then([e.correctAnswer]),
  ];
}

/// 43 × 47 = 4 × 5 × 100 + 3 × 7.
List<MethodLine> _sameTensUnitsTo10(ArithmeticExercise e) {
  final a = e.operandA;
  final b = e.operandB;
  final tens = a ~/ 10;
  return [
    _then([_add(_mul(_mul(tens, tens + 1), 100), _mul(a % 10, b % 10))]),
    _then([_add(tens * (tens + 1) * 100, (a % 10) * (b % 10))]),
    _then([e.correctAnswer]),
  ];
}

/// 64 × 32 = 2⁶ × 2⁵ = 2¹¹.
List<MethodLine>? _powersOf2Product(ArithmeticExercise e) {
  final i = _log2(e.operandA);
  final j = _log2(e.operandB);
  if (i == null || j == null) return null;
  return [
    _then([_mul(_pow(2, i), _pow(2, j))]),
    _then([_pow(2, i + j)]),
    _then([e.correctAnswer]),
  ];
}

/// 97 × 96 = 100 × (97 − 4) + 3 × 4.
List<MethodLine> _bothNear100(ArithmeticExercise e) {
  final a = e.operandA;
  final b = e.operandB;
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
    _then([e.correctAnswer]),
  ];
}

// ── Division ──────────────────────────────────────────────────────────────

/// 36 000 ÷ 400 = 360 ÷ 4: drop the zeros both share.
List<MethodLine> _roundDivision(ArithmeticExercise e) {
  var x = e.operandA;
  var y = e.operandB;
  while (x % 10 == 0 && y % 10 == 0) {
    x ~/= 10;
    y ~/= 10;
  }
  return [
    _then([_div(x, y)]),
    _then([e.correctAnswer]),
  ];
}

/// ÷ 25 = × 4 ÷ 100; ÷ 125 = × 8 ÷ 1 000.
List<MethodLine> _by25(ArithmeticExercise e) {
  final a = e.operandA;
  final (by, round) = e.operandB == 25 ? (4, 100) : (8, 1000);
  return [
    _then([_div(_mul(a, by), round)]),
    _then([_div(a * by, round)]),
    _then([e.correctAnswer]),
  ];
}

/// 473 ÷ 11: 43 × 11 = 430 + 43 = 473.
List<MethodLine> _by11(ArithmeticExercise e) {
  final answer = e.correctAnswer;
  return [
    _eq([_mul(answer, 11), _add(answer * 10, answer), e.operandA]),
    _eq([_div(e.operandA, 11), answer]),
  ];
}

/// 7 344 ÷ 8: halve three times (÷ 16: four).
List<MethodLine> _halvingChain(ArithmeticExercise e) {
  final a = e.operandA;
  final answer = e.correctAnswer;
  if (e.operandB == 8) {
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

// ── Powers ────────────────────────────────────────────────────────────────

/// 2⁹ = 2⁸ × 2; 2¹⁶ = 2¹⁰ × 2⁶ = 1 024 × 64.
List<MethodLine>? _powersOf2(PowerExercise e) {
  final x = e.exponent;
  if (e.base != 2) return null;
  if (x <= 10) {
    return [
      _then([_mul(_pow(2, x - 1), 2)]),
      _then([_mul(_power(2, x - 1), 2)]),
      _then([e.correctAnswer]),
    ];
  }
  return [
    _then([_mul(_pow(2, 10), _pow(2, x - 10))]),
    _then([_mul(1024, _power(2, x - 10))]),
    _then([e.correctAnswer]),
  ];
}

/// 35² = 3 × 4 × 100 + 25.
List<MethodLine>? _squaresEndingIn5(PowerExercise e) {
  final n = e.base;
  if (e.exponent != 2 || n % 10 != 5) return null;
  final t = n ~/ 10;
  return [
    _then([_add(_mul(_mul(t, t + 1), 100), 25)]),
    _then([_add(t * (t + 1) * 100, 25)]),
    _then([e.correctAnswer]),
  ];
}

/// 3⁸ = 3⁴ × 3⁴ = 81 × 81: split the exponent — 4⁵ too (= 4² × 4³).
List<MethodLine> _powersOf3To5(PowerExercise e) {
  final n = e.base;
  final x = e.exponent;
  final h = x ~/ 2;
  // 3³ = 3 × 3², not 3¹ × 3².
  Expr part(int k) => k == 1 ? Num(n) : _pow(n, k);
  return [
    _then([_mul(part(h), part(x - h))]),
    _then([_mul(_power(n, h), _power(n, x - h))]),
    _then([e.correctAnswer]),
  ];
}

/// 48² = (50 − 2)²; 997² = (1 000 − 3)².
List<MethodLine>? _squareNearBaseFamily(PowerExercise e, int base) {
  if (e.exponent != 2 || e.base == base) return null;
  return _squareFromBase(base, e.base - base);
}

/// 11³ = 121 × 11 = 1 210 + 121; 111² = 11 100 + 1 110 + 111.
List<MethodLine> _repunits(PowerExercise e) {
  final n = e.base;
  final x = e.exponent;
  final answer = e.correctAnswer;
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
  if (x == 2) {
    final digits = '$n'.length;
    return [
      _then([
        _sum([for (var i = digits - 1; i >= 0; i--) n * _power(10, i)]),
      ]),
      _then([answer]),
    ];
  }
  // 111³ = 12 321 × 111 = 1 232 100 + 123 210 + 12 321.
  final before = _power(n, x - 1);
  final digits = '$n'.length;
  return [
    _then([_mul(before, n)]),
    _then([
      _sum([for (var i = digits - 1; i >= 0; i--) before * _power(10, i)]),
    ]),
    _then([answer]),
  ];
}

// ── Roots ─────────────────────────────────────────────────────────────────

/// √256 = √2⁸ = 2⁴ = 16.
List<MethodLine>? _rootsOfPowersOf2(SquareRootExercise e) {
  final r = e.correctAnswer;
  final k = _log2(r);
  if (k == null || e.index != 2) return null;
  return [
    _eq([e.radicand, _pow(2, 2 * k)]),
    _eq([RootOf(e.radicand), _pow(2, k)]),
    _then([r]),
  ];
}

/// √7 225: 85² = 8 × 9 × 100 + 25.
List<MethodLine>? _rootsEndingIn25(SquareRootExercise e) {
  final r = e.correctAnswer;
  if (e.index != 2 || r % 10 != 5) return null;
  final t = r ~/ 10;
  return [
    _eq([_pow(r, 2), _add(_mul(_mul(t, t + 1), 100), 25)]),
    _then([e.radicand]),
    _eq([RootOf(e.radicand), r]),
  ];
}

/// √10 201: 101² = (100 + 1)².
List<MethodLine>? _rootNearBase(SquareRootExercise e, int base) {
  final r = e.correctAnswer;
  if (e.index != 2 || r == base) return null;
  return _rootFromBase(e.radicand, base, r - base);
}

/// ∛8 000: 20³ = 2³ × 1 000; ∛1 331: 11³ = 121 × 11.
List<MethodLine>? _knownCubes(SquareRootExercise e) {
  final r = e.correctAnswer;
  if (e.index != 3) return null;
  if (r % 10 == 0) {
    return [
      _eq([_pow(r, 3), _mul(_pow(r ~/ 10, 3), 1000)]),
      _then([e.radicand]),
      _eq([RootOf(e.radicand, index: 3), r]),
    ];
  }
  return [
    _eq([_pow(r, 3), _mul(r * r, r)]),
    _then([e.radicand]),
    _eq([RootOf(e.radicand, index: 3), r]),
  ];
}

// ── Percentages ───────────────────────────────────────────────────────────

/// 50 % = half; 25 % = half of half.
List<MethodLine>? _halfAndQuarter(PercentageExercise e) {
  final base = e.base;
  if (e.percent == 50) {
    return [
      _then([_div(base, 2)]),
      _then([e.correctAnswer]),
    ];
  }
  if (e.percent != 25) return null;
  return [
    _then([_div(_div(base, 2), 2)]),
    _then([_div(base ~/ 2, 2)]),
    _then([e.correctAnswer]),
  ];
}

/// p % of B = B % of p, then B % of p from what B is: a quarter or a half
/// (25, 50), so many times (2 500 % = × 25), or so many times and a quarter
/// or a half (125 %, 250 %, 1 250 %).
List<MethodLine> _swap(PercentageExercise e) {
  final p = e.percent;
  final base = e.base;
  final answer = e.correctAnswer;
  final swapped = _then([PercentOf(base, p)]);
  if (base < 100) {
    return [
      swapped,
      _then([_div(p, 100 ~/ base)]),
      _then([answer]),
    ];
  }
  final times = base ~/ 100;
  final rest = base % 100;
  if (rest == 0) {
    return [
      swapped,
      _then([_mul(p, times)]),
      _then([answer]),
    ];
  }
  final share = 100 ~/ rest;
  return [
    swapped,
    _then([_add(times == 1 ? Num(p) : _mul(p, times), _div(p, share))]),
    _then([_add(p * times, p ~/ share)]),
    _then([answer]),
  ];
}

/// 99 % = the whole less 1 %; 101 % plus 1 %; 125 % plus a quarter; 200 %
/// twice.
List<MethodLine>? _nearHundredPercent(PercentageExercise e) {
  final base = e.base;
  final answer = e.correctAnswer;
  return switch (e.percent) {
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
}

// ── Integrals ─────────────────────────────────────────────────────────────

/// The single term of [e], as (power, coefficient); `null` for more.
(int, int)? _singleTerm(IntegralExercise e) {
  final terms = [
    for (var k = 0; k < 5; k++)
      if (e.coefficients[k] != 0) (k, e.coefficients[k]),
  ];
  return terms.length == 1 ? terms.single : null;
}

/// ∫₀ᵇ (k + 1)xᵏ dx = bᵏ⁺¹.
List<MethodLine>? _powerRuleFromZero(IntegralExercise e) {
  final term = _singleTerm(e);
  if (term == null) return null;
  final (k, c) = term;
  if (e.lower != 0 || c != k + 1) return null;
  return [
    _then([_pow(e.upper, k + 1)]),
    _then([e.correctAnswer]),
  ];
}

/// ∫ₐᵇ 2x dx = b² − a² = (b − a)(b + a).
List<MethodLine>? _twoXDifferenceOfSquares(IntegralExercise e) {
  final term = _singleTerm(e);
  if (term == null || term != (1, 2)) return null;
  final a = e.lower;
  final b = e.upper;
  return [
    _then([_sub(_pow(b, 2), _pow(a, 2))]),
    _then([_mul(_group(_sub(b, a)), _group(_add(b, a)))]),
    _then([_mul(b - a, b + a)]),
    _then([e.correctAnswer]),
  ];
}
