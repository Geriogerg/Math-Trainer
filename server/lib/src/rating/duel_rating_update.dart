import 'glicko2.dart';

/// Glicko-2's τ for duels (plan v3.7, owner decision).
const duelTau = 0.5;

/// No deviation above this (plan v3.7): a new player's.
const duelMaxDeviation = 350.0;

/// Both players' ratings after one rated duel (plan v3.7, Phase 7 commit
/// 3): **each duel is its own rating period**, for both — each player is
/// updated with one game against the other's rating as it stood before the
/// duel. [secondScore] is the second player's: 1 a win, 0.5 a draw, 0 a
/// loss; the first player's is its complement. The run's owner (first) is
/// rated as well, and learns it later.
({Glicko2Rating first, Glicko2Rating second}) rateDuel({
  required Glicko2Rating first,
  required Glicko2Rating second,
  required double secondScore,
}) => (
  first: glicko2Update(
    first,
    [(opponent: second, score: 1 - secondScore)],
    tau: duelTau,
    maxDeviation: duelMaxDeviation,
  ),
  second: glicko2Update(
    second,
    [(opponent: first, score: secondScore)],
    tau: duelTau,
    maxDeviation: duelMaxDeviation,
  ),
);
