import 'dart:math';

import '../models/exercise.dart';
import '../models/operation_type.dart';
import 'draw.dart';
import 'tier.dart';

/// The four basic operations, tier by tier, as built at the Levels phase
/// (rules v2 and v3). Multiplication and division are `doc/levels.md`
/// section 5's, under every rules version; addition and subtraction are an
/// earlier draft's (4 digits at most), frozen for v2 and v3 games — from
/// rules v4 on, the spec's own tables are `longArithmeticAt`'s.
/// Every question is built from its parts (rule 10): digits drawn so that a
/// carry or a borrow happens exactly where the tier wants it, a quotient
/// drawn before its dividend. Never a draw followed by a check.
ArithmeticExercise arithmeticAt(
  OperationType operation,
  Tier tier,
  Random random,
) {
  final (a, b) = switch (operation) {
    OperationType.addition => _addition(tier, random),
    OperationType.subtraction => _subtraction(tier, random),
    OperationType.multiplication => _multiplication(tier, random),
    OperationType.division => _division(tier, random),
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

int _ceilDiv(int a, int b) => (a + b - 1) ~/ b;

_Operands _addition(Tier tier, Random r) => switch (tier) {
  // 1-digit + 1-digit, sum ≤ 10.
  Tier.t0 => () {
    final a = drawBetween(r, 1, 9);
    return (a, drawBetween(r, 1, 10 - a));
  }(),
  // 1-digit + 1-digit crossing 10.
  Tier.t1 => () {
    final a = drawBetween(r, 2, 9);
    return (a, drawBetween(r, 11 - a, 9));
  }(),
  // 2-digit + 1-digit.
  Tier.t2 => (drawBetween(r, 10, 99), drawBetween(r, 1, 9)),
  // 2-digit + 2-digit without a carry; or tens + tens.
  Tier.t3 =>
    drawCoin(r)
        ? () {
            final ua = drawBetween(r, 0, 9);
            final ub = drawBetween(r, 0, 9 - ua);
            final ta = drawBetween(r, 1, 8);
            final tb = drawBetween(r, 1, 9 - ta);
            return (_number([ta, ua]), _number([tb, ub]));
          }()
        : (10 * drawBetween(r, 1, 9), 10 * drawBetween(r, 1, 9)),
  // 2-digit + 2-digit with a carry from the units.
  Tier.t4 => () {
    final ua = drawBetween(r, 1, 9);
    final ub = drawBetween(r, 10 - ua, 9);
    final ta = drawBetween(r, 1, 9);
    final tb = drawBetween(r, 1, 9);
    return (_number([ta, ua]), _number([tb, ub]));
  }(),
  // 3-digit + 2-digit.
  Tier.t5 => (drawBetween(r, 100, 999), drawBetween(r, 10, 99)),
  // 3-digit + 3-digit, at most one carry (none, units or tens), never one
  // out of the hundreds.
  Tier.t6 => () {
    final carryAt = drawBetween(r, 0, 2);
    final int ua, ub;
    if (carryAt == 1) {
      ua = drawBetween(r, 1, 9);
      ub = drawBetween(r, 10 - ua, 9);
    } else {
      ua = drawBetween(r, 0, 9);
      ub = drawBetween(r, 0, 9 - ua);
    }
    final c1 = carryAt == 1 ? 1 : 0;
    final int ta, tb;
    if (carryAt == 2) {
      ta = drawBetween(r, 1, 9);
      tb = drawBetween(r, 10 - ta, 9);
    } else {
      ta = drawBetween(r, 0, 9 - c1);
      tb = drawBetween(r, 0, 9 - c1 - ta);
    }
    final c2 = carryAt == 2 ? 1 : 0;
    final ha = drawBetween(r, 1, 8 - c2);
    final hb = drawBetween(r, 1, 9 - c2 - ha);
    return (_number([ha, ta, ua]), _number([hb, tb, ub]));
  }(),
  // 3-digit + 3-digit, carries out of the units and the tens.
  Tier.t7 => () {
    final (ua, ub, ta, tb) = _twoCarries(r);
    return (
      _number([drawBetween(r, 1, 9), ta, ua]),
      _number([drawBetween(r, 1, 9), tb, ub]),
    );
  }(),
  // 4-digit + 3-digit.
  Tier.t8 => (drawBetween(r, 1000, 9999), drawBetween(r, 100, 999)),
  // 4-digit + 4-digit, carries out of the units and the tens at least.
  Tier.t9 => () {
    final (ua, ub, ta, tb) = _twoCarries(r);
    final ha = drawBetween(r, 0, 9);
    final hb = drawBetween(r, 0, 9);
    return (
      _number([drawBetween(r, 1, 9), ha, ta, ua]),
      _number([drawBetween(r, 1, 9), hb, tb, ub]),
    );
  }(),
};

/// Units and tens digits of two addends with a carry out of both.
(int, int, int, int) _twoCarries(Random r) {
  final ua = drawBetween(r, 1, 9);
  final ub = drawBetween(r, 10 - ua, 9);
  final ta = drawBetween(r, 0, 9);
  final tb = drawBetween(r, 9 - ta, 9); // ta + tb + 1 ≥ 10
  return (ua, ub, ta, tb);
}

_Operands _subtraction(Tier tier, Random r) => switch (tier) {
  // Within 10, never below 1.
  Tier.t0 => () {
    final a = drawBetween(r, 2, 10);
    return (a, drawBetween(r, 1, a - 1));
  }(),
  // Teens − 1-digit, crossing 10.
  Tier.t1 => () {
    final u = drawBetween(r, 1, 8);
    return (10 + u, drawBetween(r, u + 1, 9));
  }(),
  // 2-digit − 1-digit with a borrow.
  Tier.t2 => () {
    final tens = drawBetween(r, 2, 9);
    final u = drawBetween(r, 0, 8);
    return (_number([tens, u]), drawBetween(r, u + 1, 9));
  }(),
  // 2-digit − 2-digit without a borrow; or tens − tens.
  Tier.t3 =>
    drawCoin(r)
        ? () {
            final ua = drawBetween(r, 0, 9);
            final ub = drawBetween(r, 0, ua);
            final ta = drawBetween(r, 1, 9);
            final tb = drawBetween(r, 1, ta);
            return (_number([ta, ua]), _number([tb, ub]));
          }()
        : () {
            final ta = drawBetween(r, 2, 9);
            return (10 * ta, 10 * drawBetween(r, 1, ta - 1));
          }(),
  // 2-digit − 2-digit with a borrow.
  Tier.t4 => () {
    final ua = drawBetween(r, 0, 8);
    final ub = drawBetween(r, ua + 1, 9);
    final ta = drawBetween(r, 2, 9);
    final tb = drawBetween(r, 1, ta - 1);
    return (_number([ta, ua]), _number([tb, ub]));
  }(),
  // 3-digit − 2-digit.
  Tier.t5 => (drawBetween(r, 100, 999), drawBetween(r, 10, 99)),
  // 3-digit − 3-digit, at most one borrow (none, units or tens).
  Tier.t6 => () {
    final borrowAt = drawBetween(r, 0, 2);
    final int ua, ub;
    if (borrowAt == 1) {
      ua = drawBetween(r, 0, 8);
      ub = drawBetween(r, ua + 1, 9);
    } else {
      ua = drawBetween(r, 0, 9);
      ub = drawBetween(r, 0, ua);
    }
    final c1 = borrowAt == 1 ? 1 : 0;
    final int ta, tb;
    if (borrowAt == 2) {
      ta = drawBetween(r, 0, 8);
      tb = drawBetween(r, ta + 1, 9);
    } else {
      ta = drawBetween(r, c1, 9);
      tb = drawBetween(r, 0, ta - c1);
    }
    final c2 = borrowAt == 2 ? 1 : 0;
    final ha = drawBetween(r, 1 + c2, 9);
    final hb = drawBetween(r, 1, ha - c2);
    return (_number([ha, ta, ua]), _number([hb, tb, ub]));
  }(),
  // 3-digit − 3-digit, borrows from the units and the tens; half of them
  // across a zero (403 − 178).
  Tier.t7 => () {
    final acrossZero = drawCoin(r);
    final ua = drawBetween(r, 0, 8);
    final ub = drawBetween(r, ua + 1, 9);
    final int ta, tb;
    if (acrossZero) {
      ta = 0;
      tb = drawBetween(r, 0, 9);
    } else {
      ta = drawBetween(r, 1, 9);
      tb = drawBetween(r, ta, 9); // ta − 1 < tb: a second borrow
    }
    final ha = drawBetween(r, 2, 9);
    final hb = drawBetween(r, 1, ha - 1);
    return (_number([ha, ta, ua]), _number([hb, tb, ub]));
  }(),
  // 4-digit − 3-digit.
  Tier.t8 => (drawBetween(r, 1000, 9999), drawBetween(r, 100, 999)),
  // 4-digit − 4-digit, borrows from the units and the tens at least; the
  // thousands keep the result positive.
  Tier.t9 => () {
    final ua = drawBetween(r, 0, 8);
    final ub = drawBetween(r, ua + 1, 9);
    final ta = drawBetween(r, 0, 9);
    final tb = drawBetween(r, ta, 9);
    final ha = drawBetween(r, 0, 9);
    final hb = drawBetween(r, 0, 9);
    final tha = drawBetween(r, 2, 9);
    final thb = drawBetween(r, 1, tha - 1);
    return (_number([tha, ha, ta, ua]), _number([thb, hb, tb, ub]));
  }(),
};

_Operands _multiplication(Tier tier, Random r) => switch (tier) {
  // Tables 1–5, × 1–10, either order.
  Tier.t0 => _eitherOrder(r, drawBetween(r, 1, 5), drawBetween(r, 1, 10)),
  // Tables 6–10, × 1–10, either order.
  Tier.t1 => _eitherOrder(r, drawBetween(r, 6, 10), drawBetween(r, 1, 10)),
  // 10–15 × 1–9; or a multiple of 10 × 1–9.
  Tier.t2 =>
    drawCoin(r)
        ? (drawBetween(r, 10, 15), drawBetween(r, 1, 9))
        : (10 * drawBetween(r, 1, 9), drawBetween(r, 1, 9)),
  // 16–25 × 2–9; or a 2-digit number × 11.
  Tier.t3 =>
    drawCoin(r)
        ? (drawBetween(r, 16, 25), drawBetween(r, 2, 9))
        : (drawBetween(r, 10, 99), 11),
  // Any 2-digit × 1-digit.
  Tier.t4 => (drawBetween(r, 10, 99), drawBetween(r, 2, 9)),
  // 11–19 × 11–19; or a 2-digit number × 5, 25 or 50.
  Tier.t5 =>
    drawCoin(r)
        ? (drawBetween(r, 11, 19), drawBetween(r, 11, 19))
        : (drawBetween(r, 10, 99), drawOne(r, const [5, 25, 50])),
  // 2-digit × 2-digit up to 40 × 40; or a multiple of 10 × 2-digit.
  Tier.t6 =>
    drawCoin(r)
        ? (drawBetween(r, 11, 40), drawBetween(r, 11, 40))
        : (10 * drawBetween(r, 2, 9), drawBetween(r, 11, 99)),
  // 3-digit × 1-digit.
  Tier.t7 => (drawBetween(r, 100, 999), drawBetween(r, 2, 9)),
  // Any 2-digit × 2-digit.
  Tier.t8 => (drawBetween(r, 10, 99), drawBetween(r, 10, 99)),
  // 3-digit × 2-digit up to 250 × 50.
  Tier.t9 => (drawBetween(r, 100, 250), drawBetween(r, 10, 50)),
};

_Operands _eitherOrder(Random r, int a, int b) => drawCoin(r) ? (a, b) : (b, a);

/// The divisor and the quotient first, the dividend their product: every
/// division is exact (rule 10). Mirrors the multiplication of each tier.
_Operands _division(Tier tier, Random r) {
  final (divisor, quotient) = switch (tier) {
    // Facts of tables 1–5.
    Tier.t0 => (drawBetween(r, 1, 5), drawBetween(r, 1, 10)),
    // Facts of tables 6–10.
    Tier.t1 => (drawBetween(r, 6, 10), drawBetween(r, 1, 10)),
    // Dividends from 10–15 × 2–9; or tens (560 ÷ 8 = 70).
    Tier.t2 =>
      drawCoin(r)
          ? (drawBetween(r, 2, 9), drawBetween(r, 10, 15))
          : (drawBetween(r, 2, 9), 10 * drawBetween(r, 1, 9)),
    // Dividends from 16–25 × 2–9.
    Tier.t3 => (drawBetween(r, 2, 9), drawBetween(r, 16, 25)),
    // 3-digit ÷ 1-digit.
    Tier.t4 => _quotientFor(r, drawBetween(r, 2, 9), 100, 999),
    // ÷ 11–19 (from 11–19 × 11–19); or ÷ 5, 25, 50.
    Tier.t5 =>
      drawCoin(r)
          ? (drawBetween(r, 11, 19), drawBetween(r, 11, 19))
          : (drawOne(r, const [5, 25, 50]), drawBetween(r, 10, 99)),
    // 3-digit ÷ 2-digit up to 40.
    Tier.t6 => _quotientFor(r, drawBetween(r, 11, 40), 100, 999),
    // 4-digit ÷ 1-digit.
    Tier.t7 => _quotientFor(r, drawBetween(r, 2, 9), 1000, 9999),
    // 4-digit ÷ 2-digit.
    Tier.t8 => _quotientFor(r, drawBetween(r, 11, 99), 1000, 9999),
    // 4-digit ÷ 2-digit with a 3-digit quotient.
    Tier.t9 => _quotientFor(r, drawBetween(r, 11, 99), 1000, 9999, minQ: 100),
  };
  return (divisor * quotient, divisor);
}

/// [divisor] and a quotient whose product lies in [min, max].
(int, int) _quotientFor(
  Random r,
  int divisor,
  int min,
  int max, {
  int minQ = 1,
}) {
  final low = _ceilDiv(min, divisor);
  return (divisor, drawBetween(r, low > minQ ? low : minQ, max ~/ divisor));
}
