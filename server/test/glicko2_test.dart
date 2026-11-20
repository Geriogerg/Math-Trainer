import 'package:math_trainer_server/server.dart';
import 'package:test/test.dart';

const _closeTo = closeTo;

/// Phase 5.2 commit 3: Glicko-2 as Glickman's "Example of the Glicko-2
/// system" (2013) computes it, and rating periods without games.
void main() {
  test("Glickman's worked example", () {
    // A player rated 1500 (RD 200, σ 0.06) plays three games in the
    // period, τ = 0.5: beats a 1400 (RD 30), loses to a 1550 (RD 100) and
    // to a 1700 (RD 300).
    const player = Glicko2Rating(
      rating: 1500,
      deviation: 200,
      volatility: 0.06,
    );
    final after = glicko2Update(player, [
      (
        opponent: const Glicko2Rating(
          rating: 1400,
          deviation: 30,
          volatility: 0.06,
        ),
        score: 1,
      ),
      (
        opponent: const Glicko2Rating(
          rating: 1550,
          deviation: 100,
          volatility: 0.06,
        ),
        score: 0,
      ),
      (
        opponent: const Glicko2Rating(
          rating: 1700,
          deviation: 300,
          volatility: 0.06,
        ),
        score: 0,
      ),
    ], tau: 0.5);
    // The paper's results: r' = 1464.06, RD' = 151.52, σ' = 0.05999.
    expect(after.rating, _closeTo(1464.06, 0.01));
    expect(after.deviation, _closeTo(151.52, 0.01));
    expect(after.volatility, _closeTo(0.05999, 0.00001));
    // On the Glicko-2 scale: μ' = −0.2069, φ' = 0.8722.
    expect((after.rating - 1500) / glicko2Scale, _closeTo(-0.2069, 0.0001));
    expect(after.deviation / glicko2Scale, _closeTo(0.8722, 0.0001));
  });

  group('a rating period with no games', () {
    test('only the deviation grows: φ\' = √(φ² + σ²)', () {
      const player = Glicko2Rating(
        rating: 1720,
        deviation: 80,
        volatility: 0.06,
      );
      final after = glicko2Update(player, const []);
      expect(after.rating, 1720);
      expect(after.volatility, 0.06);
      final phi = 80 / glicko2Scale;
      final expected = glicko2Scale * (phi * phi + 0.06 * 0.06).sqrtValue;
      expect(after.deviation, _closeTo(expected, 1e-9));
      expect(after.deviation, greaterThan(80));
    });

    test('never beyond a new player\'s uncertainty (350)', () {
      var rating = const Glicko2Rating(
        rating: 1600,
        deviation: 340,
        volatility: 0.06,
      );
      for (var period = 0; period < 1000; period++) {
        rating = glicko2Update(rating, const []);
      }
      expect(rating.deviation, 350);
      expect(rating.rating, 1600);
      expect(glicko2Update(newPlayerRating, const []).deviation, 350);
    });
  });

  test(
    'a win raises the rating and narrows the deviation; a loss lowers it',
    () {
      final win = glicko2Update(newPlayerRating, [
        (opponent: newPlayerRating, score: 1),
      ]);
      final loss = glicko2Update(newPlayerRating, [
        (opponent: newPlayerRating, score: 0),
      ]);
      final draw = glicko2Update(newPlayerRating, [
        (opponent: newPlayerRating, score: 0.5),
      ]);
      expect(win.rating, greaterThan(1500));
      expect(loss.rating, lessThan(1500));
      expect(draw.rating, _closeTo(1500, 1e-9));
      expect(win.deviation, lessThan(350));
      // Symmetric around the start.
      expect(win.rating - 1500, _closeTo(1500 - loss.rating, 1e-6));
    },
  );

  test('a large surprise moves the volatility up', () {
    const steady = Glicko2Rating(rating: 1500, deviation: 50, volatility: 0.06);
    final upset = glicko2Update(steady, [
      for (var i = 0; i < 10; i++)
        (
          opponent: const Glicko2Rating(
            rating: 2300,
            deviation: 50,
            volatility: 0.06,
          ),
          score: 1.0,
        ),
    ]);
    expect(upset.volatility, greaterThan(0.06));
    // A settled player (RD 50) moves, but not all the way at once.
    expect(upset.rating, greaterThan(1600));
  });

  group('invalid input throws', () {
    test('deviation, volatility, rating', () {
      for (final bad in [
        const Glicko2Rating(rating: 1500, deviation: 0, volatility: 0.06),
        const Glicko2Rating(rating: 1500, deviation: 200, volatility: 0),
        const Glicko2Rating(
          rating: double.nan,
          deviation: 200,
          volatility: 0.06,
        ),
        const Glicko2Rating(
          rating: 1500,
          deviation: double.infinity,
          volatility: 0.06,
        ),
      ]) {
        expect(() => glicko2Update(bad, const []), throwsArgumentError);
        expect(
          () => glicko2Update(newPlayerRating, [(opponent: bad, score: 1)]),
          throwsArgumentError,
        );
      }
    });

    test('a score outside 0–1, a τ not positive', () {
      for (final score in [-0.1, 1.5, double.nan]) {
        expect(
          () => glicko2Update(newPlayerRating, [
            (opponent: newPlayerRating, score: score),
          ]),
          throwsArgumentError,
        );
      }
      expect(
        () => glicko2Update(newPlayerRating, const [], tau: 0),
        throwsArgumentError,
      );
    });
  });
}

extension on double {
  double get sqrtValue {
    // Newton's method: the test keeps its own square root, independent of
    // the code under test.
    var x = this;
    for (var i = 0; i < 60; i++) {
      x = (x + this / x) / 2;
    }
    return x;
  }
}
