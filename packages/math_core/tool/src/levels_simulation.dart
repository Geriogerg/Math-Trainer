import 'dart:math';

import 'package:math_core/leveling/answer_outcome.dart';
import 'package:math_core/leveling/level.dart';
import 'package:math_core/leveling/level_change.dart';
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
  (name: '60 %', accuracy: 0.6, fluent: 1.0),
];

/// Games of [questions] questions one simulated player needs to reach the
/// start of each tier T1…T9 (levels 10, 20 … 90), from level 0, under the
/// real update (`levelAfterGame`, the fluent time of the level's tier).
/// `null`: not reached within [maxGames].
List<int?> gamesToTiers(
  SimulatedPlayer player, {
  required Random random,
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
  int runs = 1001,
  int questions = 10,
  int seed = 2026,
}) {
  final perTier = List.generate(9, (_) => <int>[]);
  final random = Random(seed);
  for (var r = 0; r < runs; r++) {
    final reached = gamesToTiers(player, random: random, questions: questions);
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
