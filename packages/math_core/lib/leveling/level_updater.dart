import 'dart:math' as math;

import 'answer_outcome.dart';
import 'level.dart';
import 'leveling_rules.dart';

/// Pure level update function — see `doc/decisions.md` for the full
/// semantics. Replayable over a history: calling [update] once per session,
/// passing the returned level as the next call's `currentLevel`, rebuilds
/// the whole progression — which enables recalibrating the parameters and
/// recomputing server-side.
///
/// [answers] holds the answers of **a single operation** only: the level is
/// per operation, and this function does not know `ExerciseType` — the
/// caller filters before calling.
class LevelUpdater {
  LevelUpdater({LevelingRules? rules}) : rules = rules ?? LevelingRules();

  final LevelingRules rules;

  /// [currentLevel] is valid by construction (`Level` checks its range).
  Level update({
    required Level currentLevel,
    required List<AnswerOutcome> answers,
    ConfidenceMultiplier confidence = ConfidenceMultiplier.normal,
  }) {
    if (answers.length < rules.nMin) return currentLevel;

    final meanP = answers.map(_pFor).reduce((a, b) => a + b) / answers.length;
    final rawDelta = meanP - rules.pCible;
    if (rawDelta.abs() < rules.delta) return currentLevel;

    final deadbandRemoved = rawDelta.isNegative
        ? rawDelta + rules.delta
        : rawDelta - rules.delta;
    final k = rawDelta.isNegative ? rules.kBas : rules.kHaut;
    final confidenceFactor = switch (confidence) {
      ConfidenceMultiplier.normal => 1.0,
      ConfidenceMultiplier.calibration => rules.kCalib,
      ConfidenceMultiplier.returning => rules.boostRetour,
    };

    // Volume weighting: exactly 1.0 at n = nMin (unchanged behaviour at the
    // boundary), growing as a square root beyond — 16 answers do not weigh
    // 4× more than 4, only 2×. Without it, a session of 4 answers at 85 %
    // and one of 16 answers at 85 % moved the level identically (see
    // doc/decisions.md).
    final volumeWeight = math.sqrt(answers.length / rules.nMin);

    final change = (deadbandRemoved * k * confidenceFactor * volumeWeight)
        .clamp(-rules.deltaMax.toDouble(), rules.deltaMax.toDouble());

    // The single rounding, to hundredths (rule 18: `+ − × ÷` and `sqrt`
    // above, then one `round`). Rounding to a whole level here is what used
    // to swallow every step under 0.5 (doc/decisions.md).
    return Level.clampedV1(currentLevel.hundredths + (change * 100).round());
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
