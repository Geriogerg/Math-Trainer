import '../scoring/scorer.dart';
import 'answer_result.dart';

class SessionResult {
  const SessionResult({
    required this.outcomes,
    required this.totalScore,
    this.scorer = const Scorer(),
  });

  final List<AnswerResult> outcomes;
  final int totalScore;

  /// Only used to recompute [scoreBreakdown] with the same formula that
  /// actually produced [totalScore] — pass it explicitly from
  /// `SessionController` if a non-standard `Scorer` is used.
  final Scorer scorer;

  int get correctCount => outcomes.where((outcome) => outcome.isCorrect).length;

  double get accuracy => outcomes.isEmpty ? 0 : correctCount / outcomes.length;

  double get averageElapsedMs => outcomes.isEmpty
      ? 0
      : outcomes.map((outcome) => outcome.elapsedMs).reduce((a, b) => a + b) /
            outcomes.length;

  int get timeoutCount => outcomes.where((outcome) => outcome.isTimeout).length;

  /// Wrong but not timed out — `doc/design.md` keeps the two apart rather
  /// than merging them as "incorrect".
  int get wrongCount => outcomes.length - correctCount - timeoutCount;

  /// Best streak of consecutive right answers, not the final streak
  /// (`SessionState.currentStreak`): the player may have ended on a wrong
  /// answer after a long streak. Rebuilt by replaying `outcomes` — the
  /// streak at any moment only depends on the right/wrong sequence before
  /// it.
  int get bestStreak {
    var current = 0;
    var best = 0;
    for (final outcome in outcomes) {
      current = outcome.isCorrect ? current + 1 : 0;
      if (current > best) best = current;
    }
    return best;
  }

  /// Breakdown of the total score. `difficultyBonus` captures both the
  /// difficulty multiplier and per-answer rounding rather than exposing a
  /// single multiplier: several types (hence several frozen levels) can
  /// coexist in one session, and `doc/decisions.md` rules out a unified
  /// level.
  ({int base, int speedBonus, int streakBonus, int difficultyBonus})
  get scoreBreakdown {
    var current = 0;
    var base = 0;
    var speedBonus = 0;
    var streakBonus = 0;
    for (final outcome in outcomes) {
      current = outcome.isCorrect ? current + 1 : 0;
      final raw = scorer.rawPointsFor(outcome, currentStreak: current);
      base += raw.base;
      speedBonus += raw.speedBonus;
      streakBonus += raw.streakBonus;
    }
    return (
      base: base,
      speedBonus: speedBonus,
      streakBonus: streakBonus,
      difficultyBonus: totalScore - base - speedBonus - streakBonus,
    );
  }
}
