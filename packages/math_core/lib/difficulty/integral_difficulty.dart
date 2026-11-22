import 'level_interpolation.dart';

/// The bounds an integral is drawn within at a level (Redesign phase
/// commit 4). Uncalibrated starting values, like the other types
/// (`doc/decisions.md`): level 1 is `∫₀ᵇ 2x dx` with b ≤ 3; level 100
/// reaches antiderivatives of degree 4 with every term present and bounds
/// up to 7.
class IntegralBounds {
  const IntegralBounds({
    required this.maxDegree,
    required this.maxLeading,
    required this.maxOther,
    required this.maxLower,
    required this.maxWidth,
  });

  /// The antiderivative's degree is drawn in [2, maxDegree] (p: one less).
  final int maxDegree;

  /// The antiderivative's leading coefficient, in [1, maxLeading].
  final int maxLeading;

  /// Its other coefficients (x¹ … x^(d−1)), each in [0, maxOther].
  final int maxOther;

  /// The lower bound, in [0, maxLower].
  final int maxLower;

  /// upper − lower, in [1, maxWidth].
  final int maxWidth;
}

class IntegralDifficulty {
  const IntegralDifficulty();

  IntegralBounds boundsFor(int level) => IntegralBounds(
    maxDegree: interpolateLevel(level: level, atLevel1: 2, atLevel100: 4),
    maxLeading: interpolateLevel(level: level, atLevel1: 1, atLevel100: 4),
    maxOther: interpolateLevel(level: level, atLevel1: 0, atLevel100: 3),
    maxLower: interpolateLevel(level: level, atLevel1: 0, atLevel100: 3),
    maxWidth: interpolateLevel(level: level, atLevel1: 3, atLevel100: 4),
  );
}

const integralDifficulty = IntegralDifficulty();
