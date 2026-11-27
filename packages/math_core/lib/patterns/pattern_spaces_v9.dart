import '../models/exercise.dart';
import '../models/exercise_type.dart';
import '../strategies/strategy.dart';
import '../tiers/question_space.dart';
import '../tiers/tier.dart';
import 'pattern_family.dart';
import 'pattern_parts.dart';

/// The questions [family] asks at [tier] under **rules v9** (`doc/levels.md`
/// v1.6, section 5b), as a [QuestionSpace]: each distinct question equally
/// likely, drawn by a game without repeats ([OperationDraws]). Throws for a
/// tier below the family's first (rule 13). Built once and kept.
///
/// v1.6 against v5–v8 (`patternQuestionV5`, `patternQuestion`):
/// - **uniform within a family**: v5 drew a form first (a coin), then its
///   numbers — `× 99` was half of `× 9s` at T5;
/// - **the new size rows**: Swap (bases 25–50, then 125–500, 1 250–5 000,
///   12 500–50 000), round-number division (dividends up to 5, 7, 9 digits,
///   quotient never below 10), ∛ of round cubes ((20–50)³, then (20–90)³
///   and (200–500)³), ∫₀ᵇ 2x up to b = 50 and 100, ∫₀ᵇ 3x² up to b = 12;
/// - **√ of powers of 2 mirrors powers of 2 two tiers later** (v1.6's row;
///   v6 sized it by its own row): one to three questions per band;
/// - **families grow**: a family outside the size table whose numbers
///   stayed the same over three tiers grows tier by tier (its range's top
///   end rises), so its median answer rises at least every two tiers;
/// - **repunits** take 11² and 11⁵, 111³ where the hard limit allows: with
///   v8's three questions per band the family would never be asked.
/// A family with fewer than 4 distinct questions at a tier is skipped there
/// ([familiesAtV9]).
QuestionSpace familySpaceV9(PatternFamily family, Tier tier) {
  if (tier.index < family.from.index) {
    throw ArgumentError.value(
      tier,
      'tier',
      'is below ${family.name}\'s first tier (${family.from.label}).',
    );
  }
  return _spaces[(family, tier)] ??= QuestionSpace.of(_forms(family, tier));
}

final _spaces = <(PatternFamily, Tier), QuestionSpace>{};

/// The families of [type] a v9 game draws at [tier], in declaration order:
/// started by [tier], with at least [minDistinctFamily] distinct questions
/// there — "no repetitive families" (spec v1.6 section 5b): a family below
/// that is skipped, its share going to the others.
List<PatternFamily> familiesAtV9(ExerciseType type, Tier tier) =>
    _available[(type, tier)] ??= List.unmodifiable([
      for (final f in PatternFamily.availableAt(type, tier))
        if (familySpaceV9(f, tier).distinct >= minDistinctFamily) f,
    ]);

final _available = <(ExerciseType, Tier), List<PatternFamily>>{};

/// The fewest distinct questions a family must offer at a tier.
const minDistinctFamily = 4;

// ── Helpers ─────────────────────────────────────────────────────────────

/// The standard operand size of addition and subtraction per tier
/// (`doc/levels.md` section 5, the larger operand): T0 1 digit … T9 9.
const _sumDigits = [1, 2, 2, 3, 4, 4, 5, 6, 8, 9];

Axis _digits(int digits) =>
    Axis.range(digits == 1 ? 1 : pow10(digits - 1), pow10(digits) - 1);

/// −[max] … −1 and 1 … [max].
Axis _signed(int max) => Axis.of([
  for (var k = -max; k <= max; k++)
    if (k != 0) k,
]);

/// [low] … [high]'s top end rising over a family's plateau: at the [k]-th
/// (0-based) of [n] tiers, up to `low + (high − low) × (k + 1) / n` — so
/// the median rises every tier (spec v1.6, "Families grow").
Axis _growing(int low, int high, int k, int n) =>
    Axis.range(low, low + (high - low) * (k + 1) ~/ n);

/// Quotients making `divisor × quotient` exactly [digits] digits long.
Axis _quotientsWithDigits(int divisor, int digits) => Axis.range(
  (pow10(digits - 1) + divisor - 1) ~/ divisor,
  (pow10(digits) - 1) ~/ divisor,
);

Form _f(List<Axis> axes, Exercise Function(List<int> c) build) =>
    Form(axes, build);

Form _symmetric(List<Axis> axes, Exercise Function(List<int> c) build) =>
    Form(axes, build, symmetric: true);

Form _list(List<Exercise> questions) => Form.listed(questions);

/// [divisor] with the quotients that give dividends of [digits] digits.
Form _quotientsOf(int divisor, int digits) => _f([
  _quotientsWithDigits(divisor, digits),
], (c) => quotientOf(divisor, c[0]));

PowerExercise _power(int base, int exponent) =>
    PowerExercise(base: base, exponent: exponent);

// ── Families ────────────────────────────────────────────────────────────

List<Form> _forms(PatternFamily family, Tier tier) {
  final t = tier.index;
  return switch (family) {
    // ── Addition: operands of the tier's standard size D ─────────────────
    // 48 + 49, 250 + 251; from 6 + 6 at T1 (crossing 10).
    PatternFamily.doubles => [
      _f([
        t == 1 ? Axis.range(6, 99) : _digits(_sumDigits[t]),
        Axis.range(0, 1),
      ], (c) => sumOf(c[0], c[0] + c[1])),
    ],
    // 37 + 63, 418 + 582: both D digits, the units never 0.
    PatternFamily.complements => () {
      final k = _sumDigits[t];
      return [
        _symmetric([
          Axis.range(pow10(k - 2), 9 * pow10(k - 2) - 1),
          Axis.range(1, 9),
        ], (c) => sumOf(10 * c[0] + c[1], pow10(k) - 10 * c[0] - c[1])),
      ];
    }(),
    // 65 + 98, 347 + 199.
    PatternFamily.addJustBelowRound => () {
      final d = _sumDigits[t];
      return [
        _f([
          _digits(d),
          Axis.range(2, 10),
          Axis.range(1, 3),
        ], (c) => sumOf(c[0], c[1] * pow10(d - 1) - c[2])),
      ];
    }(),
    // 350 + 450 at T3, 3 500 + 4 500 at T4, 250 000 + 750 000 at T7.
    PatternFamily.roundNumbers => () {
      final unit = pow10(_sumDigits[t] - 2);
      return [
        _symmetric([
          Axis.range(11, 99),
          Axis.range(11, 99),
        ], (c) => sumOf(unit * c[0], unit * c[1])),
      ];
    }(),
    // 27 + 46 + 73 at T4–T5; 3-digit terms at T6 …
    PatternFamily.threeTerms => () {
      final k = _sumDigits[t] - 2;
      return [
        _f(
          [
            Axis.range(pow10(k - 2), 9 * pow10(k - 2) - 1),
            Axis.range(1, 9),
            _digits(k),
          ],
          (c) =>
              threeTermsOf(10 * c[0] + c[1], c[2], pow10(k) - 10 * c[0] - c[1]),
        ),
      ];
    }(),
    // 4 562 + 998 at T5, 73 845 + 9 999 at T6.
    PatternFamily.addJustBelowPowerOf10 => () {
      final d = _sumDigits[t];
      return [
        _f([
          _digits(d),
          Axis.range(1, 3),
        ], (c) => sumOf(c[0], pow10(d - 1) - c[1])),
      ];
    }(),

    // ── Subtraction: the first operand of the tier's standard size D ─────
    // 742 − 198 at T3, 9 856 − 996 at T4.
    PatternFamily.subtractJustBelowRound => () {
      final d = _sumDigits[t];
      return [
        for (var m = 1; m <= 9; m++)
          _f([
            Axis.range(m * pow10(d - 1), pow10(d) - 1),
            Axis.range(1, 4),
          ], (c) => differenceOf(c[0], m * pow10(d - 1) - c[1])),
      ];
    }(),
    // 1 000 − 357, 10 000 − 2 486 at T4: e digits under 10^e, never a
    // multiple of 10 (the borrow runs all the way).
    PatternFamily.fromRound => () {
      final d = _sumDigits[t];
      return [
        for (var e = d - 1; e <= d; e++)
          _f([
            Axis.range(pow10(e - 2), pow10(e - 1) - 1),
            Axis.range(1, 9),
          ], (c) => differenceOf(pow10(e), 10 * c[0] + c[1])),
      ];
    }(),
    // 5 003 − 4 997 at T4.
    PatternFamily.acrossRound => () {
      final d = _sumDigits[t];
      return [
        _f([
          Axis.range(pow10(d - 3), pow10(d - 2) - 1),
          Axis.range(1, 9),
          Axis.range(1, 9),
        ], (c) => differenceOf(100 * c[0] + c[1], 100 * c[0] - c[2])),
      ];
    }(),
    // 803 − 497 at T5: one digit under the tier's standard size, the shift
    // is the point.
    PatternFamily.sameGapShift => () {
      final d = _sumDigits[t] - 1;
      return [
        for (var m = 2; m <= 9; m++)
          _f([
            Axis.range(m * pow10(d - 1) + 1, pow10(d) - 1),
            Axis.range(1, 9),
          ], (c) => differenceOf(c[0], m * pow10(d - 1) - c[1])),
      ];
    }(),
    // 84 312 − 9 998 at T6.
    PatternFamily.subtractJustBelowPowerOf10 => () {
      final d = _sumDigits[t];
      return [
        _f([
          _digits(d),
          Axis.range(1, 3),
        ], (c) => differenceOf(c[0], pow10(d - 1) - c[1])),
      ];
    }(),

    // ── Multiplication ───────────────────────────────────────────────────
    // Size table: T2 2-digit × 5 · T4 3-digit · T6 4-digit.
    PatternFamily.times5 => switch (t) {
      < 4 => [
        _f([Axis.range(11, 99)], (c) => productOf(c[0], 5)),
      ],
      _ => [
        _f([
          _digits(t < 6 ? 3 : 4),
          Axis.of(const [5, 50]),
        ], (c) => productOf(c[0], c[1])),
      ],
    },
    // 43 × 11; 352 × 11 from T5, growing to 909 × 11 by T7; any 3-digit
    // number from T8.
    PatternFamily.times11 => [
      _f([
        switch (t) {
          < 5 => Axis.range(12, 99),
          < 8 => _growing(100, 909, t - 5, 3),
          _ => _digits(3),
        },
      ], (c) => productOf(c[0], 11)),
    ],
    // 98 × 7, 103 × 8; around 1 000 from T6.
    PatternFamily.nearBase =>
      t < 6
          ? [
              _f([
                _signed(5),
                Axis.range(2, 9),
              ], (c) => productOf(100 + c[0], c[1])),
            ]
          : [
              _f([
                _signed(9),
                t < 8 ? Axis.range(2, 9) : Axis.range(11, 19),
              ], (c) => productOf(1000 + c[0], c[1])),
            ],
    // 36 × 25, 88 × 125: growing over T5–T7; 3-digit × 25 and up to
    // 99 × 125 from T8.
    PatternFamily.times25 => [
      _f([
        t < 8 ? _growing(12, 99, t - 5, 3) : _digits(3),
      ], (c) => productOf(c[0], 25)),
      _f([
        t < 8 ? _growing(12, 79, t - 5, 3) : Axis.range(12, 99),
      ], (c) => productOf(c[0], 125)),
    ],
    // 17 × 23, 47 × 53: middles 20–50 at T5 growing to 20–90 by T7;
    // around 100–300 from T8.
    PatternFamily.differenceOfSquares => [
      _f([
        t < 8 ? _growing(2, 9, t - 5, 3) : Axis.range(10, 30),
        Axis.range(1, 9),
      ], (c) => productOf(10 * c[0] - c[1], 10 * c[0] + c[1])),
    ],
    // 16 × 35 (= 8 × 70).
    PatternFamily.doublingHalving => [
      _f([
        t < 8 ? _growing(6, 24, t - 5, 3) : Axis.range(25, 49),
        Axis.range(1, 9),
      ], (c) => productOf(2 * c[0], 5 * (2 * c[1] + 1))),
    ],
    // 47 × 99, 236 × 999 (T9); growing over T5–T7.
    PatternFamily.times9s => switch (t) {
      < 8 => [
        _f([_growing(100, 999, t - 5, 3)], (c) => productOf(c[0], 9)),
        _f([_growing(12, 99, t - 5, 3)], (c) => productOf(c[0], 99)),
      ],
      8 => [
        _f([_digits(3)], (c) => productOf(c[0], 99)),
        _f([Axis.range(12, 99)], (c) => productOf(c[0], 999)),
      ],
      _ => [
        _f([_digits(3)], (c) => productOf(c[0], 999)),
      ],
    },
    // 43 × 47; 113 × 117 from T8.
    PatternFamily.sameTensUnitsTo10 => [
      _symmetric([
        t < 8 ? Axis.range(1, 9) : Axis.range(10, 31),
        Axis.range(1, 9),
      ], (c) => productOf(10 * c[0] + c[1], 10 * c[0] + 10 - c[1])),
    ],
    // 47 × 101.
    PatternFamily.times101 => [
      _f([
        switch (t) {
          < 8 => Axis.range(11, 99),
          8 => Axis.range(100, 990),
          _ => _digits(3),
        },
      ], (c) => productOf(c[0], 101)),
    ],
    // 64 × 32: the product 2^(a + b), at most 2¹³ at T6–T7, 2¹⁶ at T8, 2¹⁸
    // at T9.
    PatternFamily.powersOf2Product => () {
      final sum = switch (t) {
        < 8 => 13,
        8 => 16,
        _ => 18,
      };
      return [
        Form.listed([
          for (var a = 3; a <= 9; a++)
            for (var b = a; b <= 9; b++)
              if (a + b <= sum) productOf(powerOf2(a), powerOf2(b)),
        ], symmetric: true),
      ];
    }(),
    // T7: 97 × 96, or 98 × 102 with the one above no further than the one
    // below (the product under 10 000); both 100 ± 9 from T8.
    PatternFamily.bothNear100 =>
      t >= 8
          ? [
              _symmetric([
                _signed(9),
                _signed(9),
              ], (c) => productOf(100 + c[0], 100 + c[1])),
            ]
          : [
              _symmetric([
                Axis.range(1, 9),
                Axis.range(1, 9),
              ], (c) => productOf(100 - c[0], 100 - c[1])),
              _list([
                for (var below = 1; below <= 9; below++)
                  for (var above = 1; above <= below; above++)
                    productOf(100 - below, 100 + above),
              ]),
            ],
    // 195 × 205 (T9).
    PatternFamily.differenceOfSquaresHundreds => [
      _f([
        Axis.range(1, 5),
        Axis.range(1, 9),
      ], (c) => productOf(100 * c[0] - c[1], 100 * c[0] + c[1])),
    ],

    // ── Division: the divisor and the quotient first ─────────────────────
    // Size table: T2 up to 3 digits · T4 4 digits · T6 6 digits.
    PatternFamily.halveBig => [
      for (final digits in switch (t) {
        < 4 => const [2, 3],
        < 6 => const [4],
        _ => const [5, 6],
      })
        _quotientsOf(2, digits),
    ],
    // Size table (v9): T4 dividends up to 5 digits (36 000 ÷ 400) · T6 up
    // to 7 · T8 up to 9 · the quotient never below 10. A divisor a × 10^m
    // and a quotient q × 10^n; the dividend's length is the band's.
    PatternFamily.roundDivision => () {
      final (low, high) = switch (t) {
        < 6 => (3, 5),
        < 8 => (6, 7),
        _ => (8, 9),
      };
      return [
        _list([
          for (var a = 2; a <= 9; a++)
            for (var m = 1; m <= 7; m++)
              for (var q = 2; q <= 12; q++)
                for (var n = 0; n <= 7; n++)
                  if (q * pow10(n) >= 10)
                    if (_lengthOf(a * q) + m + n case final d
                        when d >= low && d <= high)
                      quotientOf(a * pow10(m), q * pow10(n)),
        ]),
      ];
    }(),
    // Size table: T5 up to 4 digits · T7 6 digits.
    PatternFamily.bigBy3To5 => [
      for (var divisor = 3; divisor <= 5; divisor++)
        for (final digits in t < 7 ? const [3, 4] : const [5, 6])
          _quotientsOf(divisor, digits),
    ],
    // 4 875 ÷ 25: dividends growing over T5–T8, 5-digit at T9.
    PatternFamily.by25 => [
      _f([
        t < 9 ? _growing(40, 399, t - 5, 4) : Axis.range(400, 3999),
      ], (c) => quotientOf(25, c[0])),
      _f([
        t < 9 ? _growing(8, 79, t - 5, 4) : Axis.range(80, 799),
      ], (c) => quotientOf(125, c[0])),
    ],
    // 473 ÷ 11.
    PatternFamily.by11 => [
      _f([
        switch (t) {
          < 8 => Axis.range(12, 99),
          8 => Axis.range(100, 909),
          _ => _digits(3),
        },
      ], (c) => quotientOf(11, c[0])),
    ],
    // 7 344 ÷ 8: 4-digit dividends, from 1 000–3 999 at T6 up to 9 999 at
    // T8; 5-digit at T9.
    PatternFamily.halvingChain => [
      for (final divisor in const [8, 16])
        if (t < 9)
          _f([
            _growing(
              (1000 + divisor - 1) ~/ divisor,
              9999 ~/ divisor,
              t - 6,
              3,
            ),
          ], (c) => quotientOf(divisor, c[0]))
        else
          _quotientsOf(divisor, 5),
    ],
    // Size table: T7 up to 5 digits · T9 7 digits.
    PatternFamily.bigBy6To9 => [
      for (var divisor = 6; divisor <= 9; divisor++)
        for (final digits in t < 9 ? const [4, 5] : const [6, 7])
          _quotientsOf(divisor, digits),
    ],

    // ── Powers ────────────────────────────────────────────────────────────
    // Size table: T1 up to 2⁶ · T3 2⁸ · T5 2¹⁰ · T7 2¹⁶ · T9 2²⁰ — two
    // questions a band below T7: skipped there (fewer than 4).
    PatternFamily.powersOf2 => () {
      final (low, high) = _powersOf2Band(t);
      return [
        _f([Axis.range(low, high)], (c) => _power(2, c[0])),
      ];
    }(),
    // Size table: T3 up to 95² · T6 up to 205². From 25², T3's own.
    PatternFamily.squaresEndingIn5 => [
      _f([
        t < 6 ? Axis.range(2, 9) : Axis.range(10, 20),
      ], (c) => _power(10 * c[0] + 5, 2)),
    ],
    // Size table: T4 up to 3⁴, 4³, 5³ · T6 3⁶, 4⁵, 5⁴ · T8 3⁸.
    PatternFamily.powersOf3To5 => [
      for (var base = 3; base <= 5; base++)
        () {
          final (low, high) = _powersOf3To5Band(t, base);
          return _f([Axis.range(low, high)], (c) => _power(base, c[0]));
        }(),
    ],
    // 48², 97² at T5–T6; 103² from T7 (5 digits).
    PatternFamily.squaresNear50And100 =>
      t < 7
          ? [
              _f([_signed(5)], (c) => _power(50 + c[0], 2)),
              _f([Axis.range(1, 5)], (c) => _power(100 - c[0], 2)),
            ]
          : [
              _f([_signed(9)], (c) => _power(100 + c[0], 2)),
            ],
    // 11³ = 1 331, 111² = 12 321: within the hard limit, 11² and 11³ at
    // T6 (skipped: two questions), 11²–11⁴ and 111² at T7–T8, and the
    // larger ones at T9.
    PatternFamily.repunits => [
      _list(switch (t) {
        < 7 => [_power(11, 2), _power(11, 3)],
        < 9 => [_power(11, 2), _power(11, 3), _power(11, 4), _power(111, 2)],
        _ => [
          _power(11, 4),
          _power(11, 5),
          _power(111, 2),
          _power(111, 3),
          _power(1111, 2),
        ],
      }),
    ],
    // 997² = 994 009 (T9).
    PatternFamily.squaresNear1000 => [
      _f([_signed(9)], (c) => _power(1000 + c[0], 2)),
    ],

    // ── Roots: the root first ─────────────────────────────────────────────
    // v1.6's row: the mirror of powers of 2, two tiers later — the even
    // exponents of that band: one to three questions, skipped everywhere.
    PatternFamily.rootsOfPowersOf2 => () {
      final (low, high) = _powersOf2Band(t - 2);
      return [
        _f([
          Axis.range((low + 1) ~/ 2, high ~/ 2),
        ], (c) => squareRootOf(powerOf2(c[0]))),
      ];
    }(),
    // √625 … √9 025 (T3's squares, the mirror of squares ending in 5),
    // from √625–√3 025 at T3 up to √9 025 at T6; √11 025 … √42 025 from T7.
    PatternFamily.rootsEndingIn25 => [
      _f([
        t < 7 ? Axis.range(2, const [5, 6, 7, 9][t - 3]) : Axis.range(10, 20),
      ], (c) => squareRootOf(10 * c[0] + 5)),
    ],
    // √9 409 at T5–T6; √10 201 from T7.
    PatternFamily.rootsNear100 => [
      _f([
        t < 7 ? Axis.range(-9, -1) : _signed(9),
      ], (c) => squareRootOf(100 + c[0])),
    ],
    // ∛1 331, and round cubes — size table (v9): T6 (20–50)³ · T8 (20–90)³
    // and (200–500)³.
    PatternFamily.cubeRootsRepunitAndRound => [
      _list([
        for (final root in [
          11,
          ...[for (var r = 20; r <= (t < 8 ? 50 : 90); r += 10) r],
          if (t >= 8) ...[for (var r = 200; r <= 500; r += 100) r],
        ])
          SquareRootExercise(radicand: root * root * root, index: 3),
      ]),
    ],
    // √994 009 (T9).
    PatternFamily.rootsNear1000 => [
      _f([_signed(9)], (c) => squareRootOf(1000 + c[0])),
    ],

    // ── Percentages: the percentage first, a base that makes it whole ─────
    // Size table: T2 up to 3 digits · T4 4 digits · T6 6 digits.
    PatternFamily.halfAndQuarterOfBig => [
      for (final (percent, share) in const [(50, 2), (25, 4)])
        for (final digits in switch (t) {
          < 4 => const [2, 3],
          < 6 => const [4],
          _ => const [5, 6],
        })
          _f([
            _quotientsWithDigits(share, digits),
          ], (c) => PercentageExercise(percent: percent, base: share * c[0])),
    ],
    // Size table (v9): T3 2-digit bases (8 % of 25) · T5 bases 125, 250,
    // 500 (36 % of 250) · T7 1 250, 2 500, 5 000 · T9 up to 50 000. Every
    // percentage that makes the answer whole and is not already a
    // friendly one.
    PatternFamily.swap => [
      for (final base in switch (t) {
        < 5 => const [25, 50],
        < 7 => const [125, 250, 500],
        < 9 => const [1250, 2500, 5000],
        _ => const [12500, 25000, 50000],
      })
        _list([
          for (var p = 2; p <= 98; p++)
            if (!friendlyPercentages.contains(p) && p * base % 100 == 0)
              PercentageExercise(percent: p, base: base),
        ]),
    ],
    // 15 % of 2 400 000: an even 2-digit lead keeps the answer at three
    // significant digits.
    PatternFamily.percentOfBigRound => [
      for (final e in switch (t) {
        < 7 => const [2, 3],
        < 9 => const [4, 5],
        _ => const [5, 6],
      })
        _f([
          Axis.of(multiplesOf5),
          Axis.range(6, 49),
        ], (c) => PercentageExercise(percent: c[0], base: 2 * c[1] * pow10(e))),
    ],
    // 99 % of 300, 125 % of 64; 101 %, 200 %.
    PatternFamily.nearHundredPercent => [
      _f([
        Axis.range(1, 9),
      ], (c) => PercentageExercise(percent: 99, base: 100 * c[0])),
      _f([
        Axis.range(1, 9),
      ], (c) => PercentageExercise(percent: 101, base: 100 * c[0])),
      _f([
        Axis.range(3, 50),
      ], (c) => PercentageExercise(percent: 125, base: 4 * c[0])),
      _f([
        Axis.range(11, t < 9 ? 499 : 999),
      ], (c) => PercentageExercise(percent: 200, base: c[0])),
    ],

    // ── Integrals ─────────────────────────────────────────────────────────
    // Size table (v9): T1 b ≤ 6 · T3 b ≤ 12 · T5 b ≤ 25 · T7 b ≤ 50 · T9
    // b ≤ 100.
    PatternFamily.twoXFromZero => () {
      final (low, high) = switch (t) {
        < 3 => (3, 6),
        < 5 => (7, 12),
        < 7 => (13, 25),
        < 9 => (26, 50),
        _ => (51, 100),
      };
      return [
        _f([Axis.range(low, high)], (c) => integralOf(0, c[0], c1: 2)),
      ];
    }(),
    // Size table (v9): T4 b ≤ 4 · T6 b ≤ 8 · T8 b ≤ 12 (three questions at
    // T4–T5: skipped there).
    PatternFamily.threeXSquaredFromZero => () {
      final (low, high) = switch (t) {
        < 6 => (2, 4),
        < 8 => (5, 8),
        _ => (9, 12),
      };
      return [
        _f([Axis.range(low, high)], (c) => integralOf(0, c[0], c2: 3)),
      ];
    }(),
    // ∫₁₉²¹ 2x dx = 2 × 40: middles 10–50 at T5 growing to 10–90 by T7;
    // bounds around 100–300 from T8.
    PatternFamily.twoXDifferenceOfSquares => [
      _f([
        t < 8 ? _growing(1, 9, t - 5, 3) : Axis.range(10, 30),
        Axis.range(1, 9),
      ], (c) => integralOf(10 * c[0] - c[1], 10 * c[0] + c[1], c1: 2)),
    ],
    // Size table: T7 b ≤ 4 · T9 b ≤ 6 (three, then two questions: skipped).
    PatternFamily.fourXCubedFromZero => [
      _f([
        t < 9 ? Axis.range(2, 4) : Axis.range(5, 6),
      ], (c) => integralOf(0, c[0], c3: 4)),
    ],
  };
}

int _lengthOf(int n) => '$n'.length;

/// Powers of 2 per tier, as the size table's bands (each entry holds up to
/// the next): exponents above the band below, up to the band's limit.
(int, int) _powersOf2Band(int tier) => switch (tier) {
  1 || 2 => (5, 6),
  3 || 4 => (7, 8),
  5 || 6 => (9, 10),
  7 || 8 => (11, 16),
  _ => (17, 20),
};

/// Powers of 3, 4, 5 per tier and base: the size table's bands (T4, T6,
/// T8 — at T8 only 3 grows), exponents above the band below.
(int, int) _powersOf3To5Band(int tier, int base) {
  if (tier < 6) return base == 3 ? (3, 4) : (3, 3);
  if (base == 4) return (4, 5);
  if (base == 5) return (4, 4);
  return tier < 8 ? (5, 6) : (7, 8);
}
