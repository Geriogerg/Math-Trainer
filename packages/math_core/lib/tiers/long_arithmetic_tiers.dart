import 'dart:math';

import '../models/exercise.dart';
import '../models/operation_type.dart';
import 'draw.dart';
import 'tier.dart';

/// Addition and subtraction from rules v4 on: `doc/levels.md` section 5's
/// tables as written — up to 9 digits (T2 47 + 38 … T9 538 274 916 +
/// 287 649 385). Rules v2 and v3 keep `arithmeticAt`'s shorter tables (a
/// mismatch found at the Patterns and Method phase, `doc/decisions.md`):
/// their games must replay. Built from digits (rule 10): a carry or a
/// borrow is placed, never checked for.
ArithmeticExercise longArithmeticAt(
  OperationType operation,
  Tier tier,
  Random random,
) {
  final (a, b) = switch (operation) {
    OperationType.addition => _addition(tier, random),
    OperationType.subtraction => _subtraction(tier, random),
    OperationType.multiplication ||
    OperationType.division => throw ArgumentError.value(
      operation,
      'operation',
      'has no long table: only addition and subtraction.',
    ),
  };
  return ArithmeticExercise(operandA: a, operandB: b, operationType: operation);
}

typedef _Operands = (int, int);

int _number(List<int> digitsHighFirst) {
  var n = 0;
  for (final d in digitsHighFirst) {
    n = n * 10 + d;
  }
  return n;
}

/// A number of exactly [digits] digits.
int _digits(Random r, int digits) {
  var low = 1;
  for (var i = 1; i < digits; i++) {
    low *= 10;
  }
  return drawBetween(r, low, 10 * low - 1);
}

/// 7 or 8 digits, each half the time (T8: "7- and 8-digit numbers").
int _sevenOrEight(Random r) => drawCoin(r) ? 7 : 8;

_Operands _addition(Tier tier, Random r) => switch (tier) {
  // 1-digit + 1-digit, sum ≤ 10.
  Tier.t0 => () {
    final a = drawBetween(r, 1, 9);
    return (a, drawBetween(r, 1, 10 - a));
  }(),
  // 1-digit + 1-digit crossing 10; or 2-digit + 1-digit.
  Tier.t1 =>
    drawCoin(r)
        ? () {
            final a = drawBetween(r, 2, 9);
            return (a, drawBetween(r, 11 - a, 9));
          }()
        : (drawBetween(r, 10, 99), drawBetween(r, 1, 9)),
  // 2-digit + 2-digit, with a carry from the units.
  Tier.t2 => () {
    final ua = drawBetween(r, 1, 9);
    final ub = drawBetween(r, 10 - ua, 9);
    return (
      _number([drawBetween(r, 1, 9), ua]),
      _number([drawBetween(r, 1, 9), ub]),
    );
  }(),
  // 3-digit + 2-digit; or 3-digit + 3-digit.
  Tier.t3 => (_digits(r, 3), _digits(r, drawCoin(r) ? 2 : 3)),
  // 4-digit + 3-digit.
  Tier.t4 => (_digits(r, 4), _digits(r, 3)),
  // 4-digit + 4-digit, carries out of the units and the tens at least.
  Tier.t5 => () {
    final ua = drawBetween(r, 1, 9);
    final ub = drawBetween(r, 10 - ua, 9);
    final ta = drawBetween(r, 0, 9);
    final tb = drawBetween(r, 9 - ta, 9); // ta + tb + 1 ≥ 10
    return (
      _number([drawBetween(r, 1, 9), drawBetween(r, 0, 9), ta, ua]),
      _number([drawBetween(r, 1, 9), drawBetween(r, 0, 9), tb, ub]),
    );
  }(),
  Tier.t6 => (_digits(r, 5), _digits(r, 5)),
  Tier.t7 => (_digits(r, 6), _digits(r, 6)),
  Tier.t8 => (_digits(r, _sevenOrEight(r)), _digits(r, _sevenOrEight(r))),
  Tier.t9 => (_digits(r, 9), _digits(r, 9)),
};

/// Two numbers of [digitsA] ≥ [digitsB] digits, the first the larger: with
/// as many digits, the leading digits decide it (a's above b's).
_Operands _larger(Random r, int digitsA, int digitsB) {
  if (digitsA > digitsB) return (_digits(r, digitsA), _digits(r, digitsB));
  final leadA = drawBetween(r, 2, 9);
  final leadB = drawBetween(r, 1, leadA - 1);
  final restA = <int>[for (var i = 1; i < digitsA; i++) drawBetween(r, 0, 9)];
  final restB = <int>[for (var i = 1; i < digitsB; i++) drawBetween(r, 0, 9)];
  return (_number([leadA, ...restA]), _number([leadB, ...restB]));
}

_Operands _subtraction(Tier tier, Random r) => switch (tier) {
  // Within 10, never below 1.
  Tier.t0 => () {
    final a = drawBetween(r, 2, 10);
    return (a, drawBetween(r, 1, a - 1));
  }(),
  // Teens − 1-digit crossing 10; or 2-digit − 1-digit with a borrow.
  Tier.t1 =>
    drawCoin(r)
        ? () {
            final u = drawBetween(r, 1, 8);
            return (10 + u, drawBetween(r, u + 1, 9));
          }()
        : () {
            final u = drawBetween(r, 0, 8);
            return (
              _number([drawBetween(r, 2, 9), u]),
              drawBetween(r, u + 1, 9),
            );
          }(),
  // 2-digit − 2-digit with a borrow.
  Tier.t2 => () {
    final ua = drawBetween(r, 0, 8);
    final ub = drawBetween(r, ua + 1, 9);
    final ta = drawBetween(r, 2, 9);
    final tb = drawBetween(r, 1, ta - 1);
    return (_number([ta, ua]), _number([tb, ub]));
  }(),
  // 3-digit − 2- or 3-digit across a zero: the minuend's tens are 0 and
  // its units below the subtrahend's (403 − 178).
  Tier.t3 => () {
    final ua = drawBetween(r, 0, 8);
    final ub = drawBetween(r, ua + 1, 9);
    final tb = drawBetween(r, 0, 9);
    if (drawCoin(r)) {
      // 3-digit subtrahend, a smaller hundreds digit.
      final ha = drawBetween(r, 2, 9);
      return (
        _number([ha, 0, ua]),
        _number([drawBetween(r, 1, ha - 1), tb, ub]),
      );
    }
    // 2-digit subtrahend: tens from 1.
    return (
      _number([drawBetween(r, 1, 9), 0, ua]),
      _number([drawBetween(r, 1, 9), ub]),
    );
  }(),
  // 4-digit − 3-digit.
  Tier.t4 => _larger(r, 4, 3),
  // 4-digit − 4-digit, borrows from the units and the tens at least.
  Tier.t5 => () {
    final ua = drawBetween(r, 0, 8);
    final ub = drawBetween(r, ua + 1, 9);
    final ta = drawBetween(r, 0, 9);
    final tb = drawBetween(r, ta, 9); // ta − 1 < tb: a second borrow
    final tha = drawBetween(r, 2, 9);
    final thb = drawBetween(r, 1, tha - 1);
    return (
      _number([tha, drawBetween(r, 0, 9), ta, ua]),
      _number([thb, drawBetween(r, 0, 9), tb, ub]),
    );
  }(),
  Tier.t6 => _larger(r, 5, 5),
  Tier.t7 => _larger(r, 6, 6),
  // A 7- or 8-digit minuend, a 7-digit subtrahend.
  Tier.t8 => _larger(r, _sevenOrEight(r), 7),
  Tier.t9 => _larger(r, 9, 9),
};
