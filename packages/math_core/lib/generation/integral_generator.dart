import 'dart:math';

import '../difficulty/integral_difficulty.dart';
import '../models/exercise.dart';
import 'exercise_generator.dart';

/// Builds the answer's antiderivative first (rule 10): F(x) = Σ fk·x^k,
/// k = 1 … d, whole coefficients, no constant; shows p = F′ (ck = (k+1)·f(k+1))
/// and whole bounds 0 ≤ a < b. Never a draw followed by a check: every
/// draw lands on a valid question. Draw order: degree, leading coefficient,
/// the lower coefficients from x¹ up, the lower bound, the width.
class IntegralExerciseGenerator implements ExerciseGenerator {
  IntegralExerciseGenerator({IntegralBounds? bounds})
    : bounds = bounds ?? integralDifficulty.boundsFor(1);

  final IntegralBounds bounds;

  @override
  IntegralExercise next(Random random) {
    int draw(int min, int max) => min + random.nextInt(max - min + 1);
    final degree = draw(2, bounds.maxDegree);
    final f = List<int>.filled(5, 0); // F's coefficients, x⁰ … x⁴
    f[degree] = draw(1, bounds.maxLeading);
    for (var k = 1; k < degree; k++) {
      f[k] = draw(0, bounds.maxOther);
    }
    final lower = draw(0, bounds.maxLower);
    final upper = lower + draw(1, bounds.maxWidth);
    return IntegralExercise(
      lower: lower,
      upper: upper,
      c0: 1 * f[1],
      c1: 2 * f[2],
      c2: 3 * f[3],
      c3: 4 * f[4],
    );
  }
}
