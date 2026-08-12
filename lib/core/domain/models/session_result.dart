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

  /// Sert uniquement à recalculer [scoreBreakdown] avec la même formule que
  /// celle qui a réellement produit [totalScore] — à passer explicitement
  /// depuis `SessionController` si un `Scorer` non standard est utilisé.
  final Scorer scorer;

  int get correctCount => outcomes.where((outcome) => outcome.isCorrect).length;

  double get accuracy =>
      outcomes.isEmpty ? 0 : correctCount / outcomes.length;

  double get averageElapsedMs => outcomes.isEmpty
      ? 0
      : outcomes.map((outcome) => outcome.elapsedMs).reduce((a, b) => a + b) /
            outcomes.length;

  int get timeoutCount => outcomes.where((outcome) => outcome.isTimeout).length;

  /// Fausse mais pas hors délai — `doc/design.md` distingue les deux plutôt
  /// que de les confondre sous « incorrect ».
  int get wrongCount => outcomes.length - correctCount - timeoutCount;

  /// Meilleure série de bonnes réponses consécutives, pas la série finale
  /// (`SessionState.currentStreak`) : le joueur peut avoir terminé sur une
  /// mauvaise réponse après une longue série. Reconstituée en rejouant
  /// `outcomes` — le streak à chaque instant ne dépend que de la séquence
  /// juste/faux qui précède.
  int get bestStreak {
    var current = 0;
    var best = 0;
    for (final outcome in outcomes) {
      current = outcome.isCorrect ? current + 1 : 0;
      if (current > best) best = current;
    }
    return best;
  }

  /// Décomposition du score total. `difficultyBonus` capture à la fois le
  /// multiplicateur de difficulté et l'arrondi par réponse plutôt que
  /// d'exposer un multiplicateur unique : plusieurs types (donc plusieurs
  /// niveaux figés) peuvent coexister dans une même session, et
  /// `doc/decisions.md` interdit un niveau unifié.
  ({int base, int speedBonus, int streakBonus, int difficultyBonus}) get scoreBreakdown {
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
