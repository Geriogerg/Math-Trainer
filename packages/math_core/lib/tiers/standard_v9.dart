import '../models/exercise.dart';
import '../models/exercise_type.dart';
import '../patterns/pattern_parts.dart';
import 'question_space.dart';
import 'tier.dart';

/// The standard questions (not pattern questions) of [type] at [tier] under
/// **rules v9** (`doc/levels.md` v1.6, section 5): the tables as written,
/// with the drawing rules — at least 12 distinct questions per tier, every
/// distinct question equally likely (commutative forms once), no trivial
/// factor above T0 (no exponent 1, × 1, ÷ 1, 1 % or 100 % unless the tier
/// lists it), and both lengths of a "7- and 8-digit" row in every
/// combination. Built once per tier and kept.
QuestionSpace standardSpaceV9(ExerciseType type, Tier tier) =>
    _spaces[(type, tier)] ??= QuestionSpace.of(_forms(type, tier));

final _spaces = <(ExerciseType, Tier), QuestionSpace>{};

List<Form> _forms(ExerciseType type, Tier tier) => switch (type) {
  ExerciseType.addition => _addition(tier),
  ExerciseType.subtraction => _subtraction(tier),
  ExerciseType.multiplication => _multiplication(tier),
  ExerciseType.division => _division(tier),
  ExerciseType.power => _powers(tier),
  ExerciseType.squareRoot => _roots(tier),
  ExerciseType.percentage => _percentages(tier),
  ExerciseType.integral => _integrals(tier),
};

// ── Helpers ─────────────────────────────────────────────────────────────

/// Numbers of exactly [digits] digits.
Axis _digits(int digits) => Axis.range(pow10(digits - 1), pow10(digits) - 1);

/// The pairs of digits [x] (0–9) and [y] (0–9) that [keep] accepts, each as
/// `10 x + y`: one axis, so every valid pair is equally likely (v8 drew the
/// first digit, then the second among those left — 1 + 9 nine times as
/// often as 9 + 5).
Axis _digitPairs(bool Function(int x, int y) keep, {int low = 0}) => Axis.of([
  for (var x = low; x <= 9; x++)
    for (var y = low; y <= 9; y++)
      if (keep(x, y)) 10 * x + y,
]);

int _first(int pair) => pair ~/ 10;
int _second(int pair) => pair % 10;

int _number(List<int> digitsHighFirst) {
  var n = 0;
  for (final d in digitsHighFirst) {
    n = 10 * n + d;
  }
  return n;
}

Form _sums(Axis a, Axis b, {bool symmetric = false}) =>
    Form([a, b], (c) => sumOf(c[0], c[1]), symmetric: symmetric);

Form _differences(Axis a, Axis b) =>
    Form([a, b], (c) => differenceOf(c[0], c[1]));

Form _products(Axis a, Axis b, {bool symmetric = false}) =>
    Form([a, b], (c) => productOf(c[0], c[1]), symmetric: symmetric);

/// Divisor and quotient first, the dividend their product (rule 10).
Form _quotients(Axis divisors, Axis quotients) =>
    Form([divisors, quotients], (c) => quotientOf(c[0], c[1]));

/// [divisor] with every quotient that makes a dividend in [min, max].
Form _dividendsWithin(int divisor, int min, int max, {int minQuotient = 2}) {
  final low = (min + divisor - 1) ~/ divisor;
  return _quotients(
    Axis.of([divisor]),
    Axis.range(low > minQuotient ? low : minQuotient, max ~/ divisor),
  );
}

/// Two numbers of [digits] digits, the first the larger by its leading
/// digit (v8's construction: a borrow is never needed to stay positive).
Form _larger(int digits) {
  final rest = pow10(digits - 1);
  return Form(
    [
      _digitPairs((x, y) => y < x, low: 1),
      Axis.range(0, rest - 1),
      Axis.range(0, rest - 1),
    ],
    (c) =>
        differenceOf(_first(c[0]) * rest + c[1], _second(c[0]) * rest + c[2]),
  );
}

Form _powersOf(Axis bases, int exponent) =>
    Form([bases], (c) => PowerExercise(base: c[0], exponent: exponent));

Form _exponentsOf(int base, int low, int high) => Form([
  Axis.range(low, high),
], (c) => PowerExercise(base: base, exponent: c[0]));

Form _squareRoots(Axis roots) => Form([roots], (c) => squareRootOf(c[0]));

Form _cubeRoots(Axis roots) => Form([
  roots,
], (c) => SquareRootExercise(radicand: c[0] * c[0] * c[0], index: 3));

/// [percent] of every base in [min, max] that makes the answer whole — a
/// multiple of `100 / gcd(percent, 100)` (and of [roundTo]) — built from
/// the multiple (rule 10).
Form _percentOf(
  int percent,
  int min,
  int max, {
  int roundTo = 1,
  int tenths = 0,
}) {
  final whole = 1000 ~/ _gcd(10 * percent + tenths, 1000);
  final step = _lcm(whole, roundTo);
  return Form(
    [Axis.range((min + step - 1) ~/ step, max ~/ step)],
    (c) =>
        PercentageExercise(percent: percent, tenths: tenths, base: step * c[0]),
  );
}

int _gcd(int a, int b) => b == 0 ? a : _gcd(b, a % b);

int _lcm(int a, int b) => a ~/ _gcd(a, b) * b;

IntegralExercise _integral(int lower, int upper, Map<int, int> c) =>
    IntegralExercise(
      lower: lower,
      upper: upper,
      c0: c[0] ?? 0,
      c1: c[1] ?? 0,
      c2: c[2] ?? 0,
      c3: c[3] ?? 0,
      c4: c[4] ?? 0,
    );

/// 25, 35 … 95 and the tens 10 … 90 (T3 powers and roots).
final _fivesAndTens = [
  for (var b = 25; b <= 95; b += 10) b,
  for (var b = 10; b <= 90; b += 10) b,
];

// ── Addition ────────────────────────────────────────────────────────────

List<Form> _addition(Tier tier) => switch (tier) {
  // 1-digit + 1-digit, sum ≤ 10 (25 distinct; 9 + 1 was 11 % under v8).
  Tier.t0 => [
    Form.listed([
      for (var a = 1; a <= 9; a++)
        for (var b = a; b <= 10 - a; b++) sumOf(a, b),
    ], symmetric: true),
  ],
  // 1-digit + 1-digit crossing 10; 2-digit + 1-digit.
  Tier.t1 => [
    Form.listed([
      for (var a = 2; a <= 9; a++)
        for (var b = a; b <= 9; b++)
          if (a + b >= 11) sumOf(a, b),
    ], symmetric: true),
    _sums(Axis.range(10, 99), Axis.range(1, 9)),
  ],
  // 2-digit + 2-digit, with a carry from the units.
  Tier.t2 => [
    Form(
      [
        _digitPairs((x, y) => x + y >= 10, low: 1),
        Axis.range(1, 9),
        Axis.range(1, 9),
      ],
      (c) => sumOf(10 * c[1] + _first(c[0]), 10 * c[2] + _second(c[0])),
      symmetric: true,
    ),
  ],
  // 3-digit + 2-digit and 3-digit + 3-digit.
  Tier.t3 => [
    _sums(_digits(3), _digits(2)),
    _sums(_digits(3), _digits(3), symmetric: true),
  ],
  Tier.t4 => [_sums(_digits(4), _digits(3))],
  // 4-digit + 4-digit, carries out of the units and the tens at least.
  Tier.t5 => [
    Form(
      [
        _digitPairs((x, y) => x + y >= 10, low: 1),
        _digitPairs((x, y) => x + y >= 9),
        Axis.range(0, 9),
        Axis.range(0, 9),
        Axis.range(1, 9),
        Axis.range(1, 9),
      ],
      (c) => sumOf(
        _number([c[4], c[2], _first(c[1]), _first(c[0])]),
        _number([c[5], c[3], _second(c[1]), _second(c[0])]),
      ),
      symmetric: true,
    ),
  ],
  Tier.t6 => [_sums(_digits(5), _digits(5), symmetric: true)],
  Tier.t7 => [_sums(_digits(6), _digits(6), symmetric: true)],
  // "7- and 8-digit numbers": every combination, for both numbers.
  Tier.t8 => [
    _sums(_digits(7), _digits(7), symmetric: true),
    _sums(_digits(8), _digits(7)),
    _sums(_digits(8), _digits(8), symmetric: true),
  ],
  Tier.t9 => [_sums(_digits(9), _digits(9), symmetric: true)],
};

// ── Subtraction ─────────────────────────────────────────────────────────

List<Form> _subtraction(Tier tier) => switch (tier) {
  // Within 10, never below 1.
  Tier.t0 => [
    Form.listed([
      for (var a = 2; a <= 10; a++)
        for (var b = 1; b < a; b++) differenceOf(a, b),
    ]),
  ],
  // Teens − 1-digit crossing 10; 2-digit − 1-digit with a borrow.
  Tier.t1 => [
    Form.listed([
      for (var u = 1; u <= 8; u++)
        for (var b = u + 1; b <= 9; b++) differenceOf(10 + u, b),
      for (var t = 2; t <= 9; t++)
        for (var u = 0; u <= 8; u++)
          for (var b = u + 1; b <= 9; b++) differenceOf(10 * t + u, b),
    ]),
  ],
  // 2-digit − 2-digit, with a borrow.
  Tier.t2 => [
    Form(
      [_digitPairs((x, y) => x < y), _digitPairs((x, y) => y < x, low: 1)],
      (c) => differenceOf(
        10 * _first(c[1]) + _first(c[0]),
        10 * _second(c[1]) + _second(c[0]),
      ),
    ),
  ],
  // 3-digit − 2- and 3-digit across a zero: the minuend's tens are 0, its
  // units below the subtrahend's (403 − 178).
  Tier.t3 => [
    Form(
      [
        _digitPairs((x, y) => x < y),
        _digitPairs((x, y) => y < x, low: 1),
        Axis.range(0, 9),
      ],
      (c) => differenceOf(
        _number([_first(c[1]), 0, _first(c[0])]),
        _number([_second(c[1]), c[2], _second(c[0])]),
      ),
    ),
    Form(
      [_digitPairs((x, y) => x < y), Axis.range(1, 9), Axis.range(1, 9)],
      (c) => differenceOf(
        _number([c[1], 0, _first(c[0])]),
        _number([c[2], _second(c[0])]),
      ),
    ),
  ],
  Tier.t4 => [_differences(_digits(4), _digits(3))],
  // 4-digit − 4-digit, borrows from the units and the tens at least.
  Tier.t5 => [
    Form(
      [
        _digitPairs((x, y) => x < y),
        _digitPairs((x, y) => x <= y),
        Axis.range(0, 9),
        Axis.range(0, 9),
        _digitPairs((x, y) => y < x, low: 1),
      ],
      (c) => differenceOf(
        _number([_first(c[4]), c[2], _first(c[1]), _first(c[0])]),
        _number([_second(c[4]), c[3], _second(c[1]), _second(c[0])]),
      ),
    ),
  ],
  Tier.t6 => [_larger(5)],
  Tier.t7 => [_larger(6)],
  // "7- and 8-digit numbers": every combination that stays positive (v8
  // never drew an 8-digit second number, review m21).
  Tier.t8 => [_larger(7), _differences(_digits(8), _digits(7)), _larger(8)],
  Tier.t9 => [_larger(9)],
};

// ── Multiplication ──────────────────────────────────────────────────────

List<Form> _multiplication(Tier tier) => switch (tier) {
  // Tables 1–5 (× 1–10): × 1 at T0 only.
  Tier.t0 => [_products(Axis.range(1, 5), Axis.range(1, 10), symmetric: true)],
  // Tables 6–10 (× 2–10: no × 1 above T0).
  Tier.t1 => [_products(Axis.range(6, 10), Axis.range(2, 10), symmetric: true)],
  // 10–15 × 2–9; multiples of 10 × 2–9.
  Tier.t2 => [
    _products(Axis.range(10, 15), Axis.range(2, 9)),
    _products(Axis.of([for (var k = 2; k <= 9; k++) 10 * k]), Axis.range(2, 9)),
  ],
  // 16–25 × 2–9; 2-digit × 11.
  Tier.t3 => [
    _products(Axis.range(16, 25), Axis.range(2, 9)),
    _products(Axis.range(10, 99), Axis.of(const [11])),
  ],
  // Any 2-digit × 1-digit.
  Tier.t4 => [_products(Axis.range(10, 99), Axis.range(2, 9))],
  // 11–19 × 11–19; 2-digit × 5, 25, 50.
  Tier.t5 => [
    _products(Axis.range(11, 19), Axis.range(11, 19), symmetric: true),
    _products(Axis.range(10, 99), Axis.of(const [5, 25, 50])),
  ],
  // 2-digit × 2-digit up to 40 × 40; multiples of 10 × 2-digit.
  Tier.t6 => [
    _products(Axis.range(11, 40), Axis.range(11, 40), symmetric: true),
    _products(
      Axis.of([for (var k = 2; k <= 9; k++) 10 * k]),
      Axis.range(11, 99),
    ),
  ],
  // 3-digit × 1-digit.
  Tier.t7 => [_products(Axis.range(100, 999), Axis.range(2, 9))],
  // Any 2-digit × 2-digit.
  Tier.t8 => [
    _products(Axis.range(10, 99), Axis.range(10, 99), symmetric: true),
  ],
  // 3-digit × 2-digit up to 250 × 50.
  Tier.t9 => [_products(Axis.range(100, 250), Axis.range(10, 50))],
};

// ── Division: built from the multiplication of the same tier ──────────────

List<Form> _division(Tier tier) => switch (tier) {
  // Facts of tables 1–5.
  Tier.t0 => [_quotients(Axis.range(1, 5), Axis.range(1, 10))],
  // Facts of tables 6–10 (quotients 2–10, as the products).
  Tier.t1 => [_quotients(Axis.range(6, 10), Axis.range(2, 10))],
  // Dividends from 10–15 × 2–9; tens (560 ÷ 8 = 70).
  Tier.t2 => [
    _quotients(Axis.range(2, 9), Axis.range(10, 15)),
    _quotients(
      Axis.range(2, 9),
      Axis.of([for (var k = 2; k <= 9; k++) 10 * k]),
    ),
  ],
  // Dividends from 16–25 × 2–9.
  Tier.t3 => [_quotients(Axis.range(2, 9), Axis.range(16, 25))],
  // 3-digit ÷ 1-digit.
  Tier.t4 => [for (var d = 2; d <= 9; d++) _dividendsWithin(d, 100, 999)],
  // ÷ 11–19 (from 11–19 × 11–19); ÷ 5, 25, 50.
  Tier.t5 => [
    _quotients(Axis.range(11, 19), Axis.range(11, 19)),
    _quotients(Axis.of(const [5, 25, 50]), Axis.range(10, 99)),
  ],
  // 3-digit ÷ 2-digit up to 40.
  Tier.t6 => [for (var d = 11; d <= 40; d++) _dividendsWithin(d, 100, 999)],
  // 4-digit ÷ 1-digit.
  Tier.t7 => [for (var d = 2; d <= 9; d++) _dividendsWithin(d, 1000, 9999)],
  // 4-digit ÷ 2-digit.
  Tier.t8 => [for (var d = 11; d <= 99; d++) _dividendsWithin(d, 1000, 9999)],
  // 4-digit ÷ 2-digit with a 3-digit quotient.
  Tier.t9 => [
    for (var d = 11; d <= 99; d++)
      _dividendsWithin(d, 1000, 9999, minQuotient: 100),
  ],
};

// ── Powers (spec v1.6: new T0–T2 and T6 rows) ───────────────────────────

List<Form> _powers(Tier tier) => switch (tier) {
  // Squares 2–12; 2³.
  Tier.t0 => [_powersOf(Axis.range(2, 12), 2), _exponentsOf(2, 3, 3)],
  // Squares 11–16; 2⁴–2⁷; 3³, 4³.
  Tier.t1 => [
    _powersOf(Axis.range(11, 16), 2),
    _exponentsOf(2, 4, 7),
    _powersOf(Axis.of(const [3, 4]), 3),
  ],
  // Squares 17–22; cubes 2–5; 2⁸; 3⁴.
  Tier.t2 => [
    _powersOf(Axis.range(17, 22), 2),
    _powersOf(Axis.range(2, 5), 3),
    _exponentsOf(2, 8, 8),
    _exponentsOf(3, 4, 4),
  ],
  // Squares of 25, 35 … 95 and tens.
  Tier.t3 => [_powersOf(Axis.of(_fivesAndTens), 2)],
  // Squares 21–30; 2⁷–2¹⁰.
  Tier.t4 => [_powersOf(Axis.range(21, 30), 2), _exponentsOf(2, 7, 10)],
  // Squares 31–50; cubes 6–10.
  Tier.t5 => [
    _powersOf(Axis.range(31, 50), 2),
    _powersOf(Axis.range(6, 10), 3),
  ],
  // Squares 51–70; 3³–3⁶ (v8: from 3¹, review m11).
  Tier.t6 => [_powersOf(Axis.range(51, 70), 2), _exponentsOf(3, 3, 6)],
  // Squares 71–100.
  Tier.t7 => [_powersOf(Axis.range(71, 100), 2)],
  // Squares 101–125; cubes 11–15.
  Tier.t8 => [
    _powersOf(Axis.range(101, 125), 2),
    _powersOf(Axis.range(11, 15), 3),
  ],
  // Squares 126–200; 5⁴, 6⁴, 7⁴.
  Tier.t9 => [
    _powersOf(Axis.range(126, 200), 2),
    _powersOf(Axis.range(5, 7), 4),
  ],
};

// ── Roots (spec v1.6: no longer a strict mirror of powers) ───────────────

List<Form> _roots(Tier tier) => switch (tier) {
  // √ of squares 2–13.
  Tier.t0 => [_squareRoots(Axis.range(2, 13))],
  // √ of squares 11–20; ∛ of cubes 2–3.
  Tier.t1 => [_squareRoots(Axis.range(11, 20)), _cubeRoots(Axis.range(2, 3))],
  // √ of squares 21–30; ∛ of cubes 4–6.
  Tier.t2 => [_squareRoots(Axis.range(21, 30)), _cubeRoots(Axis.range(4, 6))],
  // √ of squares of 25, 35 … 95 and tens.
  Tier.t3 => [_squareRoots(Axis.of(_fivesAndTens))],
  // √ of squares 31–40; ∛ of cubes 7–8.
  Tier.t4 => [_squareRoots(Axis.range(31, 40)), _cubeRoots(Axis.range(7, 8))],
  // √ of squares 41–60; ∛ of cubes 9–10.
  Tier.t5 => [_squareRoots(Axis.range(41, 60)), _cubeRoots(Axis.range(9, 10))],
  // √ of squares 61–80.
  Tier.t6 => [_squareRoots(Axis.range(61, 80))],
  // √ of squares 81–100.
  Tier.t7 => [_squareRoots(Axis.range(81, 100))],
  // √ of squares 101–125; ∛ of cubes 11–15.
  Tier.t8 => [
    _squareRoots(Axis.range(101, 125)),
    _cubeRoots(Axis.range(11, 15)),
  ],
  // √ of squares 126–200.
  Tier.t9 => [_squareRoots(Axis.range(126, 200))],
};

// ── Percentages ─────────────────────────────────────────────────────────

List<Form> _percentages(Tier tier) => switch (tier) {
  // 50 %, 10 % of tens up to 100.
  Tier.t0 => [_percentOf(50, 10, 100, roundTo: 10), _percentOf(10, 10, 100)],
  // 25 %, 20 % of round numbers (up to 200).
  Tier.t1 => [
    _percentOf(25, 10, 200, roundTo: 10),
    _percentOf(20, 10, 200, roundTo: 10),
  ],
  // 10 %, 20 %, 50 % of 2-digit and 3-digit numbers.
  Tier.t2 => [
    for (final p in const [10, 20, 50]) _percentOf(p, 10, 999),
  ],
  // 5 %, 75 %.
  Tier.t3 => [
    for (final p in const [5, 75]) _percentOf(p, 10, 400),
  ],
  // 1 %, 15 %, 30 %, 40 % of hundreds (1 % listed here).
  Tier.t4 => [
    for (final p in const [1, 15, 30, 40])
      _percentOf(p, 100, 900, roundTo: 100),
  ],
  // Any multiple of 5 %.
  Tier.t5 => [for (var p = 5; p <= 95; p += 5) _percentOf(p, 20, 400)],
  // Any whole percentage of a round hundred — but 1 %, listed at T4 only.
  Tier.t6 => [
    for (var p = 2; p <= 99; p++) _percentOf(p, 100, 900, roundTo: 100),
  ],
  // 12.5 %, 37.5 %, 62.5 %, 87.5 % (eighths) of multiples of 8.
  Tier.t7 => [
    for (final p in const [12, 37, 62, 87]) _percentOf(p, 16, 200, tenths: 5),
  ],
  // Above 100 %, of 2-digit numbers.
  Tier.t8 => [
    for (final p in const [110, 120, 125, 150, 175, 200]) _percentOf(p, 10, 99),
  ],
  // Any whole percentage of a 3-digit base, whole result — but 1 %.
  Tier.t9 => [for (var p = 2; p <= 99; p++) _percentOf(p, 100, 999)],
};

// ── Integrals (spec v1.6: new T1 and T4 rows) ───────────────────────────

List<Form> _integrals(Tier tier) => switch (tier) {
  // A constant, from 0: ∫₀⁴ 3 dx.
  Tier.t0 => [
    Form([
      Axis.range(1, 9),
      Axis.range(1, 6),
    ], (c) => _integral(0, c[1], {0: c[0]})),
  ],
  // 2x or 4x, from 0, upper bound 2–10.
  Tier.t1 => [
    Form([
      Axis.of(const [2, 4]),
      Axis.range(2, 10),
    ], (c) => _integral(0, c[1], {1: c[0]})),
  ],
  // 2x from a to b: ∫₂⁵ 2x dx.
  Tier.t2 => [
    Form([
      Axis.range(1, 6),
      Axis.range(1, 4),
    ], (c) => _integral(c[0], c[0] + c[1], {1: 2})),
  ],
  // 2x + c from 0: ∫₀³ (2x + 4) dx.
  Tier.t3 => [
    Form([
      Axis.range(1, 9),
      Axis.range(1, 6),
    ], (c) => _integral(0, c[1], {1: 2, 0: c[0]})),
  ],
  // 3x² or 6x², from 0, upper bound 2–7.
  Tier.t4 => [
    Form([
      Axis.of(const [3, 6]),
      Axis.range(2, 7),
    ], (c) => _integral(0, c[1], {2: c[0]})),
  ],
  // 3x² from a to b: ∫₁³ 3x² dx.
  Tier.t5 => [
    Form([
      Axis.range(1, 4),
      Axis.range(1, 3),
    ], (c) => _integral(c[0], c[0] + c[1], {2: 3})),
  ],
  // Degree 2 with a linear term: ∫₀² (3x² + 2x) dx.
  Tier.t6 => [
    Form([
      Axis.of(const [3, 6]),
      Axis.of(const [2, 4, 6, 8]),
      Axis.range(0, 2),
      Axis.range(1, 3),
    ], (c) => _integral(c[2], c[2] + c[3], {2: c[0], 1: c[1]})),
  ],
  // 4x³ from 0 or from 1, upper bound 2–7 (v8 stopped at 5: 8 questions,
  // under the 12 a tier must offer).
  Tier.t7 => [
    Form([
      Axis.range(0, 1),
      Axis.range(2, 7),
    ], (c) => _integral(c[0], c[1], {3: 4})),
  ],
  // Degree 3 mixed: ∫₀² (4x³ + 6x) dx.
  Tier.t8 => [
    Form(
      [
        Axis.of(const [4, 8]),
        Axis.of(const [0, 3, 6]),
        Axis.of(const [2, 4, 6, 8]),
        Axis.range(0, 3),
        Axis.range(0, 2),
        Axis.range(1, 2),
      ],
      (c) => _integral(c[4], c[4] + c[5], {3: c[0], 2: c[1], 1: c[2], 0: c[3]}),
    ),
  ],
  // Degree 3–4 with a second term, negative half the time, wider bounds:
  // v8's construction, every case listed — the integrand ≥ 0 on [a, b].
  Tier.t9 => [Form.listed(_degree3To4)],
};

final List<Exercise> _degree3To4 = [
  for (var degree = 3; degree <= 4; degree++)
    for (var lead = 1; lead <= 2; lead++)
      for (var j = 1; j <= degree - 1; j++) ...[
        // Negative: the leading term covers |cj| from the lower bound on.
        for (var a = 1; a <= 3; a++)
          for (
            var m = 1;
            m <=
                _min(3, (degree + 1) * lead * _power(a, degree - j) ~/ (j + 1));
            m++
          )
            for (var w = 1; w <= 3; w++)
              _integral(a, a + w, {
                degree: (degree + 1) * lead,
                j: -(j + 1) * m,
              }),
        for (var a = 0; a <= 3; a++)
          for (var m = 1; m <= 3; m++)
            for (var w = 1; w <= 3; w++)
              _integral(a, a + w, {
                degree: (degree + 1) * lead,
                j: (j + 1) * m,
              }),
      ],
];

int _min(int a, int b) => a < b ? a : b;

int _power(int x, int n) {
  var r = 1;
  for (var i = 0; i < n; i++) {
    r *= x;
  }
  return r;
}
