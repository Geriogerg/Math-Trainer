import 'dart:math';

import 'package:math_core/difficulty/integral_difficulty.dart';
import 'package:math_core/generation/composite_exercise_generator.dart';
import 'package:math_core/generation/integral_generator.dart';
import 'package:math_core/leveling/level.dart';
import 'package:math_core/models/exercise.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/persistence/exercise_codec.dart';
import 'package:math_core/placement/placement.dart';
import 'package:math_core/placement/placement_exercise_source.dart';
import 'package:test/test.dart';

/// p(x) at [x], for the area checks below.
int _p(IntegralExercise e, int x) {
  var sum = 0;
  var power = 1;
  for (final c in e.coefficients) {
    sum += c * power;
    power *= x;
  }
  return sum;
}

void main() {
  group('IntegralExercise', () {
    test('the plan\'s examples', () {
      expect(
        IntegralExercise(
          lower: 0,
          upper: 3,
          c0: 0,
          c1: 2,
          c2: 0,
          c3: 0,
        ).correctAnswer,
        9,
      );
      expect(
        IntegralExercise(
          lower: 1,
          upper: 2,
          c0: 0,
          c1: 0,
          c2: 3,
          c3: 0,
        ).correctAnswer,
        7,
      );
    });

    test('every term: ∫₁³ (2 + 4x + 3x² + 8x³) dx = 4 + 16 + 26 + 160', () {
      expect(
        IntegralExercise(
          lower: 1,
          upper: 3,
          c0: 2,
          c1: 4,
          c2: 3,
          c3: 8,
        ).correctAnswer,
        206,
      );
    });

    test('invalid questions throw (rule 13)', () {
      IntegralExercise make({
        int lower = 0,
        int upper = 2,
        int c0 = 0,
        int c1 = 2,
        int c2 = 0,
        int c3 = 0,
      }) => IntegralExercise(
        lower: lower,
        upper: upper,
        c0: c0,
        c1: c1,
        c2: c2,
        c3: c3,
      );
      expect(() => make(lower: -1), throwsArgumentError);
      expect(() => make(lower: 2, upper: 2), throwsArgumentError);
      expect(() => make(c1: 3), throwsArgumentError); // not a multiple of 2
      expect(() => make(c2: 4), throwsArgumentError); // not a multiple of 3
      expect(() => make(c0: -1), throwsArgumentError);
      expect(() => make(c1: 0), throwsArgumentError); // all zero
    });

    test('stored with every coefficient', () {
      final described = describeExerciseForStorage(
        IntegralExercise(lower: 0, upper: 3, c0: 0, c1: 2, c2: 0, c3: 0),
      );
      expect(described.exerciseType, 'integral');
      expect(described.operationType, 'integral');
      expect(described.operands, {
        'lower': 0,
        'upper': 3,
        'c0': 0,
        'c1': 2,
        'c2': 0,
        'c3': 0,
      });
    });
  });

  group('IntegralExerciseGenerator', () {
    test('level 1: ∫₀ᵇ 2x dx, b ≤ 3', () {
      final generator = IntegralExerciseGenerator(
        bounds: integralDifficulty.boundsFor(1),
      );
      final random = Random(1);
      for (var i = 0; i < 200; i++) {
        final e = generator.next(random);
        expect(e.coefficients, [0, 2, 0, 0]);
        expect(e.lower, 0);
        expect(e.upper, inInclusiveRange(1, 3));
      }
    });

    test('thousands of draws over every level: valid areas, whole answers', () {
      final random = Random(2026);
      for (var level = 1; level <= 100; level++) {
        final generator = IntegralExerciseGenerator(
          bounds: integralDifficulty.boundsFor(level),
        );
        for (var i = 0; i < 50; i++) {
          final e = generator.next(random); // the constructor checks it
          for (var x = e.lower; x <= e.upper; x++) {
            expect(_p(e, x), greaterThanOrEqualTo(0));
          }
          expect(e.correctAnswer, greaterThan(0));
          expect(e.correctAnswer, lessThan(10000000)); // 7 typed digits
        }
      }
    });

    test('difficulty grows: level 100 reaches degree 4 and wider bounds', () {
      final low = integralDifficulty.boundsFor(1);
      final high = integralDifficulty.boundsFor(100);
      expect(high.maxDegree, greaterThan(low.maxDegree));
      expect(high.maxLeading, greaterThan(low.maxLeading));
      expect(high.maxOther, greaterThan(low.maxOther));
      expect(high.maxLower, greaterThan(low.maxLower));
      expect(high.maxWidth, greaterThanOrEqualTo(low.maxWidth));
    });

    test('pinned on VM and JavaScript', () {
      final generator = exerciseGeneratorFor(ExerciseType.integral, 60);
      final random = Random(42);
      expect([for (var i = 0; i < 3; i++) generator.next(random)], _pinned);
    });
  });

  test('a never-played integral gets its type placement', () {
    final sequence = typePlacementSequence({
      ExerciseType.integral,
    }, rules: typePlacementRules);
    expect(sequence, everyElement(ExerciseType.integral));
    final source = PlacementExerciseSource(
      seed: 5,
      rules: typePlacementRules,
      sequence: sequence,
    );
    expect(source.next(), isA<IntegralExercise>());
    expect(Level.whole(typePlacementRules.startLevel).whole, greaterThan(0));
  });
}

// ∫₀¹ (2x + 3x²) dx = 2; ∫₀¹ (1 + 2x + 6x²) dx = 4; ∫₀² (2 + 4x + 9x²) dx = 36.
final _pinned = [
  IntegralExercise(lower: 0, upper: 1, c0: 0, c1: 2, c2: 3, c3: 0),
  IntegralExercise(lower: 0, upper: 1, c0: 1, c1: 2, c2: 6, c3: 0),
  IntegralExercise(lower: 0, upper: 2, c0: 2, c1: 4, c2: 9, c3: 0),
];
