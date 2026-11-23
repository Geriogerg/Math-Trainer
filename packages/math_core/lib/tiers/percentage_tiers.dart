import 'dart:math';

import '../models/exercise.dart';
import 'draw.dart';
import 'tier.dart';

/// A percentage of [tier] (`doc/levels.md`, section 5): the percentage
/// first, then a base among the multiples that make the answer whole (rule
/// 10) — never a base drawn and then checked.
PercentageExercise percentageAt(Tier tier, Random r) => switch (tier) {
  // 50 %, 10 % of tens up to 100.
  Tier.t0 => PercentageExercise(
    percent: drawOne(r, const [50, 10]),
    base: 10 * drawBetween(r, 1, 10),
  ),
  // 25 %, 20 % of round numbers up to 200.
  Tier.t1 => () {
    final percent = drawOne(r, const [25, 20]);
    return PercentageExercise(
      percent: percent,
      base: _wholeBase(r, percent, 10, 200, roundTo: 10),
    );
  }(),
  // 10 %, 20 %, 50 % of 2-digit and 3-digit numbers.
  Tier.t2 => _anyOf(r, const [10, 20, 50], 10, 999),
  // 5 %, 75 %.
  Tier.t3 => _anyOf(r, const [5, 75], 10, 400),
  // 1 %, 15 %, 30 %, 40 % of hundreds.
  Tier.t4 => PercentageExercise(
    percent: drawOne(r, const [1, 15, 30, 40]),
    base: 100 * drawBetween(r, 1, 9),
  ),
  // Any multiple of 5 %.
  Tier.t5 => _anyOf(r, [for (var p = 5; p <= 95; p += 5) p], 20, 400),
  // Any whole percentage of a round hundred.
  Tier.t6 => PercentageExercise(
    percent: drawBetween(r, 1, 99),
    base: 100 * drawBetween(r, 1, 9),
  ),
  // 12.5 %, 37.5 %, 62.5 %, 87.5 % (eighths) of multiples of 8.
  Tier.t7 => PercentageExercise(
    percent: drawOne(r, const [12, 37, 62, 87]),
    tenths: 5,
    base: 8 * drawBetween(r, 2, 25),
  ),
  // Above 100 %, of 2-digit numbers.
  Tier.t8 => _anyOf(r, const [110, 120, 125, 150, 175, 200], 10, 99),
  // Any whole percentage of a 3-digit base, whole result.
  Tier.t9 => _anyOf(r, [for (var p = 1; p <= 99; p++) p], 100, 999),
};

PercentageExercise _anyOf(Random r, List<int> percents, int min, int max) {
  final percent = drawOne(r, percents);
  return PercentageExercise(
    percent: percent,
    base: _wholeBase(r, percent, min, max),
  );
}

/// A base in [min, max] for which `percent × base / 100` is whole: a
/// multiple of `100 / gcd(percent, 100)` (and of [roundTo]).
int _wholeBase(Random r, int percent, int min, int max, {int roundTo = 1}) {
  final step = _lcm(100 ~/ _gcd(percent, 100), roundTo);
  return step * drawBetween(r, (min + step - 1) ~/ step, max ~/ step);
}

int _gcd(int a, int b) => b == 0 ? a : _gcd(b, a % b);

int _lcm(int a, int b) => a ~/ _gcd(a, b) * b;
