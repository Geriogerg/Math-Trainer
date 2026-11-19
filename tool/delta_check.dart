// ignore_for_file: avoid_print
//
// A CLI script, not app code: console output is the deliverable.

import 'dart:math' as math;

import 'package:math_trainer/core/domain/leveling/answer_outcome.dart';
import 'package:math_trainer/core/domain/leveling/confidence.dart';
import 'package:math_trainer/core/domain/leveling/level.dart';
import 'package:math_trainer/core/domain/leveling/level_updater.dart';
import 'package:math_trainer/core/domain/leveling/leveling_rules.dart';
import 'package:math_trainer/core/domain/persistence/level_cache_entry.dart';

/// Phase 0 commit 5: is `δ` right for `n_min` = 4? Simulated players run the
/// real [LevelUpdater] against a logistic performance model — a model, not
/// data: it compares settings with each other, it does not calibrate them
/// (that is Phase 3, on real sessions).
///
/// Player model, for a question at level `L` and a true skill `S`
/// (`g = L − S`, positive when too hard):
/// - right with probability `1 / (1 + e^(g / w))`;
/// - if right, a log-normal response time of median `2.5 s · e^(g / 15)`,
///   σ = 0.4 (harder questions take longer).
///
/// The reference is the original design: `n_min` = 8, `δ` = 0.05, 8
/// answers per operation and session. Each candidate plays 4 answers per
/// session (what `n_min × active types` gives every type).
///
/// Rerun in Phase 1 commit 2 with continuous levels (integer hundredths):
/// the simulated player answers at the level's whole part, as generation
/// does; distances use the continuous value.
///
/// Usage: `dart run tool/delta_check.dart`
void main() {
  for (final w in [6.0, 10.0]) {
    final model = _Model(skill: 50, w: w);
    final target = model.equilibriumLevel(LevelingRules());
    print(
      '== Model w = $w: level where E[p] = p_cible is ${target.toStringAsFixed(1)} ==',
    );
    print(
      'n\tδ\tconvergence\tbias\tspread (sd)\toscillation (±)\tsessions that move\t'
      'eff. dead band up / down',
    );
    for (final (n, delta) in [
      (8, 0.05),
      (4, 0.05),
      (4, 0.07),
      (4, 0.10),
      (4, 0.15),
    ]) {
      final rules = LevelingRules(nMin: n, delta: delta);
      final m = _simulate(model, rules, answersPerSession: n, target: target);
      // Rounding to hundredths adds half a hundredth over K to δ (it added
      // half a level when levels were whole numbers).
      final up = delta + 0.005 / rules.kHaut;
      final down = delta + 0.005 / rules.kBas;
      print(
        '$n\t${delta.toStringAsFixed(2)}\t${m.convergence.toStringAsFixed(1)}\t\t'
        '${m.bias.toStringAsFixed(2)}\t${m.spread.toStringAsFixed(2)}\t\t'
        '${m.oscillation.toStringAsFixed(2)}\t\t${(m.moveRate * 100).toStringAsFixed(0)} %\t\t\t'
        '${up.toStringAsFixed(3)} / ${down.toStringAsFixed(3)}',
      );
    }
    print('');
  }
  print(
    'convergence: mean sessions from level 1 until within ±2 of the equilibrium level\n'
    '(capped at 150);\n'
    'bias, spread: mean and standard deviation of (level − equilibrium) over 100 sessions\n'
    'of a player started at the equilibrium level, normal confidence;\n'
    'oscillation: mean of (max − min) / 2 per player over those 100 sessions;\n'
    'eff. dead band: |mean p − p_cible| needed to move the level at all at n = n_min,\n'
    'normal confidence — rounding to hundredths adds 0.005 / K to δ (0.5 / K before\n'
    'Phase 1 commit 2, with whole levels);\n'
    'sessions that move: share of sessions that change the stored level (hundredths).',
  );
}

class _Model {
  _Model({required this.skill, required this.w});

  final double skill;
  final double w;

  AnswerOutcome answer(int level, math.Random random) {
    final g = level - skill;
    final pRight = 1 / (1 + math.exp(g / w));
    if (random.nextDouble() >= pRight) {
      return const AnswerOutcome(isCorrect: false, elapsedMs: 15000);
    }
    final median = 2500 * math.exp(g / 15);
    final ms = median * math.exp(0.4 * _gaussian(random));
    return AnswerOutcome(isCorrect: true, elapsedMs: ms.round());
  }

  /// Level (interpolated) where the expected `p` crosses `p_cible`.
  double equilibriumLevel(LevelingRules rules) {
    final random = math.Random(7);
    double expectedP(int level) {
      var sum = 0.0;
      const samples = 20000;
      for (var i = 0; i < samples; i++) {
        sum += _p(answer(level, random), rules);
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

double _p(AnswerOutcome a, LevelingRules rules) {
  if (!a.isCorrect) return 0;
  final t = a.elapsedMs;
  final speed = t <= rules.tRapideMs
      ? 1.0
      : t >= rules.tLentMs
      ? 0.0
      : 1 - (t - rules.tRapideMs) / (rules.tLentMs - rules.tRapideMs);
  return rules.f + (1 - rules.f) * speed;
}

double _gaussian(math.Random random) {
  final u1 = 1 - random.nextDouble();
  final u2 = random.nextDouble();
  return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2);
}

class _Metrics {
  _Metrics(
    this.convergence,
    this.bias,
    this.spread,
    this.oscillation,
    this.moveRate,
  );
  final double convergence;
  final double bias;
  final double spread;
  final double oscillation;
  final double moveRate;
}

_Metrics _simulate(
  _Model model,
  LevelingRules rules, {
  required int answersPerSession,
  required double target,
}) {
  const players = 2000;
  final random = math.Random(42);
  final updater = LevelUpdater(rules: rules);
  final base = DateTime.utc(2026, 1, 1);

  List<AnswerOutcome> session(int level) => [
    for (var i = 0; i < answersPerSession; i++) model.answer(level, random),
  ];

  // Convergence: a new player from level 1, calibration included.
  const convergenceCap = 150;
  var convergenceSum = 0;
  for (var p = 0; p < players; p++) {
    var level = Level.floor;
    LevelCacheEntry? prior;
    var s = 0;
    while (s < convergenceCap && (level.value - target).abs() > 2) {
      final now = base.add(Duration(days: s));
      level = updater.update(
        currentLevel: level,
        answers: session(level.whole),
        confidence: confidenceFor(entry: prior, now: now, rules: rules),
      );
      prior = LevelCacheEntry(
        level: level,
        sessionsPlayed: (prior?.sessionsPlayed ?? 0) + 1,
        updatedAt: now,
      );
      s++;
    }
    convergenceSum += s;
  }

  // Equilibrium: a settled player starting at the equilibrium level,
  // normal confidence, 100 sessions.
  const settledSessions = 100;
  final gaps = <double>[];
  var oscillationSum = 0.0;
  var moves = 0;
  for (var p = 0; p < players; p++) {
    var level = Level.fromHundredths((target * 100).round());
    var lo = level.value, hi = level.value;
    for (var s = 0; s < settledSessions; s++) {
      final next = updater.update(
        currentLevel: level,
        answers: session(level.whole),
      );
      if (next != level) moves++;
      level = next;
      gaps.add(level.value - target);
      lo = math.min(lo, level.value);
      hi = math.max(hi, level.value);
    }
    oscillationSum += (hi - lo) / 2;
  }

  final bias = gaps.reduce((a, b) => a + b) / gaps.length;
  final variance =
      gaps.map((g) => (g - bias) * (g - bias)).reduce((a, b) => a + b) /
      gaps.length;
  return _Metrics(
    convergenceSum / players,
    bias,
    math.sqrt(variance),
    oscillationSum / players,
    moves / (players * settledSessions),
  );
}
