import '../models/answer_result.dart';

class ScoringRules {
  const ScoringRules({
    this.basePoints = 10,
    this.maxSpeedBonus = 10,
    this.speedBonusWindowMs = 5000,
    this.streakBonusPerStep = 2,
    this.maxStreakBonus = 20,
  });

  final int basePoints;
  final int maxSpeedBonus;
  final int speedBonusWindowMs;
  final int streakBonusPerStep;
  final int maxStreakBonus;
}

/// Fonctions pures de calcul de points. Le streak (nombre de bonnes
/// réponses consécutives) est un état de session détenu par
/// `SessionController`, pas par `Scorer` : ce dernier reste sans état
/// interne et donc trivial à tester.
class Scorer {
  const Scorer({this.rules = const ScoringRules()});

  final ScoringRules rules;

  /// [currentStreak] compte la réponse en cours : 1 pour la première bonne
  /// réponse d'une série, 2 pour la deuxième consécutive, etc.
  int pointsFor(AnswerResult answer, {required int currentStreak}) {
    if (!answer.isCorrect) return 0;
    return rules.basePoints +
        _speedBonus(answer.elapsedMs) +
        _streakBonus(currentStreak);
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
}
