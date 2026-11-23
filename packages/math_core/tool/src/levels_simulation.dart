import 'dart:math';

import 'package:math_core/leveling/answer_outcome.dart';
import 'package:math_core/leveling/level.dart';
import 'package:math_core/leveling/level_change.dart';
import 'package:math_core/leveling/level_rules.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/tiers/fluent_time.dart';

/// A simulated player of one operation: each answer right with probability
/// [accuracy], a right one fluent with probability [fluent] (else slow,
/// within 30 s). The same at every tier — real players stall earlier, at
/// the tier where their accuracy drops (`doc/levels.md`, section 3).
typedef SimulatedPlayer = ({String name, double accuracy, double fluent});

const simulatedPlayers = <SimulatedPlayer>[
  (name: 'perfect', accuracy: 1.0, fluent: 1.0),
  (name: 'perfect, slow', accuracy: 1.0, fluent: 0.0),
  (name: '80 %', accuracy: 0.8, fluent: 1.0),
  (name: '70 %', accuracy: 0.7, fluent: 1.0),
  (name: '60 %', accuracy: 0.6, fluent: 1.0),
];

/// The questions per operation a game offers.
const questionCounts = [4, 5, 10, 20];

/// Games of [questions] questions one simulated player needs to reach the
/// start of each tier T1…T9 (levels 10, 20 … 90), from level 0, under
/// [rules] (`levelAfterGame`, the fluent time of the level's tier).
/// `null`: not reached within [maxGames].
List<int?> gamesToTiers(
  SimulatedPlayer player, {
  required Random random,
  required LevelRules rules,
  int questions = 10,
  int maxGames = 500,
  ExerciseType type = ExerciseType.addition,
}) {
  final reached = List<int?>.filled(9, null);
  var level = Level.zero;
  for (var game = 1; game <= maxGames; game++) {
    final fluentMs = fluentTimeMs(type, level);
    final answers = [
      for (var i = 0; i < questions; i++)
        () {
          final right = random.nextDouble() < player.accuracy;
          final fluent = random.nextDouble() < player.fluent;
          return AnswerOutcome(
            isCorrect: right,
            elapsedMs: right && fluent ? fluentMs : 29000,
          );
        }(),
    ];
    level = levelAfterGame(
      current: level,
      answers: answers,
      fluentMs: fluentMs,
      rules: rules,
    );
    for (var t = 1; t <= 9; t++) {
      if (reached[t - 1] == null && level.whole >= 10 * t) {
        reached[t - 1] = game;
      }
    }
    if (reached.last != null) break;
  }
  return reached;
}

/// The median over [runs] seeded players: per tier, `null` when more than
/// half never reached it.
List<int?> medianGamesToTiers(
  SimulatedPlayer player, {
  required LevelRules rules,
  int runs = 1001,
  int questions = 10,
  int seed = 2026,
}) {
  final perTier = List.generate(9, (_) => <int>[]);
  final random = Random(seed);
  for (var r = 0; r < runs; r++) {
    final reached = gamesToTiers(
      player,
      random: random,
      rules: rules,
      questions: questions,
    );
    for (var t = 0; t < 9; t++) {
      perTier[t].add(reached[t] ?? 1 << 30);
    }
  }
  return [
    for (final games in perTier)
      () {
        games.sort();
        final median = games[games.length ~/ 2];
        return median >= 1 << 30 ? null : median;
      }(),
  ];
}

/// The exact expected change, in levels, of one operation's level after a
/// game of [questions] answers on it, for a player right with probability
/// [accuracy], a right answer fluent with probability [fluent]: every
/// outcome (so many fluent, so many slow, the rest wrong) weighted by its
/// multinomial probability, each moved by the real [levelChangeHundredths].
/// No clamping: the drift inside a tier.
double expectedChange(
  LevelRules rules, {
  required int questions,
  required double accuracy,
  double fluent = 1.0,
}) {
  final pFluent = accuracy * fluent;
  final pSlow = accuracy * (1 - fluent);
  final pWrong = 1 - accuracy;
  var expected = 0.0;
  for (var f = 0; f <= questions; f++) {
    for (var s = 0; s <= questions - f; s++) {
      final w = questions - f - s;
      final probability =
          _multinomial(questions, f, s) *
          _power(pFluent, f) *
          _power(pSlow, s) *
          _power(pWrong, w);
      if (probability == 0) continue;
      final change = levelChangeHundredths(
        questions: questions,
        creditPercent:
            f * LevelRules.fluentCreditPercent + s * rules.slowCreditPercent,
        rules: rules,
      );
      expected += probability * change / 100;
    }
  }
  return expected;
}

/// The accuracy, in percent to a tenth, at which a player's level stops
/// moving on average ([expectedChange] = 0): the stall. Below it the level
/// drifts down, above it up. `null`: it never stops (a drift of one sign
/// at every accuracy).
double? stallAccuracyPercent(
  LevelRules rules, {
  required int questions,
  double fluent = 1.0,
}) {
  double at(double p) =>
      expectedChange(rules, questions: questions, accuracy: p, fluent: fluent);
  var low = 0.0;
  var high = 1.0;
  if (at(low) >= 0 || at(high) <= 0) return null;
  for (var i = 0; i < 40; i++) {
    final mid = (low + high) / 2;
    if (at(mid) < 0) {
      low = mid;
    } else {
      high = mid;
    }
  }
  return ((low + high) / 2 * 1000).round() / 10;
}

/// The plan's targets for the level update (v3.2, Levels close-out step
/// 1), checked on [rules]: each with what was measured.
List<({String target, String measured, bool met})> targetsFor(
  LevelRules rules,
) {
  final stalls = [
    for (final n in questionCounts) stallAccuracyPercent(rules, questions: n),
  ];
  final slowFour = levelChangeHundredths(
    questions: 4,
    creditPercent: 4 * rules.slowCreditPercent,
    rules: rules,
  );
  final perfect = [
    for (final n in questionCounts)
      levelChangeHundredths(
        questions: n,
        creditPercent: n * LevelRules.fluentCreditPercent,
        rules: rules,
      ),
  ];
  final worst = [
    for (final n in questionCounts)
      levelChangeHundredths(questions: n, creditPercent: 0, rules: rules),
  ].reduce(min);
  String levels(int hundredths) => (hundredths / 100).toStringAsFixed(2);
  return [
    (
      target: 'stall between 60 and 70 % correct (n = 4/5/10/20)',
      measured: stalls.map((s) => s == null ? 'none' : '$s %').join(' / '),
      met: stalls.every((s) => s != null && s >= 60 && s <= 70),
    ),
    (
      target: '4 questions, all correct but slow: at least +1.5',
      measured: '+${levels(slowFour)}',
      met: slowFour >= 150,
    ),
    (
      target: 'a perfect game gains the full cap +3/+3/+4/+5',
      measured: perfect.map((c) => '+${levels(c)}').join(' / '),
      met: [
        for (final (i, n) in questionCounts.indexed)
          perfect[i] == 100 * rules.capUpFor(n),
      ].every((m) => m),
    ),
    (
      target: 'a bad game never costs more than 3 levels',
      measured: levels(worst),
      met: worst >= -300,
    ),
  ];
}

/// The candidates searched around the plan's starting point: only the three
/// constants the plan opens to tuning move.
Iterable<LevelRules> candidateRules() sync* {
  for (final slow in [80, 85, 90]) {
    for (var low = 56; low <= 66; low += 2) {
      for (var high = low + 6; high <= 75; high += 2) {
        for (final down in [2, 3]) {
          yield LevelRules(
            slowCreditPercent: slow,
            deadBandLowPercent: low,
            deadBandHighPercent: high,
            capDownLevels: down,
          );
        }
      }
    }
  }
}

double _multinomial(int n, int a, int b) =>
    _factorial(n) / (_factorial(a) * _factorial(b) * _factorial(n - a - b));

double _factorial(int n) {
  var f = 1.0;
  for (var i = 2; i <= n; i++) {
    f *= i;
  }
  return f;
}

double _power(double x, int k) {
  var r = 1.0;
  for (var i = 0; i < k; i++) {
    r *= x;
  }
  return r;
}
