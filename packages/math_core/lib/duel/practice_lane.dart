import 'dart:math';

import '../leveling/level.dart';
import '../tiers/fluent_time.dart';
import '../validation/session_validation.dart' show maxElapsedMs;
import 'duel_config.dart';
import 'duel_run.dart';
import 'duel_validation.dart';

/// A practice opponent (plan v3.7): when the pool has no run to race, a
/// simulated player of the duel's tier — labelled "Practice", no rating
/// change for either side. Its lane is drawn from the config alone, so the
/// server and the app draw the same one (VM and JavaScript; `nextInt`
/// only, rule 18). Provisional (`doc/decisions.md`, "Phase 7"):
/// - a question is right 70 % of the time, answered in 60–140 % of the
///   tier's fluent time (at most 30 s);
/// - a Get the count round is exact half the time, else 1–9 away (never
///   further than the six numbers alone), reached in 8–28 s, halfway there
///   first when the start is far.
DuelLane practiceLane(DuelConfig config) {
  // Its own stream, not the content's: the lane must not echo the draws
  // that made the questions. `seed + 1` rather than a bitwise mix, which
  // JavaScript would cut to 32 bits.
  final random = Random(config.seed + 1);
  if (config.mode.isQuiz) {
    final level = Level.whole(10 * config.difficulty);
    return QuizLane([
      for (final type in config.typeSequence())
        () {
          final correct = random.nextInt(100) < 70;
          final fluent = fluentTimeMs(type, level, config.rulesVersion);
          final ms = fluent * (60 + random.nextInt(81)) ~/ 100;
          return (elapsedMs: min(ms, maxElapsedMs), correct: correct);
        }(),
    ]);
  }
  return CountLane([
    for (final (puzzle, _) in config.rounds())
      () {
        final base = baseCountDistance(puzzle);
        final exact = random.nextInt(2) == 0;
        final missed = 1 + random.nextInt(9);
        final time = 8000 + random.nextInt(20001);
        final distance = exact ? 0 : min(missed, base);
        if (distance >= base) {
          return CountLaneRound(baseDistance: base, improvements: const []);
        }
        final halfway = distance + (base - distance) ~/ 2;
        return CountLaneRound(
          baseDistance: base,
          improvements: [
            if (halfway > distance && halfway < base)
              (atMs: time ~/ 2, distance: halfway),
            (atMs: time, distance: distance),
          ],
        );
      }(),
  ]);
}
