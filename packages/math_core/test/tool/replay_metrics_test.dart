import 'package:math_core/leveling/answer_outcome.dart';
import 'package:math_core/leveling/leveling_rules.dart';
import 'package:test/test.dart';

import '../../tool/src/replay_metrics.dart';

void main() {
  group('mean', () {
    test('empty list: null', () {
      expect(mean([]), isNull);
    });

    test('plain mean', () {
      expect(mean([1, 2, 3]), 2.0);
    });
  });

  group('convergenceIndex', () {
    test('flat trajectory: immediate convergence', () {
      expect(convergenceIndex([50, 50, 50, 50, 50]), 0);
    });

    test('never converges if no window drops below the target', () {
      // Amplitude > 2 in any window of 5: constant rise.
      final levels = List.generate(20, (i) => i * 5);
      expect(convergenceIndex(levels), isNull);
    });

    test(
      'a single late deviation no longer prevents detection (bounded window)',
      () {
        // 19 stable values at 50, then an isolated deviation at the very end.
        final levels = [...List.generate(19, (_) => 50), 90];

        // With the old definition (amplitude over the whole rest of the
        // trajectory), no index would have converged: the final deviation
        // shows in the tail of every index tested. With the bounded window
        // (5), convergence is detected from index 0: its first 5 values (all
        // 50) do not include the final deviation.
        expect(convergenceIndex(levels), 0);
      },
    );

    test('detects the stable window even after an unstable phase', () {
      final levels = [10, 90, 10, 90, 50, 51, 50, 51, 50, 51];
      // The first 5 values oscillate well beyond the target; the window
      // [50,51,50,51,50] (index 4) is the first under the target.
      expect(convergenceIndex(levels), 4);
    });

    test('a window of length 1 at the end of a trajectory is never taken for a '
        'convergence', () {
      // Unstable to the end; the very last window holds a single element
      // (index 4, one element left) — an amplitude of 0 by construction that
      // must not pass for a convergence.
      expect(convergenceIndex([10, 90, 10, 90, 30]), isNull);
    });
  });

  group('replay', () {
    test('8 right and instant answers, starting level always 1 (cold replay, '
        "not a real session's frozen level)", () {
      final trajectory = [
        List.generate(
          8,
          (_) => const AnswerOutcome(isCorrect: true, elapsedMs: 0),
        ),
      ];

      final levels = replay(
        trajectory,
        LevelingRules(),
        DateTime.utc(2026, 1, 1),
      );

      // From 1, calibration confidence (never played): deadbandRemoved=0.23,
      // k=kHaut=3.0, confidenceFactor=kCalib=4.0, volume weighting √(8/4) —
      // well beyond deltaMax, clamped to 3.0 → 1 + 3 = 4.
      expect(levels, [4]);
    });

    test('replays several sessions in order, each level feeding the next', () {
      final trajectory = [
        List.generate(
          8,
          (_) => const AnswerOutcome(isCorrect: true, elapsedMs: 0),
        ),
        List.generate(
          8,
          (_) => const AnswerOutcome(isCorrect: true, elapsedMs: 0),
        ),
      ];

      final levels = replay(
        trajectory,
        LevelingRules(),
        DateTime.utc(2026, 1, 1),
      );

      // Session 1: level 1 → calibration confidence (never played); bounded
      // by deltaMax (3) both ways, so 1 + 3 = 4.
      // Session 2: sessionsPlayed=1 < 3, still calibration; 4 + 3 = 7.
      expect(levels, [4, 7]);
    });
  });

  group('averageMetrics', () {
    test('averages convergence/oscillation/bias over several trajectories', () {
      // Two trajectories of 2 sessions each, all wrong: starting level 1,
      // stuck at 1 (lower bound) from the first session — the window [1, 1]
      // converges at index 0 for both trajectories.
      final allFalseSession = List.generate(
        8,
        (_) => const AnswerOutcome(isCorrect: false, elapsedMs: 0),
      );
      final trajectories = [
        [allFalseSession, allFalseSession],
        [allFalseSession, allFalseSession],
      ];

      final metrics = averageMetrics(
        trajectories,
        LevelingRules(),
        DateTime.utc(2026, 1, 1),
      );

      expect(metrics.convergence, 0.0);
      expect(metrics.oscillation, 0.0);
      expect(metrics.bias, 0.0);
    });

    test('a trajectory too short to converge is not counted', () {
      // A single session can never "converge" in the window sense (at least
      // 2 values needed): excluded from the computation, no crash.
      final trajectories = [
        [
          List.generate(
            8,
            (_) => const AnswerOutcome(isCorrect: true, elapsedMs: 0),
          ),
        ],
      ];

      final metrics = averageMetrics(
        trajectories,
        LevelingRules(),
        DateTime.utc(2026, 1, 1),
      );

      expect(metrics.convergence, isNull);
      expect(metrics.oscillation, isNull);
      expect(metrics.bias, isNull);
    });
  });
}
