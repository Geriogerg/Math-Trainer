part of 'method_for.dart';

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

/// The operation's fallback, with what its lines do (each kind its own
/// name in the app: "the strategy name matches what the lines do").
(MethodFallback, List<MethodLine>) _fallback(Exercise e) => switch (e) {
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
  IntegralExercise() => (MethodFallback.antiderivative, _antiderivative(e)),
};

/// Single digits: make 10 past ten; a double or near double; count on by
/// ones from the larger — never the sum written the other way round (v1.6:
/// "no step that restates the question"). Longer numbers by place value,
/// left to right: digit columns up to 3 digits, groups of three digits
/// beyond — "column with carries" for long numbers, one line per stage.
(MethodFallback, List<MethodLine>) _additionFallback(ArithmeticExercise e) {
  final addends = [e.operandA, e.operandB, ?e.operandC];
  final answer = e.correctAnswer;
  final largest = addends.reduce((x, y) => x > y ? x : y);
  if (largest < 10 && addends.length == 2) {
    final [a, b] = addends;
    final big = a > b ? a : b;
    final small = a > b ? b : a;
    if (big + small > 10) {
      // Make 10: 8 + 7 = 8 + 2 + 5.
      final toTen = 10 - big;
      return (
        MethodFallback.makeTen,
        [
          _then([_add(_add(big, toTen), small - toTen)]),
          _then([_add(10, small - toTen)]),
          _then([answer]),
        ],
      );
    }
    if (big - small <= 1) {
      // 4 + 4 = 2 × 4; 4 + 5 = 4 + 4 + 1.
      return (
        MethodFallback.nearDouble,
        big == small
            ? [
                _then([_mul(2, small)]),
                _then([answer]),
              ]
            : [
                _then([_add(_add(small, small), 1)]),
                _then([_add(2 * small, 1)]),
                _then([answer]),
              ],
      );
    }
    if (small <= 3) {
      // 7 + 2 = 7 + 1 + 1.
      return (
        MethodFallback.countOn,
        [
          _then([
            _sum([big, for (var i = 0; i < small; i++) 1]),
          ]),
          _then([answer]),
        ],
      );
    }
    // 4 + 6 = 5 + 5: even them out to a double.
    final move = (big - small) ~/ 2;
    return (
      MethodFallback.nearDouble,
      [
        _then([_add(big - move, small + move)]),
        _then([answer]),
      ],
    );
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
  if (places.length == 1) {
    // 30 + 40: one place — (3 + 4) × 10.
    final parts = places.single;
    final place = _placeOf(parts.first);
    return (
      MethodFallback.placeValue,
      [
        _then([
          _mul(_group(_sum([for (final p in parts) p ~/ place])), place),
        ]),
        _then([answer]),
      ],
    );
  }
  final grouped = [
    for (final parts in places)
      parts.length == 1 ? _x(parts.single) : _group(_sum(parts)),
  ];
  final sums = [
    for (final parts in places) parts.fold<int>(0, (s, p) => s + p),
  ];
  return (
    MethodFallback.placeValue,
    [
      _then([_sum(grouped)]),
      _then([_sum(sums)]),
      _then([answer]),
    ],
  );
}

/// The highest power of [unit] not above [n].
int _placeAtUnit(int n, int unit) {
  var p = 1;
  while (p * unit <= n) {
    p *= unit;
  }
  return p;
}

/// Within 10, the addition it undoes; else count up from the smaller
/// number through a round one; else take the subtrahend away in parts.
(MethodFallback, List<MethodLine>) _subtractionFallback(int a, int b) {
  final answer = a - b;
  if (a <= 10) {
    return (
      MethodFallback.thinkAddition,
      [
        _eq([_add(b, answer), a]),
        _eq([_sub(a, b), answer]),
      ],
    );
  }
  final digitsB = '$b'.length;
  for (var p = digitsB <= 1 ? 10 : _power(10, digitsB - 1); p >= 10; p ~/= 10) {
    final round = (b ~/ p + 1) * p;
    // Up to the minuend itself: 297 + 3 = 300.
    if (round == a && _significant(a - b) <= 2) {
      return (
        MethodFallback.countUp,
        [
          _eq([_add(b, answer), a]),
          _eq([_sub(a, b), answer]),
        ],
      );
    }
    // Through a round number, when the first step is short (403 − 178 =
    // 22 + 203; never 40 000 − 30 549 first).
    if (round > b && round < a && _significant(round - b) <= 2) {
      return (
        MethodFallback.countUp,
        [
          _then([_add(_group(_sub(round, b)), _group(_sub(a, round)))]),
          _then([_add(round - b, a - round)]),
          _then([answer]),
        ],
      );
    }
  }
  // b's leading place first, then the rest.
  final place = _placeOf(b);
  final high = b - b % place;
  final low = b % place;
  if (low == 0) {
    return (
      MethodFallback.takeAwayInParts,
      [
        _then([_add(_group(_sub(a - a % place, high)), a % place)]),
        _then([_add(a - a % place - high, a % place)]),
        _then([answer]),
      ],
    );
  }
  return (
    MethodFallback.takeAwayInParts,
    [
      _then([_sub(_sub(a, high), low)]),
      _then([_sub(a - high, low)]),
      _then([answer]),
    ],
  );
}

/// × 1 and × 10 are the fact; tables by fives or by adding on; longer
/// numbers split by place value.
(MethodFallback, List<MethodLine>) _multiplicationFallback(int a, int b) {
  final answer = a * b;
  final large = a >= b ? a : b;
  final small = a >= b ? b : a;
  if (const [0, 1, 10].contains(small) || large == 10) {
    return (
      MethodFallback.timesOneOrTen,
      [
        _then([answer]),
      ],
    );
  }
  if (large < 10) {
    if (large >= 6) {
      // 8 × 7 = 8 × 5 + 8 × 2.
      return (
        MethodFallback.fives,
        [
          _then([_add(_mul(small, 5), _mul(small, large - 5))]),
          _then([_add(small * 5, small * (large - 5))]),
          _then([answer]),
        ],
      );
    }
    return (
      MethodFallback.repeatedAddition,
      [
        _then([
          _sum([for (var i = 0; i < small; i++) large]),
        ]),
        _then([answer]),
      ],
    );
  }
  final parts = [
    for (var place = _placeOf(large); place >= 1; place ~/= 10)
      if (large ~/ place % 10 != 0) large ~/ place % 10 * place,
  ];
  if (parts.length == 1) {
    // 70 × 8 = 7 × 8 × 10.
    final place = _placeOf(large);
    final digit = large ~/ place;
    return (
      MethodFallback.tensFirst,
      [
        _then([_mul(_mul(digit, small), place)]),
        _then([_mul(digit * small, place)]),
        _then([answer]),
      ],
    );
  }
  return (
    MethodFallback.splitFactor,
    [
      _then([_mul(_group(_sum(parts)), small)]),
      _then([
        _sum([for (final p in parts) p * small]),
      ]),
      _then([answer]),
    ],
  );
}

/// (a + b)² from the nearest ten; tens squared; small squares and other
/// powers by multiplying out.
(MethodFallback, List<MethodLine>) _powerFallback(int n, int x) {
  final answer = _power(n, x);
  if (x == 1) {
    return (
      MethodFallback.multiplyOut,
      [
        _then([n]),
      ],
    );
  }
  if (x == 2 && n >= 11 && n % 10 != 0) {
    final base = (n + 5) ~/ 10 * 10;
    return (MethodFallback.nearestTen, _squareFromBase(base, n - base));
  }
  if (x == 2 && n % 10 == 0 && n > 10) {
    final t = n ~/ 10;
    return (
      MethodFallback.squareTens,
      [
        _then([_mul(_mul(t, t), 100)]),
        _then([answer]),
      ],
    );
  }
  if (x == 2) {
    return (
      MethodFallback.multiplyOut,
      [
        _then([_mul(n, n)]),
        _then([answer]),
      ],
    );
  }
  final before = _power(n, x - 1);
  return (
    MethodFallback.multiplyOut,
    [
      _then([_mul(x - 1 == 1 ? Num(n) : _pow(n, x - 1), n)]),
      _then([_mul(before, n)]),
      _then([answer]),
    ],
  );
}

/// A known square or cube; else the last digit, then bracket between known
/// squares (or cubes).
(MethodFallback, List<MethodLine>) _rootFallback(int radicand, int index) {
  final root = RootOf(radicand, index: index).value;
  Expr powerOf(int x) => _pow(x, index);
  final rootLine = _eq([RootOf(radicand, index: index), root]);
  if (root <= 10 || root % 10 == 0) {
    return (
      MethodFallback.knownPower,
      [
        _eq([powerOf(root), radicand]),
        rootLine,
      ],
    );
  }
  final low = root ~/ 10 * 10;
  final units = root % 10;
  final bracket = _lt([powerOf(low), radicand, powerOf(low + 10)]);
  final lastDigit = _eq([powerOf(units), _power(units, index)]);
  if (index == 3 || units == 5) {
    // A cube's last digit gives the root's; …25 gives 5.
    return (MethodFallback.lastDigitBracket, [bracket, lastDigit, rootLine]);
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
  return (
    MethodFallback.lastDigitBracket,
    [bracket, lastDigit, decide, rootLine],
  );
}

/// Friendly fractions (a half, a quarter, a fifth, a tenth, a hundredth,
/// three quarters, eighths); else built from 100 %, 50 %, 25 %, 10 %, 5 %
/// and 1 %, each part whole (`doc/levels.md` v1.6: "never p × base ÷ 100");
/// else swapped (p % of B = B % of p) and built.
(MethodFallback, List<MethodLine>) _percentageFallback(PercentageExercise e) {
  final p = e.percent;
  final base = e.base;
  final answer = e.correctAnswer;
  (MethodFallback, List<MethodLine>) friendly(List<MethodLine> lines) =>
      (MethodFallback.friendlyFraction, lines);
  if (e.tenths != 0) {
    // Eighths: 37.5 % = 3 eighths.
    final eighths = (p * 10 + e.tenths) ~/ 125;
    return friendly([
      _then([_mul(_div(base, 8), eighths)]),
      _then([_mul(base ~/ 8, eighths)]),
      _then([answer]),
    ]);
  }
  switch (p) {
    case 50:
      return friendly([
        _then([_div(base, 2)]),
        _then([answer]),
      ]);
    case 25:
      return friendly([
        _then([_div(base, 4)]),
        _then([answer]),
      ]);
    case 20:
      return friendly([
        _then([_div(base, 5)]),
        _then([answer]),
      ]);
    case 10:
      return friendly([
        _then([_div(base, 10)]),
        _then([answer]),
      ]);
    case 1:
      return friendly([
        _then([_div(base, 100)]),
        _then([answer]),
      ]);
    case 75:
      return friendly([
        _then([_mul(_div(base, 4), 3)]),
        _then([_mul(base ~/ 4, 3)]),
        _then([answer]),
      ]);
    case 5 when base % 20 == 0:
      // Half of 10 %.
      return friendly([
        _then([_div(_div(base, 10), 2)]),
        _then([_div(base ~/ 10, 2)]),
        _then([answer]),
      ]);
  }
  // Above 100 %: the whole and a friendly rest (120 % of 45 = 45 + 45 ÷ 5).
  final share = p > 100 ? _friendlyShare(p - 100) : null;
  if (share != null) {
    final rest = (p - 100) * base;
    if (rest % 100 == 0) {
      final (n, d) = share;
      final restExpr = d == 1
          ? Num(base)
          : n == 1
          ? _div(base, d)
          : _mul(_div(base, d), n);
      return (
        MethodFallback.wholeAndRest,
        [
          _then([_add(base, restExpr)]),
          _then([_add(base, rest ~/ 100)]),
          _then([answer]),
        ],
      );
    }
  }
  if (base % 100 == 0 && p < 100) {
    return (MethodFallback.buildPercentage, _fromTensFivesOnes(p, base));
  }
  if (_build(p, base) case final parts?) {
    return (MethodFallback.buildPercentage, _buildLines(parts, base, answer));
  }
  if (_build(base, p) case final parts?) {
    final built = _buildLines(parts, p, answer);
    return (
      MethodFallback.swapAndBuild,
      [
        _then([PercentOf(base, p)]),
        ...built.take(3),
      ],
    );
  }
  // No whole build either way round: never for a question rules v9 draws
  // (tested over every one); kept so older rules' questions still get one.
  return (
    MethodFallback.productOver100,
    [
      _then([_div(_mul(p, base), 100)]),
      _then([_div(p * base, 100)]),
      _then([answer]),
    ],
  );
}

/// [p] % as a friendly share (n, d) — n d-ths: 10 % = (1, 10), 20 % =
/// (1, 5), 25 % = (1, 4), 50 % = (1, 2), 75 % = (3, 4), 100 % = (1, 1);
/// `null` for any other.
(int, int)? _friendlyShare(int p) => switch (p) {
  10 => (1, 10),
  20 => (1, 5),
  25 => (1, 4),
  50 => (1, 2),
  75 => (3, 4),
  100 => (1, 1),
  _ => null,
};
