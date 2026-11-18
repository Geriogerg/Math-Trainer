import 'package:math_trainer/core/domain/leveling/answer_outcome.dart';
import 'package:math_trainer/core/domain/leveling/confidence.dart';
import 'package:math_trainer/core/domain/leveling/leveling_rules.dart';
import 'package:math_trainer/core/domain/leveling/level_updater.dart';
import 'package:math_trainer/core/domain/persistence/level_cache_entry.dart';

/// Pure replay and measurement logic of `tool/recalibrate.dart`, kept apart
/// from the script to stay testable (the script itself is not, easily: its
/// entry point reads a real SQLite database). Public — unlike the rest of
/// the script — precisely for that.

/// A trajectory = the answer batches of one operation for one player,
/// sorted chronologically by session, sessions under `n_min` excluded.
typedef Trajectory = List<List<AnswerOutcome>>;

class Metrics {
  const Metrics({this.convergence, this.oscillation, this.bias});
  final double? convergence;
  final double? oscillation;
  final double? bias;
}

/// Amplitude target at equilibrium (doc/decisions.md: oscillation ≤ 2).
const oscillationTarget = 2;

/// Sliding window used to detect convergence: it does not require *all* the
/// rest of the trajectory to meet the target (a single late deviation would
/// then invalidate an otherwise real convergence), only the next
/// [convergenceWindow] sessions. Oscillation and bias, once convergence is
/// detected, are still measured over the whole rest of the trajectory — the
/// detection must tolerate an isolated accident, not the characterisation
/// of the equilibrium.
const convergenceWindow = 5;

/// Replays a trajectory with [rules], starting level 1. `sessionsPlayed`
/// and absence for `confidenceFor` are rebuilt from the replay itself — not
/// from `player_levels`, which only reflects the current state, not the
/// full history.
List<int> replay(
  Trajectory trajectory,
  LevelingRules rules,
  DateTime baseTime,
) {
  final updater = LevelUpdater(rules: rules);
  var level = 1;
  LevelCacheEntry? prior;
  final levels = <int>[];

  for (var i = 0; i < trajectory.length; i++) {
    final now = baseTime.add(
      Duration(days: i),
    ); // no real timestamps replayed here
    final confidence = confidenceFor(entry: prior, now: now, rules: rules);
    level = updater.update(
      currentLevel: level,
      answers: trajectory[i],
      confidence: confidence,
    );
    levels.add(level);
    prior = LevelCacheEntry(
      level: level,
      sessionsPlayed: (prior?.sessionsPlayed ?? 0) + 1,
      updatedAt: now,
    );
  }
  return levels;
}

/// First index from which a window of [convergenceWindow] sessions (or
/// fewer, at the end of the trajectory) has an amplitude (max−min) under
/// [oscillationTarget] — `null` if never reached. A window of length 1
/// allows no conclusion (zero amplitude by construction) and is ignored.
int? convergenceIndex(List<int> levels) {
  for (var i = 0; i < levels.length; i++) {
    final windowEnd = (i + convergenceWindow < levels.length)
        ? i + convergenceWindow
        : levels.length;
    final window = levels.sublist(i, windowEnd);
    if (window.length < 2) continue;
    final amplitude =
        window.reduce((a, b) => a > b ? a : b) -
        window.reduce((a, b) => a < b ? a : b);
    if (amplitude <= oscillationTarget) return i;
  }
  return null;
}

double? mean(List<double> values) =>
    values.isEmpty ? null : values.reduce((a, b) => a + b) / values.length;

/// Replays all [trajectories] with [rules] and averages the metrics.
/// Oscillation and bias are measured over the whole rest of the trajectory
/// from the convergence point (see [convergenceWindow] for why the
/// detection itself is more tolerant).
Metrics averageMetrics(
  List<Trajectory> trajectories,
  LevelingRules rules,
  DateTime baseTime,
) {
  final convergences = <double>[];
  final oscillations = <double>[];
  final biases = <double>[];

  for (final trajectory in trajectories) {
    final levels = replay(trajectory, rules, baseTime);
    final convergedAt = convergenceIndex(levels);
    if (convergedAt == null) continue;

    convergences.add(convergedAt.toDouble());
    final tail = levels.sublist(convergedAt);
    oscillations.add(
      (tail.reduce((a, b) => a > b ? a : b) -
              tail.reduce((a, b) => a < b ? a : b))
          .toDouble(),
    );
    if (tail.length >= 2) {
      final diffs = [
        for (var i = 1; i < tail.length; i++) tail[i] - tail[i - 1],
      ];
      biases.add(diffs.reduce((a, b) => a + b) / diffs.length);
    }
  }

  return Metrics(
    convergence: mean(convergences),
    oscillation: mean(oscillations),
    bias: mean(biases),
  );
}
