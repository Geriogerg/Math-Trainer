import '../models/exercise.dart';
import '../models/operation_type.dart';
import '../patterns/pattern_family.dart';
import '../strategies/strategy.dart';
import 'method.dart';
import 'method_expr.dart';

// One library, four files (split at Phase 6b commit 3, review m12): the
// entry and its guards here; the building blocks, the families and the
// fallbacks in the parts below.
part 'method_blocks.dart';
part 'method_families.dart';
part 'method_fallbacks.dart';

/// The Method for [exercise] (`doc/levels.md` section 9): the pattern
/// [family]'s own strategy for a pattern question (its family recomputed by
/// replay, never guessed), else the detector's best strategy
/// ([bestStrategy]) **when it makes the question easier** ([offersMethod]),
/// else the operation's fallback — so every question has one. Integers
/// only; every line checked by `methodProblems` in tests.
Method methodFor(Exercise exercise, {PatternFamily? family}) {
  if (family != null) {
    final lines = _familyLines(family, exercise);
    if (lines != null) return Method(lines: lines, family: family);
  }
  final move = bestStrategy(exercise);
  if (move != null && offersMethod(move)) {
    return Method(lines: _strategyLines(move), strategy: move.strategy);
  }
  final (kind, lines) = _fallback(exercise);
  return Method(lines: lines, fallback: kind);
}

/// Whether the detector's [move] is a Method worth showing (`doc/levels.md`
/// v1.6 section 9, "A method must make the question easier"): rounding — to
/// add or to take away — only a number of at least two digits, within 3 of
/// a round number (one significant digit: 70, 200, 9 000), and never onto
/// the number it subtracts from (10 − 7 = 10 − 10 + 3 restates the
/// question, and 9 − 8 as 9 − 10 + 2 would pass below zero). The detector
/// itself is unchanged: weak spots key their skills on it.
bool offersMethod(StrategyMove move) => switch (move) {
  CompensationMove(:final rounded, :final adjustment) => _worthRounding(
    rounded - adjustment,
    rounded,
  ),
  SubtractViaRoundMove(:final minuend, :final rounded, :final correction) =>
    _worthRounding(rounded - correction, rounded) && rounded < minuend,
  DoublingHalvingMove() ||
  SplitFactorMove() ||
  SquareNearBaseMove() ||
  DifferenceOfSquaresMove() ||
  SwapPercentageMove() => true,
};

/// [n] (two digits or more) is 1 to 3 from [round], a one-significant-digit
/// number.
bool _worthRounding(int n, int round) =>
    n >= 10 && (round - n).abs() <= 3 && round != n && _oneSignificant(round);

/// 70, 200, 9 000: one digit, then zeros.
bool _oneSignificant(int n) {
  if (n < 1) return false;
  while (n % 10 == 0) {
    n ~/= 10;
  }
  return n < 10;
}
