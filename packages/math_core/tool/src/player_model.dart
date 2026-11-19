import 'dart:math' as math;

import 'package:math_core/leveling/answer_outcome.dart';
import 'package:math_core/leveling/leveling_rules.dart';

/// Simulated player shared by the level simulations (`delta_check.dart`,
/// `placement_check.dart`) — a model, not data: it compares settings with
/// each other, it does not calibrate them (Phase 3, on real sessions).
///
/// For a question at level `L` and a true skill `S` (`g = L − S`, positive
/// when too hard):
/// - right with probability `1 / (1 + e^(g / w))`;
/// - if right, a log-normal response time of median `2.5 s · e^(g / 15)`,
///   σ = 0.4 (harder questions take longer); wrong counts as a 15 s
///   timeout for the level (it earns nothing either way).
class PlayerModel {
  PlayerModel({required this.skill, required this.w});

  final double skill;
  final double w;

  AnswerOutcome answer(int level, math.Random random) {
    final g = level - skill;
    final pRight = 1 / (1 + math.exp(g / w));
    if (random.nextDouble() >= pRight) {
      return const AnswerOutcome(isCorrect: false, elapsedMs: 15000);
    }
    final median = 2500 * math.exp(g / 15);
    final ms = median * math.exp(0.4 * gaussian(random));
    return AnswerOutcome(isCorrect: true, elapsedMs: ms.round());
  }

  /// Level (interpolated) where the expected `p` crosses `p_cible` — the
  /// level a perfect estimator would settle on for this player.
  double equilibriumLevel(LevelingRules rules) {
    final random = math.Random(7);
    double expectedP(int level) {
      var sum = 0.0;
      const samples = 20000;
      for (var i = 0; i < samples; i++) {
        sum += performance(answer(level, random), rules);
      }
      return sum / samples;
    }

    var previous = expectedP(1);
    for (var level = 2; level <= 100; level++) {
      final current = expectedP(level);
      if (previous >= rules.pCible && current < rules.pCible) {
        return level - 1 + (previous - rules.pCible) / (previous - current);
      }
      previous = current;
    }
    throw StateError('no equilibrium level in 1..100');
  }
}

/// `p` of one answer, as `LevelUpdater` scores it.
double performance(AnswerOutcome a, LevelingRules rules) {
  if (!a.isCorrect) return 0;
  final t = a.elapsedMs;
  final speed = t <= rules.tRapideMs
      ? 1.0
      : t >= rules.tLentMs
      ? 0.0
      : 1 - (t - rules.tRapideMs) / (rules.tLentMs - rules.tRapideMs);
  return rules.f + (1 - rules.f) * speed;
}

double gaussian(math.Random random) {
  final u1 = 1 - random.nextDouble();
  final u2 = random.nextDouble();
  return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2);
}
