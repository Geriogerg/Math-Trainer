import 'dart:math';

import 'package:math_core/models/exercise.dart';
import 'package:math_core/models/operation_type.dart';
import 'package:math_core/tiers/long_arithmetic_tiers.dart';
import 'package:math_core/tiers/tier.dart';
import 'package:test/test.dart';

bool _in(int n, int min, int max) => n >= min && n <= max;
int _digits(int n) => '$n'.length;

/// Carries of a + b, column by column.
int _carries(int a, int b) {
  var carry = 0;
  var count = 0;
  while (a > 0 || b > 0) {
    final sum = a % 10 + b % 10 + carry;
    carry = sum >= 10 ? 1 : 0;
    count += carry;
    a ~/= 10;
    b ~/= 10;
  }
  return count;
}

/// Borrows of a − b (a ≥ b), column by column.
int _borrows(int a, int b) {
  var borrow = 0;
  var count = 0;
  while (a > 0 || b > 0) {
    final diff = a % 10 - b % 10 - borrow;
    borrow = diff < 0 ? 1 : 0;
    count += borrow;
    a ~/= 10;
    b ~/= 10;
  }
  return count;
}

typedef _Spec = bool Function(int a, int b);

/// `doc/levels.md` section 5, addition, T0…T9.
final List<_Spec> _addition = [
  (a, b) => _in(a, 1, 9) && _in(b, 1, 9) && a + b <= 10,
  (a, b) =>
      (_in(a, 1, 9) && _in(b, 1, 9) && a + b > 10) ||
      (_digits(a) == 2 && _digits(b) == 1),
  (a, b) => _digits(a) == 2 && _digits(b) == 2 && a % 10 + b % 10 >= 10,
  (a, b) => _digits(a) == 3 && (_digits(b) == 2 || _digits(b) == 3),
  (a, b) => _digits(a) == 4 && _digits(b) == 3,
  (a, b) => _digits(a) == 4 && _digits(b) == 4 && _carries(a, b) >= 2,
  (a, b) => _digits(a) == 5 && _digits(b) == 5,
  (a, b) => _digits(a) == 6 && _digits(b) == 6,
  (a, b) => _in(_digits(a), 7, 8) && _in(_digits(b), 7, 8),
  (a, b) => _digits(a) == 9 && _digits(b) == 9,
];

/// `doc/levels.md` section 5, subtraction, T0…T9; never negative.
final List<_Spec> _subtraction = [
  (a, b) => a <= 10 && b >= 1 && a - b >= 1,
  (a, b) =>
      (_in(a, 11, 19) && _in(b, 1, 9) && a % 10 < b) ||
      (_digits(a) == 2 && _digits(b) == 1 && a % 10 < b),
  (a, b) => _digits(a) == 2 && _digits(b) == 2 && a % 10 < b % 10,
  (a, b) =>
      _digits(a) == 3 &&
      (_digits(b) == 2 || _digits(b) == 3) &&
      a ~/ 10 % 10 == 0 &&
      a % 10 < b % 10,
  (a, b) => _digits(a) == 4 && _digits(b) == 3,
  (a, b) => _digits(a) == 4 && _digits(b) == 4 && _borrows(a, b) >= 2,
  (a, b) => _digits(a) == 5 && _digits(b) == 5,
  (a, b) => _digits(a) == 6 && _digits(b) == 6,
  (a, b) => _in(_digits(a), 7, 8) && _digits(b) == 7,
  (a, b) => _digits(a) == 9 && _digits(b) == 9,
];

const _additionExamples = [
  [(4, 5)],
  [(8, 7), (47, 8)],
  [(47, 38)],
  [(347, 258)],
  [(2468, 785)],
  [(4789, 3657)],
  [(47806, 38597)],
  [(482761, 359846)],
  [(4736285, 2948617)],
  [(538274916, 287649385)],
];

const _subtractionExamples = [
  [(9, 4)],
  [(15, 7), (43, 7)],
  [(72, 38)],
  [(403, 178)],
  [(3042, 687)],
  [(7003, 2468)],
  [(52004, 27368)],
  [(700251, 384769)],
  [(6030417, 2958639)],
  [(900040301, 457386529)],
];

void main() {
  for (final (op, specs, examples) in [
    (OperationType.addition, _addition, _additionExamples),
    (OperationType.subtraction, _subtraction, _subtractionExamples),
  ]) {
    group('rules v4 ${op.name}: the spec\'s section 5 table', () {
      for (final tier in Tier.values) {
        test('${tier.label}: its examples are its kind; 3,000 draws are '
            'too, never negative', () {
          final spec = specs[tier.index];
          for (final (a, b) in examples[tier.index]) {
            expect(spec(a, b), isTrue, reason: '$a, $b');
          }
          final random = Random(tier.index + 7);
          for (var i = 0; i < 3000; i++) {
            final ArithmeticExercise e = longArithmeticAt(op, tier, random);
            expect(e.operationType, op);
            expect(spec(e.operandA, e.operandB), isTrue, reason: '$e');
            expect(e.correctAnswer, greaterThan(0));
            expect(e.correctAnswer, lessThan(10000000000)); // 10 digits
          }
        });
      }
    });
  }

  test('only addition and subtraction have long tables (rule 13)', () {
    expect(
      () => longArithmeticAt(OperationType.division, Tier.t3, Random(1)),
      throwsArgumentError,
    );
  });
}
