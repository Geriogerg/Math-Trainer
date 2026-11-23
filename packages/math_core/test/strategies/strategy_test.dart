import 'package:math_core/models/exercise.dart';
import 'package:math_core/models/operation_type.dart';
import 'package:math_core/strategies/strategy.dart';
import 'package:test/test.dart';

ArithmeticExercise _op(int a, OperationType op, int b) =>
    ArithmeticExercise(operandA: a, operandB: b, operationType: op);

const _add = OperationType.addition;
const _sub = OperationType.subtraction;
const _mul = OperationType.multiplication;
const _div = OperationType.division;

/// Plan section 6.1: one test per strategy, on the table's own example,
/// then the cases each rule must leave alone. Runs on the VM and compiled
/// to JavaScript (`dart test -p node`), like every core test.
void main() {
  group('one test per strategy (the plan\'s examples)', () {
    test('compensation: 47 + 68 = 47 + 70 − 2', () {
      expect(
        bestStrategy(_op(47, _add, 68)),
        const CompensationMove(kept: 47, rounded: 70, adjustment: 2),
      );
    });

    test('subtract via a round number: 603 − 298 = 603 − 300 + 2', () {
      expect(
        bestStrategy(_op(603, _sub, 298)),
        const SubtractViaRoundMove(minuend: 603, rounded: 300, correction: 2),
      );
    });

    test('doubling and halving: 25 × 16 = 100 × 4', () {
      expect(
        bestStrategy(_op(25, _mul, 16)),
        const DoublingHalvingMove(round: 100, other: 4),
      );
    });

    test('split the factor: 7 × 46 = 280 + 42', () {
      final move = bestStrategy(_op(7, _mul, 46))! as SplitFactorMove;
      expect(move, const SplitFactorMove(digit: 7, tens: 40, units: 6));
      expect(move.digit * move.tens, 280);
      expect(move.digit * move.units, 42);
    });

    test('square near a base: 48² = 2500 − 200 + 4', () {
      final move =
          bestStrategy(const PowerExercise(base: 48, exponent: 2))!
              as SquareNearBaseMove;
      expect(move, const SquareNearBaseMove(base: 50, offset: -2));
      expect(move.base * move.base, 2500);
      expect(2 * move.base * move.offset, -200);
      expect(move.offset * move.offset, 4);
    });

    test('difference of squares: 47 × 53 = 50² − 3²', () {
      expect(
        bestStrategy(_op(47, _mul, 53)),
        const DifferenceOfSquaresMove(middle: 50, gap: 3),
      );
    });

    test('swap the percentage: 8% of 25 = 25% of 8', () {
      expect(
        bestStrategy(PercentageExercise(percent: 8, base: 25)),
        const SwapPercentageMove(percent: 25, base: 8),
      );
    });
  });

  group('each rule, its edges', () {
    test('compensation picks the operand closer to its ten', () {
      // 59 needs 1, 68 needs 2: round 59.
      expect(
        bestStrategy(_op(59, _add, 68)),
        const CompensationMove(kept: 68, rounded: 60, adjustment: 1),
      );
      // A single digit counts: 47 + 9 = 47 + 10 − 1.
      expect(
        bestStrategy(_op(47, _add, 9)),
        const CompensationMove(kept: 47, rounded: 10, adjustment: 1),
      );
      expect(bestStrategy(_op(42, _add, 35)), isNull);
    });

    test('a subtrahend just above a round number', () {
      expect(
        bestStrategy(_op(800, _sub, 302)),
        const SubtractViaRoundMove(minuend: 800, rounded: 300, correction: -2),
      );
      expect(
        bestStrategy(_op(81, _sub, 47)),
        const SubtractViaRoundMove(minuend: 81, rounded: 50, correction: 3),
      );
      // Already round, or nowhere near one.
      expect(bestStrategy(_op(603, _sub, 300)), isNull);
      expect(bestStrategy(_op(603, _sub, 250)), isNull);
      expect(bestStrategy(_op(60, _sub, 35)), isNull);
    });

    test('doubling and halving needs a factor that divides', () {
      expect(
        bestStrategy(_op(14, _mul, 5)),
        const DoublingHalvingMove(round: 10, other: 7),
      );
      expect(
        bestStrategy(_op(50, _mul, 18)),
        const DoublingHalvingMove(round: 100, other: 9),
      );
      // 25 × 18: 18 is not a multiple of 4 — no whole hundred.
      expect(bestStrategy(_op(25, _mul, 18)), isNull);
    });

    test('split the factor: one digit × two digits only', () {
      expect(bestStrategy(_op(7, _mul, 40)), isNull); // nothing to split
      expect(bestStrategy(_op(12, _mul, 34)), isNull); // two by two
      expect(
        bestStrategy(_op(83, _mul, 6)),
        const SplitFactorMove(digit: 6, tens: 80, units: 3),
      );
    });

    test('fewer steps win when two strategies fit', () {
      // 5 × 46: doubling and halving (10 × 23) beats splitting.
      expect(bestStrategy(_op(5, _mul, 46)), isA<DoublingHalvingMove>());
      // 48 × 52 around 50: the difference of squares.
      expect(bestStrategy(_op(48, _mul, 52)), isA<DifferenceOfSquaresMove>());
    });

    test('square near a base: around 50 and 100, not on them', () {
      expect(
        bestStrategy(const PowerExercise(base: 103, exponent: 2)),
        const SquareNearBaseMove(base: 100, offset: 3),
      );
      expect(bestStrategy(const PowerExercise(base: 50, exponent: 2)), isNull);
      expect(bestStrategy(const PowerExercise(base: 37, exponent: 2)), isNull);
      expect(bestStrategy(const PowerExercise(base: 49, exponent: 3)), isNull);
    });

    test('swap only towards a friendly percentage', () {
      expect(
        bestStrategy(PercentageExercise(percent: 25, base: 8)),
        isNull,
      ); // already friendly
      expect(
        bestStrategy(PercentageExercise(percent: 8, base: 30)),
        isNull,
      ); // 30% is not friendlier
    });

    test('no strategy for division and square roots', () {
      expect(bestStrategy(_op(84, _div, 7)), isNull);
      expect(bestStrategy(SquareRootExercise(radicand: 144)), isNull);
    });
  });

  // A move must never teach a wrong line: across every exercise in these
  // ranges, each move's own steps land on the exercise's answer.
  test('every move reaches the exercise\'s answer', () {
    var moves = 0;
    void check(Exercise exercise) {
      final move = bestStrategy(exercise);
      if (move == null) return;
      moves++;
      expect(move.result, exercise.correctAnswer, reason: '$exercise → $move');
    }

    for (var a = 0; a <= 300; a++) {
      for (var b = 0; b <= 300; b++) {
        check(_op(a, _add, b));
        if (a >= b) check(_op(a, _sub, b));
        if (a <= 120 && b <= 120) check(_op(a, _mul, b));
      }
    }
    for (var n = 1; n <= 130; n++) {
      check(PowerExercise(base: n, exponent: 2));
    }
    for (var p = 1; p <= 100; p++) {
      for (var n = 1; n <= 400; n++) {
        check(PercentageExercise(percent: p, base: n));
      }
    }
    expect(moves, greaterThan(10000));
  });
}
