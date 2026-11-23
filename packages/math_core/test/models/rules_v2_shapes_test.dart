import 'package:math_core/models/exercise.dart';
import 'package:math_core/persistence/exercise_codec.dart';
import 'package:test/test.dart';

/// The model extensions `doc/levels.md` needs (Levels phase commit 2):
/// cube roots, an eighth's tenths, x⁴ and one covered negative term — each
/// invariant with its invalid case (rule 13), and the stored shape of the
/// questions from before unchanged.
void main() {
  group('cube roots', () {
    test('∛64 = 4; ∛2197 = 13', () {
      expect(SquareRootExercise(radicand: 64, index: 3).correctAnswer, 4);
      expect(SquareRootExercise(radicand: 2197, index: 3).correctAnswer, 13);
    });

    test('only square and cube roots', () {
      expect(
        () => SquareRootExercise(radicand: 16, index: 4),
        throwsArgumentError,
      );
      expect(
        () => SquareRootExercise(radicand: 16, index: 1),
        throwsArgumentError,
      );
    });

    test('equality includes the index', () {
      expect(
        SquareRootExercise(radicand: 64, index: 3),
        isNot(SquareRootExercise(radicand: 64)),
      );
    });

    test('stored with its index; a square root keeps its old shape', () {
      expect(
        describeExerciseForStorage(
          SquareRootExercise(radicand: 64, index: 3),
        ).operands,
        {'radicand': 64, 'index': 3},
      );
      expect(
        describeExerciseForStorage(SquareRootExercise(radicand: 64)).operands,
        {'radicand': 64},
      );
    });
  });

  group('eighths', () {
    test('37.5 % of 64 = 24; 12.5 % of 16 = 2', () {
      expect(
        PercentageExercise(percent: 37, tenths: 5, base: 64).correctAnswer,
        24,
      );
      expect(
        PercentageExercise(percent: 12, tenths: 5, base: 16).correctAnswer,
        2,
      );
    });

    test('tenths are one digit', () {
      expect(
        () => PercentageExercise(percent: 37, tenths: 10, base: 64),
        throwsArgumentError,
      );
      expect(
        () => PercentageExercise(percent: 37, tenths: -1, base: 64),
        throwsArgumentError,
      );
    });

    test('stored with its tenths; a whole percentage keeps its old shape', () {
      expect(
        describeExerciseForStorage(
          PercentageExercise(percent: 37, tenths: 5, base: 64),
        ).operands,
        {'percent': 37, 'base': 64, 'tenths': 5},
      );
      expect(
        describeExerciseForStorage(
          PercentageExercise(percent: 25, base: 80),
        ).operands,
        {'percent': 25, 'base': 80},
      );
    });
  });

  group('integrals with x⁴ and a negative term', () {
    IntegralExercise integral({
      int lower = 1,
      int c0 = 0,
      int c1 = 0,
      int c2 = 0,
      int c3 = 0,
      int c4 = 0,
    }) => IntegralExercise(
      lower: lower,
      upper: lower + 2,
      c0: c0,
      c1: c1,
      c2: c2,
      c3: c3,
      c4: c4,
    );

    test('∫₁³ (5x⁴ − 3x²) dx = 216', () {
      expect(integral(c4: 5, c2: -3).correctAnswer, 216);
    });

    test('c4 must be a multiple of 5', () {
      expect(() => integral(c4: 4), throwsArgumentError);
    });

    test('two negative terms are refused', () {
      expect(() => integral(c4: 10, c2: -3, c1: -2), throwsArgumentError);
    });

    test('a negative term the higher term does not cover from the lower '
        'bound on is refused', () {
      // From 0: 5x⁴ − 3x² < 0 near 0.
      expect(() => integral(lower: 0, c4: 5, c2: -3), throwsArgumentError);
      // From 1: 5 · 1 < 6.
      expect(() => integral(c4: 5, c2: -6), throwsArgumentError);
      // A negative leading term: nothing above covers it.
      expect(() => integral(c4: -5, c2: 3), throwsArgumentError);
    });

    test('stored with c4 only when present', () {
      expect(
        describeExerciseForStorage(integral(c4: 5, c2: -3)).operands['c4'],
        5,
      );
      expect(
        describeExerciseForStorage(integral(c3: 4)).operands.containsKey('c4'),
        isFalse,
      );
    });
  });
}
