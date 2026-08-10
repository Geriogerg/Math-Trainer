import 'answer_outcome.dart';
import 'leveling_rules.dart';

/// Fonction pure de mise à jour du niveau — voir `doc/decisions.md` pour la
/// sémantique complète. Rejouable sur un historique : appeler [update] une
/// fois par session, en repassant le niveau retourné comme `currentLevel` de
/// l'appel suivant, reconstruit la progression complète — c'est ce qui
/// permettra la recalibration des paramètres et le recalcul côté serveur.
///
/// [answers] ne porte que les réponses d'**une seule opération** : le niveau
/// est par opération, et cette fonction ne connaît pas `ExerciseType` —
/// c'est à l'appelant de filtrer avant d'appeler.
class LevelUpdater {
  LevelUpdater({LevelingRules? rules}) : rules = rules ?? LevelingRules();

  final LevelingRules rules;

  int update({
    required int currentLevel,
    required List<AnswerOutcome> answers,
    ConfidenceMultiplier confidence = ConfidenceMultiplier.normal,
  }) {
    if (currentLevel < 1 || currentLevel > 100) {
      throw ArgumentError.value(currentLevel, 'currentLevel', 'doit être compris entre 1 et 100.');
    }

    if (answers.length < rules.nMin) return currentLevel;

    final meanP = answers.map(_pFor).reduce((a, b) => a + b) / answers.length;
    final rawDelta = meanP - rules.pCible;
    if (rawDelta.abs() < rules.delta) return currentLevel;

    final deadbandRemoved = rawDelta.isNegative ? rawDelta + rules.delta : rawDelta - rules.delta;
    final k = rawDelta.isNegative ? rules.kBas : rules.kHaut;
    final confidenceFactor = switch (confidence) {
      ConfidenceMultiplier.normal => 1.0,
      ConfidenceMultiplier.calibration => rules.kCalib,
      ConfidenceMultiplier.returning => rules.boostRetour,
    };

    final change = (deadbandRemoved * k * confidenceFactor).clamp(
      -rules.deltaMax.toDouble(),
      rules.deltaMax.toDouble(),
    );

    return (currentLevel + change).round().clamp(1, 100);
  }

  double _pFor(AnswerOutcome answer) {
    if (!answer.isCorrect) return 0;
    return rules.f + (1 - rules.f) * _vitesse(answer.elapsedMs);
  }

  double _vitesse(int elapsedMs) {
    final safeElapsedMs = elapsedMs < 0 ? 0 : elapsedMs;
    if (safeElapsedMs <= rules.tRapideMs) return 1.0;
    if (safeElapsedMs >= rules.tLentMs) return 0.0;
    final span = rules.tLentMs - rules.tRapideMs;
    return 1.0 - (safeElapsedMs - rules.tRapideMs) / span;
  }
}
