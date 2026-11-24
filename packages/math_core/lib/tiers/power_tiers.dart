import 'dart:math';

import '../models/exercise.dart';
import 'draw.dart';
import 'tier.dart';

/// A tier's powers: (base range or list, exponent). Roots mirror them
/// (`doc/levels.md`, section 5), so both read this one table.
typedef _Family = ({List<int> bases, int exponent});

List<int> _range(int min, int max) => [for (var b = min; b <= max; b++) b];

/// 25, 35 … 95 and the tens 10 … 90 (tier 3).
final _fivesAndTens = [
  for (var b = 25; b <= 95; b += 10) b,
  for (var b = 10; b <= 90; b += 10) b,
];

List<_Family> _powerFamilies(Tier tier) => switch (tier) {
  Tier.t0 => [(bases: _range(1, 10), exponent: 2)],
  // And 2¹–2⁶ ([_otherPowers]).
  Tier.t1 => [(bases: _range(11, 15), exponent: 2)],
  Tier.t2 => [
    (bases: _range(16, 20), exponent: 2),
    (bases: _range(1, 5), exponent: 3),
  ],
  Tier.t3 => [(bases: _fivesAndTens, exponent: 2)],
  Tier.t4 => [(bases: _range(21, 30), exponent: 2)],
  Tier.t5 => [
    (bases: _range(31, 50), exponent: 2),
    (bases: _range(6, 10), exponent: 3),
  ],
  Tier.t6 => [(bases: _range(51, 70), exponent: 2)],
  Tier.t7 => [(bases: _range(71, 100), exponent: 2)],
  Tier.t8 => [
    (bases: _range(101, 125), exponent: 2),
    (bases: _range(11, 15), exponent: 3),
  ],
  Tier.t9 => [(bases: _range(126, 200), exponent: 2)],
};

/// Powers with a fixed base and a range of exponents: 2¹–2⁶ (T1), 2⁷–2¹⁰
/// (T4), 3¹–3⁶ (T6), and 5⁴, 6⁴, 7⁴ (T9, a range of bases at exponent 4).
PowerExercise Function(Random)? _otherPowers(Tier tier) => switch (tier) {
  Tier.t1 => (r) => PowerExercise(base: 2, exponent: drawBetween(r, 1, 6)),
  Tier.t4 => (r) => PowerExercise(base: 2, exponent: drawBetween(r, 7, 10)),
  Tier.t6 => (r) => PowerExercise(base: 3, exponent: drawBetween(r, 1, 6)),
  Tier.t9 => (r) => PowerExercise(base: drawBetween(r, 5, 7), exponent: 4),
  Tier.t0 || Tier.t2 || Tier.t3 || Tier.t5 || Tier.t7 || Tier.t8 => null,
};

/// A power of [tier]: one of its forms, uniformly (`doc/levels.md`,
/// section 5), then its base and exponent.
PowerExercise powerAt(Tier tier, Random random) {
  final families = _powerFamilies(tier);
  final other = _otherPowers(tier);
  final forms = families.length + (other == null ? 0 : 1);
  final form = random.nextInt(forms);
  if (form < families.length) {
    final family = families[form];
    return PowerExercise(
      base: drawOne(random, family.bases),
      exponent: family.exponent,
    );
  }
  return other!(random);
}

/// A root of [tier], the mirror of its powers (`doc/levels.md`, section 5):
/// the root drawn first, the radicand its square or cube (rule 10). Only
/// the square and cube families mirror: the powers of 2, 3 and the fourth
/// powers have no root in the spec.
SquareRootExercise rootAt(Tier tier, Random random) {
  final family = drawOne(random, _powerFamilies(tier));
  final root = drawOne(random, family.bases);
  final radicand = family.exponent == 2 ? root * root : root * root * root;
  return SquareRootExercise(radicand: radicand, index: family.exponent);
}

/// Every power [powerAt] can draw at [tier], in a fixed order: each
/// family's bases, then the fixed-base form. Read from the same tables, so
/// it cannot drift from the generator (Phase 4: `factsAt`).
List<PowerExercise> powerSupport(Tier tier) => [
  for (final family in _powerFamilies(tier))
    for (final base in family.bases)
      PowerExercise(base: base, exponent: family.exponent),
  ...switch (tier) {
    Tier.t1 => [
      for (var e = 1; e <= 6; e++) PowerExercise(base: 2, exponent: e),
    ],
    Tier.t4 => [
      for (var e = 7; e <= 10; e++) PowerExercise(base: 2, exponent: e),
    ],
    Tier.t6 => [
      for (var e = 1; e <= 6; e++) PowerExercise(base: 3, exponent: e),
    ],
    Tier.t9 => [
      for (var b = 5; b <= 7; b++) PowerExercise(base: b, exponent: 4),
    ],
    Tier.t0 ||
    Tier.t2 ||
    Tier.t3 ||
    Tier.t5 ||
    Tier.t7 ||
    Tier.t8 => const <PowerExercise>[],
  },
];

/// Every root [rootAt] can draw at [tier], in a fixed order.
List<SquareRootExercise> rootSupport(Tier tier) => [
  for (final family in _powerFamilies(tier))
    for (final root in family.bases)
      SquareRootExercise(
        radicand: family.exponent == 2 ? root * root : root * root * root,
        index: family.exponent,
      ),
];
