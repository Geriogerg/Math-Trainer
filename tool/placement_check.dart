// ignore_for_file: avoid_print
//
// A CLI script, not app code: console output is the deliverable.

import 'dart:math' as math;

import 'package:math_trainer/core/domain/leveling/confidence.dart';
import 'package:math_trainer/core/domain/leveling/level.dart';
import 'package:math_trainer/core/domain/leveling/level_updater.dart';
import 'package:math_trainer/core/domain/leveling/leveling_rules.dart';
import 'package:math_trainer/core/domain/persistence/level_cache_entry.dart';
import 'package:math_trainer/core/domain/placement/placement.dart';

import 'src/player_model.dart';

/// Phase 1 commit 6: which start level, first step and pass time make the
/// placement test land a new player near their level, and how many games
/// does a placed player then need? Simulated players (`PlayerModel`) take
/// the real staircase (`core/domain/placement`) and then play games through
/// the real `LevelUpdater`.
///
/// Players: true skill uniform over [15, 95] (equilibrium levels roughly
/// 9–89), 2,000 per setting, both model steepnesses. "At their level":
/// within ±3 of the equilibrium level (the ±2 used in `delta_check` is the
/// natural oscillation itself once levels are continuous).
///
/// Usage: `dart run tool/placement_check.dart`
void main() {
  final rules = LevelingRules();
  for (final w in [6.0, 10.0]) {
    // Equilibrium depends on L − S only: one offset per steepness.
    final offset = PlayerModel(skill: 50, w: w).equilibriumLevel(rules) - 50;
    print(
      '== Model w = $w (equilibrium = skill ${offset.toStringAsFixed(1)}) ==',
    );
    print('Stage 1 — placement alone (24 questions):');
    print(
      'start\tstep\tpass ms\tbias\tmean |err|\twithin ±5\twithin ±10\tduration p50 / p90',
    );
    final scored = <(double, PlacementRules)>[];
    for (final start in [25, 35, 50]) {
      for (final step in [1600, 2000, 2500, 3200]) {
        for (final passMs in [3000, 4000, 5000, 6000]) {
          final placement = PlacementRules(
            version: 0,
            startLevel: start,
            firstStepHundredths: step,
            questionsPerType: 6,
            passMaxElapsedMs: passMs,
            sessionsPlayedAfter: 1,
          );
          final m = _placementOnly(placement, w, offset);
          scored.add((m.meanAbs, placement));
          print(
            '$start\t$step\t$passMs\t${m.bias.toStringAsFixed(1)}\t'
            '${m.meanAbs.toStringAsFixed(1)}\t\t'
            '${(m.within5 * 100).toStringAsFixed(0)} %\t\t'
            '${(m.within10 * 100).toStringAsFixed(0)} %\t\t'
            '${m.p50s.toStringAsFixed(0)} s / ${m.p90s.toStringAsFixed(0)} s',
          );
        }
      }
    }
    scored.sort((a, b) => a.$1.compareTo(b.$1));

    print('\nStage 2 — then games (4 answers of the type per game):');
    print(
      'setting\t\t\t\tafter\tgames to ±3 (mean / p90)\tmean |err| after 5 / 10 games',
    );
    final base = _games(null, w, offset, sessionsPlayedAfter: 0);
    print(
      'no placement (from level 1)\t0\t${base.meanGames.toStringAsFixed(1)} / '
      '${base.p90Games}\t\t\t${base.err5.toStringAsFixed(1)} / ${base.err10.toStringAsFixed(1)}',
    );
    for (final (_, placement) in scored.take(4)) {
      for (final after in [0, 1, 3]) {
        final m = _games(placement, w, offset, sessionsPlayedAfter: after);
        print(
          'start ${placement.startLevel}, step ${placement.firstStepHundredths}, '
          '${placement.passMaxElapsedMs} ms\t$after\t'
          '${m.meanGames.toStringAsFixed(1)} / ${m.p90Games}\t\t\t'
          '${m.err5.toStringAsFixed(1)} / ${m.err10.toStringAsFixed(1)}',
        );
      }
    }
    print('');
  }
  print(
    'bias: mean (placed − equilibrium); duration: model answer times, a wrong\n'
    'answer counted 8 s (not the 15 s timeout the level model uses) plus the\n'
    "1 s correction pause; 'after': sessionsPlayed written by the placement\n"
    '(< 3 keeps the calibration boost for the next 3 − after games).',
  );
}

const _players = 2000;

typedef _PlacementMetrics = ({
  double bias,
  double meanAbs,
  double within5,
  double within10,
  double p50s,
  double p90s,
});

/// Runs one placement for a player; returns the placed level of one
/// operation (all four share the model's skill, so the others are
/// independent repeats — averaged) and the duration.
(List<Level>, double seconds) _place(
  PlacementRules placement,
  PlayerModel model,
  math.Random random,
) {
  final answers = <({bool isCorrect, int elapsedMs})>[];
  var seconds = 0.0;
  for (var i = 0; i < placement.questionCount; i++) {
    final stairs = replayStaircases(answers, placement);
    final level = stairs[placementTypeAt(i)]!.level.whole;
    final a = model.answer(level, random);
    answers.add((isCorrect: a.isCorrect, elapsedMs: a.elapsedMs));
    seconds += a.isCorrect ? a.elapsedMs / 1000 : 9;
  }
  return (placementLevels(answers, placement).values.toList(), seconds);
}

_PlacementMetrics _placementOnly(
  PlacementRules placement,
  double w,
  double offset,
) {
  final random = math.Random(42);
  final errors = <double>[];
  final durations = <double>[];
  for (var p = 0; p < _players; p++) {
    final skill = 15 + random.nextDouble() * 80;
    final target = (skill + offset).clamp(1, 100);
    final (levels, seconds) = _place(
      placement,
      PlayerModel(skill: skill, w: w),
      random,
    );
    for (final level in levels) {
      errors.add(level.value - target);
    }
    durations.add(seconds);
  }
  durations.sort();
  final n = errors.length;
  return (
    bias: errors.reduce((a, b) => a + b) / n,
    meanAbs: errors.map((e) => e.abs()).reduce((a, b) => a + b) / n,
    within5: errors.where((e) => e.abs() <= 5).length / n,
    within10: errors.where((e) => e.abs() <= 10).length / n,
    p50s: durations[durations.length ~/ 2],
    p90s: durations[(durations.length * 9) ~/ 10],
  );
}

typedef _GameMetrics = ({
  double meanGames,
  int p90Games,
  double err5,
  double err10,
});

/// Placement (or none: level 1, never played), then games of 4 answers on
/// one placed operation, real `LevelUpdater` and confidence.
_GameMetrics _games(
  PlacementRules? placement,
  double w,
  double offset, {
  required int sessionsPlayedAfter,
}) {
  final random = math.Random(43);
  final updater = LevelUpdater();
  final base = DateTime.utc(2026, 1, 1);
  const cap = 150;
  final gamesNeeded = <int>[];
  final err5 = <double>[];
  final err10 = <double>[];
  for (var p = 0; p < _players; p++) {
    final skill = 15 + random.nextDouble() * 80;
    final model = PlayerModel(skill: skill, w: w);
    final target = (skill + offset).clamp(1, 100);
    var level = Level.floor;
    LevelCacheEntry? prior;
    if (placement != null) {
      level = _place(placement, model, random).$1.first;
      prior = LevelCacheEntry(
        level: level,
        sessionsPlayed: sessionsPlayedAfter,
        updatedAt: base,
      );
    }
    int? reached = (level.value - target).abs() <= 3 ? 0 : null;
    for (var g = 1; g <= cap; g++) {
      final now = base.add(Duration(days: g));
      level = updater.update(
        currentLevel: level,
        answers: [
          for (var i = 0; i < 4; i++) model.answer(level.whole, random),
        ],
        confidence: confidenceFor(entry: prior, now: now, rules: updater.rules),
      );
      prior = LevelCacheEntry(
        level: level,
        sessionsPlayed: (prior?.sessionsPlayed ?? 0) + 1,
        updatedAt: now,
      );
      if (reached == null && (level.value - target).abs() <= 3) reached = g;
      if (g == 5) err5.add((level.value - target).abs());
      if (g == 10) err10.add((level.value - target).abs());
    }
    gamesNeeded.add(reached ?? cap);
  }
  gamesNeeded.sort();
  // A fold, not `reduce`: `reduce` with a `num` callback fails on a
  // runtime `List<int>`.
  double mean(List<num> xs) => xs.fold<double>(0, (s, x) => s + x) / xs.length;
  return (
    meanGames: mean(gamesNeeded),
    p90Games: gamesNeeded[(gamesNeeded.length * 9) ~/ 10],
    err5: mean(err5),
    err10: mean(err10),
  );
}
