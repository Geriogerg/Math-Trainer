import 'package:math_core/difficulty/structural_features.dart';
import 'package:math_core/models/exercise.dart';
import 'package:math_core/models/operation_type.dart';
import 'package:test/test.dart';

ArithmeticExercise _op(int a, OperationType op, int b) =>
    ArithmeticExercise(operandA: a, operandB: b, operationType: op);

/// Plan section 6.1: "47 + 38 is harder than 45 + 32 because of the carry"
/// — the features that say so, on the VM and in JavaScript. The SQL twin
/// is checked against the same code in `structural_features_sql_parity_test`.
void main() {
  test('the plan\'s example: the carry is what differs', () {
    final hard = structuralFeatures(_op(47, OperationType.addition, 38));
    final easy = structuralFeatures(_op(45, OperationType.addition, 32));
    expect(hard.carries, 1);
    expect(easy.carries, 0);
    expect(hard.bigDigits, 2); // 7 and 8
    expect(easy.bigDigits, 0);
  });

  test('carries count every column, the last one included', () {
    expect(structuralFeatures(_op(999, OperationType.addition, 1)).carries, 3);
    expect(structuralFeatures(_op(65, OperationType.addition, 75)).carries, 2);
  });

  test('borrows go on through zeros', () {
    expect(
      structuralFeatures(_op(1000, OperationType.subtraction, 1)).borrows,
      3,
    );
    expect(
      structuralFeatures(_op(603, OperationType.subtraction, 298)).borrows,
      2,
    );
    expect(
      structuralFeatures(_op(87, OperationType.subtraction, 42)).borrows,
      0,
    );
  });

  test('carries only for additions, borrows only for subtractions', () {
    final product = structuralFeatures(
      _op(47, OperationType.multiplication, 38),
    );
    expect(product.carries, 0);
    expect(product.borrows, 0);
  });

  test('digits 6 to 9 across the operands shown, never the exponent', () {
    expect(
      structuralFeatures(const PowerExercise(base: 48, exponent: 2)).bigDigits,
      1,
    );
    expect(structuralFeatures(SquareRootExercise(radicand: 1369)).bigDigits, 2);
    expect(
      structuralFeatures(PercentageExercise(percent: 75, base: 80)).bigDigits,
      2,
    );
  });

  test('distance from a round number: the closest operand of 10 or more', () {
    StructuralFeatures of(int a, int b) =>
        structuralFeatures(_op(a, OperationType.subtraction, b));
    expect(of(603, 298).roundDistance, 2);
    expect(of(81, 47).roundDistance, 1);
    expect(of(65, 45).roundDistance, 5);
    expect(of(100, 7).roundDistance, 0);
    expect(of(9, 3).roundDistance, isNull);
  });

  test('carries and borrows agree with a plain column-sum count', () {
    // An independent count: a column carries when the units of the
    // partial sums overflow — compare over every pair below 1,000.
    int reference(int a, int b) {
      var count = 0;
      var unit = 1;
      while (unit <= a + b) {
        final low = a % (unit * 10) + b % (unit * 10);
        if (low >= unit * 10) count++;
        unit *= 10;
      }
      return count;
    }

    for (var a = 0; a < 1000; a += 7) {
      for (var b = 0; b < 1000; b += 3) {
        expect(
          structuralFeatures(_op(a, OperationType.addition, b)).carries,
          reference(a, b),
          reason: '$a + $b',
        );
        if (a >= b) {
          // a − b borrows exactly where (a − b) + b carries.
          expect(
            structuralFeatures(_op(a, OperationType.subtraction, b)).borrows,
            reference(a - b, b),
            reason: '$a − $b',
          );
        }
      }
    }
  });
}
