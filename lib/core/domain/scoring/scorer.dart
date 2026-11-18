import '../models/answer_result.dart';

class ScoringRules {
  const ScoringRules({
    this.basePoints = 10,
    this.maxSpeedBonus = 10,
    this.speedBonusWindowMs = 5000,
    this.streakBonusPerStep = 2,
    this.maxStreakBonus = 20,
    this.difficultyBonusMax = 1.0,
  });

  final int basePoints;
  final int maxSpeedBonus;
  final int speedBonusWindowMs;
  final int streakBonusPerStep;
  final int maxStreakBonus;

  /// At level 100, raw points are multiplied by `1 + difficultyBonusMax`;
  /// at level 1, by 1 (no bonus). Uncalibrated, see
  /// `doc/decisions.md`.
  final double difficultyBonusMax;
}

/// Pure point computations. The streak (number of consecutive right
/// answers) is session state held by `SessionController`, not by `Scorer`:
/// the scorer stays stateless and therefore trivial to test.
class Scorer {
  const Scorer({this.rules = const ScoringRules()});

  final ScoringRules rules;

  /// [currentStreak] counts the current answer: 1 for the first right
  /// answer of a streak, 2 for the second in a row, etc. [level] is the
  /// operation's frozen level for this session (`SessionConfig.levels`),
  /// never the cache's current level — the difficulty that actually
  /// produced this question.
  int pointsFor(AnswerResult answer, {required int currentStreak, required int level}) {
    // `level` is validated even for a wrong answer (compatible with the
    // original behaviour, tested explicitly): `_difficultyMultiplier` must
    // run before `rawPointsFor` short-circuits.
    final multiplier = _difficultyMultiplier(level);
    if (!answer.isCorrect) return 0;
    final raw = rawPointsFor(answer, currentStreak: currentStreak);
    final rawPoints = raw.base + raw.speedBonus + raw.streakBonus;
    return (rawPoints * multiplier).round();
  }

  /// Breakdown of one answer before the difficulty multiplier —
  /// {base: 0, speedBonus: 0, streakBonus: 0} if `!answer.isCorrect`. Used to
  /// show the score breakdown at the end of a session (`doc/design.md`);
  /// `pointsFor` relies on it rather than duplicating the computation.
  ({int base, int speedBonus, int streakBonus}) rawPointsFor(
    AnswerResult answer, {
    required int currentStreak,
  }) {
    if (!answer.isCorrect) return (base: 0, speedBonus: 0, streakBonus: 0);
    return (
      base: rules.basePoints,
      speedBonus: _speedBonus(answer.elapsedMs),
      streakBonus: _streakBonus(currentStreak),
    );
  }

  int _speedBonus(int elapsedMs) {
    if (elapsedMs >= rules.speedBonusWindowMs) return 0;
    final safeElapsedMs = elapsedMs < 0 ? 0 : elapsedMs;
    final fraction = 1 - (safeElapsedMs / rules.speedBonusWindowMs);
    return (rules.maxSpeedBonus * fraction).round();
  }

  int _streakBonus(int currentStreak) {
    final bonus = (currentStreak - 1) * rules.streakBonusPerStep;
    if (bonus <= 0) return 0;
    return bonus > rules.maxStreakBonus ? rules.maxStreakBonus : bonus;
  }

  double _difficultyMultiplier(int level) {
    if (level < 1 || level > 100) {
      throw ArgumentError.value(level, 'level', 'must be between 1 and 100.');
    }
    return 1 + (level - 1) / 99 * rules.difficultyBonusMax;
  }
}
