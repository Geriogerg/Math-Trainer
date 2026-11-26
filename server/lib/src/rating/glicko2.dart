import 'dart:math';

/// Glicko-2 (Phase 5.2 commit 3, Phase 7's rating moved earlier): the duel
/// rating, computed by the server only — the app never rates
/// (`duel_rating_update.dart`, used by `DuelEndpoint`). Follows Glickman,
/// "Example of the Glicko-2 system" (2013),
/// step by step; tested against its worked example.
///
/// Floating point and `exp`/`log` are fine here: rule 18 (integers only)
/// covers generation and level maths, which must match between the VM and
/// JavaScript. Ratings are computed on the server's VM alone.

/// The scale factor between the Glicko and Glicko-2 scales (step 2).
const glicko2Scale = 173.7178;

/// A new player (Glickman: 1500, RD 350, volatility 0.06).
const newPlayerRating = Glicko2Rating(
  rating: 1500,
  deviation: 350,
  volatility: 0.06,
);

final class Glicko2Rating {
  const Glicko2Rating({
    required this.rating,
    required this.deviation,
    required this.volatility,
  });

  /// r, on the familiar scale (1500 for a new player).
  final double rating;

  /// RD: the uncertainty on [rating]; large while few games are played.
  final double deviation;

  /// σ: how erratic the player's results are.
  final double volatility;

  void _check() {
    if (!rating.isFinite) {
      throw ArgumentError.value(rating, 'rating', 'must be finite.');
    }
    if (!(deviation > 0) || !deviation.isFinite) {
      throw ArgumentError.value(deviation, 'deviation', 'must be > 0.');
    }
    if (!(volatility > 0) || !volatility.isFinite) {
      throw ArgumentError.value(volatility, 'volatility', 'must be > 0.');
    }
  }

  @override
  String toString() =>
      'Glicko2Rating(${rating.toStringAsFixed(2)}, '
      'RD ${deviation.toStringAsFixed(2)}, σ ${volatility.toStringAsFixed(5)})';
}

/// One game of the rating period: the opponent as rated at its start, and
/// the score (1 a win, 0.5 a draw, 0 a loss).
typedef Glicko2Game = ({Glicko2Rating opponent, double score});

/// The player's rating after one rating period with [games] (steps 1–8).
///
/// [tau] constrains how fast volatility moves (Glickman: 0.3 to 1.2; 0.5
/// is the example's). A period without games only widens the deviation
/// (step 6), never past [maxDeviation] — a player away for long is as
/// uncertain as a new one, no more (provisional, Phase 5.2).
Glicko2Rating glicko2Update(
  Glicko2Rating player,
  List<Glicko2Game> games, {
  double tau = 0.5,
  double maxDeviation = 350,
}) {
  player._check();
  if (!(tau > 0)) throw ArgumentError.value(tau, 'tau', 'must be > 0.');
  for (final game in games) {
    game.opponent._check();
    if (!(game.score >= 0 && game.score <= 1)) {
      throw ArgumentError.value(
        game.score,
        'score',
        'must be between 0 and 1.',
      );
    }
  }

  // Step 2: to the Glicko-2 scale.
  final mu = (player.rating - 1500) / glicko2Scale;
  final phi = player.deviation / glicko2Scale;
  final sigma = player.volatility;

  if (games.isEmpty) {
    // Step 6 alone: only the deviation grows.
    final widened = sqrt(phi * phi + sigma * sigma) * glicko2Scale;
    return Glicko2Rating(
      rating: player.rating,
      deviation: min(widened, maxDeviation),
      volatility: sigma,
    );
  }

  // Steps 3 and 4: the estimated variance v and the improvement Δ.
  var vInverse = 0.0;
  var sum = 0.0;
  for (final game in games) {
    final muJ = (game.opponent.rating - 1500) / glicko2Scale;
    final phiJ = game.opponent.deviation / glicko2Scale;
    final gJ = _g(phiJ);
    final e = 1 / (1 + exp(-gJ * (mu - muJ)));
    vInverse += gJ * gJ * e * (1 - e);
    sum += gJ * (game.score - e);
  }
  final v = 1 / vInverse;
  final delta = v * sum;

  // Step 5: the new volatility (the Illinois algorithm, ε = 0.000001).
  final sigmaPrime = _newVolatility(delta, phi, v, sigma, tau);

  // Steps 6 and 7: the new deviation and rating.
  final phiStar = sqrt(phi * phi + sigmaPrime * sigmaPrime);
  final phiPrime = 1 / sqrt(1 / (phiStar * phiStar) + 1 / v);
  final muPrime = mu + phiPrime * phiPrime * sum;

  // Step 8: back to the familiar scale.
  return Glicko2Rating(
    rating: glicko2Scale * muPrime + 1500,
    deviation: min(glicko2Scale * phiPrime, maxDeviation),
    volatility: sigmaPrime,
  );
}

double _g(double phi) => 1 / sqrt(1 + 3 * phi * phi / (pi * pi));

double _newVolatility(
  double delta,
  double phi,
  double v,
  double sigma,
  double tau,
) {
  const epsilon = 0.000001;
  final a = log(sigma * sigma);
  double f(double x) {
    final ex = exp(x);
    final d = phi * phi + v + ex;
    return ex * (delta * delta - phi * phi - v - ex) / (2 * d * d) -
        (x - a) / (tau * tau);
  }

  var bigA = a;
  double bigB;
  if (delta * delta > phi * phi + v) {
    bigB = log(delta * delta - phi * phi - v);
  } else {
    var k = 1;
    while (f(a - k * tau) < 0) {
      k++;
    }
    bigB = a - k * tau;
  }
  var fA = f(bigA);
  var fB = f(bigB);
  while ((bigB - bigA).abs() > epsilon) {
    final bigC = bigA + (bigA - bigB) * fA / (fB - fA);
    final fC = f(bigC);
    if (fC * fB <= 0) {
      bigA = bigB;
      fA = fB;
    } else {
      fA = fA / 2;
    }
    bigB = bigC;
    fB = fC;
  }
  return exp(bigA / 2);
}
