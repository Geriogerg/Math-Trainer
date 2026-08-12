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

  /// Au niveau 100, les points bruts sont multipliés par `1 +
  /// difficultyBonusMax` ; au niveau 1, par 1 (aucun bonus). Non calibré,
  /// voir `doc/decisions.md`.
  final double difficultyBonusMax;
}

/// Fonctions pures de calcul de points. Le streak (nombre de bonnes
/// réponses consécutives) est un état de session détenu par
/// `SessionController`, pas par `Scorer` : ce dernier reste sans état
/// interne et donc trivial à tester.
class Scorer {
  const Scorer({this.rules = const ScoringRules()});

  final ScoringRules rules;

  /// [currentStreak] compte la réponse en cours : 1 pour la première bonne
  /// réponse d'une série, 2 pour la deuxième consécutive, etc. [level] est
  /// le niveau figé de l'opération pour cette session (`SessionConfig.
  /// levels`), jamais le niveau courant du cache — la difficulté qui a
  /// réellement produit cette question.
  int pointsFor(AnswerResult answer, {required int currentStreak, required int level}) {
    // `level` validé même pour une réponse fausse (compat. avec le
    // comportement d'origine, testé explicitement) : `_difficultyMultiplier`
    // doit s'évaluer avant le court-circuit de `rawPointsFor`.
    final multiplier = _difficultyMultiplier(level);
    if (!answer.isCorrect) return 0;
    final raw = rawPointsFor(answer, currentStreak: currentStreak);
    final rawPoints = raw.base + raw.speedBonus + raw.streakBonus;
    return (rawPoints * multiplier).round();
  }

  /// Décomposition d'une réponse avant multiplicateur de difficulté —
  /// {base: 0, speedBonus: 0, streakBonus: 0} si `!answer.isCorrect`. Sert à
  /// afficher la composition du score en fin de session (`doc/design.md`) ;
  /// `pointsFor` s'appuie dessus plutôt que de dupliquer le calcul.
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
      throw ArgumentError.value(level, 'level', 'doit être compris entre 1 et 100.');
    }
    return 1 + (level - 1) / 99 * rules.difficultyBonusMax;
  }
}
