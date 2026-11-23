import 'dart:math';

import '../models/exercise.dart';
import 'draw.dart';
import 'tier.dart';

/// An integral of [tier] (`doc/levels.md`, section 5). Each coefficient is
/// drawn as `(k + 1) × f` so the antiderivative has whole coefficients and
/// the answer is whole (rule 10); the integrand stays ≥ 0 on its interval
/// by construction — the one negative term of tier 9 is drawn no larger
/// than the leading term covers from the lower bound on (the invariant
/// `IntegralExercise` checks).
IntegralExercise integralAt(Tier tier, Random r) => switch (tier) {
  // A constant, from 0: ∫₀⁴ 3 dx.
  Tier.t0 => () {
    final c = drawBetween(r, 1, 9);
    return _integral(0, drawBetween(r, 1, 6), {0: c});
  }(),
  // 2x from 0: ∫₀³ 2x dx.
  Tier.t1 => _integral(0, drawBetween(r, 1, 9), {1: 2}),
  // 2x from a to b: ∫₂⁵ 2x dx.
  Tier.t2 => () {
    final a = drawBetween(r, 1, 6);
    return _integral(a, a + drawBetween(r, 1, 4), {1: 2});
  }(),
  // 2x + c from 0: ∫₀³ (2x + 4) dx.
  Tier.t3 => () {
    final c = drawBetween(r, 1, 9);
    return _integral(0, drawBetween(r, 1, 6), {1: 2, 0: c});
  }(),
  // 3x² from 0: ∫₀³ 3x² dx.
  Tier.t4 => _integral(0, drawBetween(r, 1, 5), {2: 3}),
  // 3x² from a to b: ∫₁³ 3x² dx.
  Tier.t5 => () {
    final a = drawBetween(r, 1, 4);
    return _integral(a, a + drawBetween(r, 1, 3), {2: 3});
  }(),
  // Degree 2 with a linear term: ∫₀² (3x² + 2x) dx.
  Tier.t6 => () {
    final c2 = 3 * drawBetween(r, 1, 2);
    final c1 = 2 * drawBetween(r, 1, 4);
    final a = drawBetween(r, 0, 2);
    return _integral(a, a + drawBetween(r, 1, 3), {2: c2, 1: c1});
  }(),
  // 4x³ from 0 or from 1: ∫₁² 4x³ dx.
  Tier.t7 => () {
    final a = drawBetween(r, 0, 1);
    return _integral(a, drawBetween(r, 2, 5), {3: 4});
  }(),
  // Degree 3 mixed: ∫₀² (4x³ + 6x) dx.
  Tier.t8 => () {
    final c3 = 4 * drawBetween(r, 1, 2);
    final c2 = 3 * drawBetween(r, 0, 2);
    final c1 = 2 * drawBetween(r, 1, 4);
    final c0 = drawBetween(r, 0, 3);
    final a = drawBetween(r, 0, 2);
    return _integral(a, a + drawBetween(r, 1, 2), {3: c3, 2: c2, 1: c1, 0: c0});
  }(),
  // Degree 3–4 with a second term, negative half the time, wider bounds:
  // ∫₁³ (5x⁴ − 3x²) dx.
  Tier.t9 => () {
    final degree = drawBetween(r, 3, 4);
    final leading = (degree + 1) * drawBetween(r, 1, 2);
    final j = drawBetween(r, 1, degree - 1);
    final negative = drawCoin(r);
    final int a, cj;
    if (negative) {
      a = drawBetween(r, 1, 3);
      // leading · a^(degree − j) covers |cj| on [a, ∞): at most that.
      final cover = leading * _power(a, degree - j) ~/ (j + 1);
      cj = -(j + 1) * drawBetween(r, 1, cover < 3 ? cover : 3);
    } else {
      a = drawBetween(r, 0, 3);
      cj = (j + 1) * drawBetween(r, 1, 3);
    }
    return _integral(a, a + drawBetween(r, 1, 3), {degree: leading, j: cj});
  }(),
};

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

int _power(int x, int n) {
  var result = 1;
  for (var i = 0; i < n; i++) {
    result *= x;
  }
  return result;
}
