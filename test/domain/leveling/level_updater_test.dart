import 'package:math_trainer/core/domain/leveling/answer_outcome.dart';
import 'package:math_trainer/core/domain/leveling/level.dart';
import 'package:math_trainer/core/domain/leveling/leveling_rules.dart';
import 'package:math_trainer/core/domain/leveling/level_updater.dart';
import 'package:test/test.dart';

/// Levels in hundredths (`Level`): 5069 is 50.69.
Level h(int hundredths) => Level.fromHundredths(hundredths);
final fifty = Level.whole(50);

void main() {
  group('LevelUpdater', () {
    test(
      'fewer than n_min answers: the level does not move (noise sample)',
      () {
        final updater = LevelUpdater();
        final answers = List.generate(
          3,
          (_) => const AnswerOutcome(isCorrect: true, elapsedMs: 0),
        );

        expect(updater.update(currentLevel: fifty, answers: answers), fifty);
      },
    );

    test(
      'exactly n_min answers, all right and fast: the level rises (K_haut)',
      () {
        final updater = LevelUpdater();
        final answers = List.generate(
          4,
          (_) => const AnswerOutcome(isCorrect: true, elapsedMs: 0),
        );

        // (1.0 − 0.70 − δ 0.07) × K_haut 3 = +0.69.
        expect(updater.update(currentLevel: fifty, answers: answers), h(5069));
      },
    );

    test('all wrong: the level falls (K_bas)', () {
      final updater = LevelUpdater();
      final answers = List.generate(
        4,
        (_) => const AnswerOutcome(isCorrect: false, elapsedMs: 0),
      );

      // (0 − 0.70 + δ 0.07) × K_bas 1.5 ≈ −0.945, rounded once: −0.94 (the
      // floating-point −0.6299… × 1.5 lands just under the half).
      expect(updater.update(currentLevel: fifty, answers: answers), h(4906));
    });

    test(
      'performance close to the target: dead band, the level does not move',
      () {
        final updater = LevelUpdater();
        final answers = [
          ...List.generate(
            2,
            (_) => const AnswerOutcome(isCorrect: true, elapsedMs: 0),
          ),
          ...List.generate(
            2,
            (_) => const AnswerOutcome(isCorrect: true, elapsedMs: 8000),
          ),
        ];

        expect(updater.update(currentLevel: fifty, answers: answers), fifty);
      },
    );

    test('confidenceFactor: calibration moves the level more than normal', () {
      final updater = LevelUpdater();
      final answers = List.generate(
        4,
        (_) => const AnswerOutcome(isCorrect: true, elapsedMs: 0),
      );

      final normal = updater.update(currentLevel: fifty, answers: answers);
      final calibration = updater.update(
        currentLevel: fifty,
        answers: answers,
        confidence: ConfidenceMultiplier.calibration,
      );

      expect(normal, h(5069));
      expect(calibration, h(5276)); // 0.69 × K_calib 4
      expect(calibration.hundredths, greaterThan(normal.hundredths));
    });

    test('Δ_max caps the change, even with a strong confidence multiplier', () {
      final updater = LevelUpdater(rules: LevelingRules(deltaMax: 1));
      final answers = List.generate(
        4,
        (_) => const AnswerOutcome(isCorrect: true, elapsedMs: 0),
      );

      // Without a cap at 1, this same scenario would give 52.76 (previous
      // test).
      expect(
        updater.update(
          currentLevel: fifty,
          answers: answers,
          confidence: ConfidenceMultiplier.calibration,
        ),
        h(5100),
      );
    });

    test('the level is capped at 100', () {
      final updater = LevelUpdater();
      final answers = List.generate(
        4,
        (_) => const AnswerOutcome(isCorrect: true, elapsedMs: 0),
      );

      expect(
        updater.update(
          currentLevel: Level.whole(99),
          answers: answers,
          confidence: ConfidenceMultiplier.calibration,
        ),
        h(10000),
      );
    });

    test('the level is floored at 1', () {
      final updater = LevelUpdater();
      final answers = List.generate(
        4,
        (_) => const AnswerOutcome(isCorrect: false, elapsedMs: 0),
      );

      expect(
        updater.update(
          currentLevel: Level.whole(2),
          answers: answers,
          confidence: ConfidenceMultiplier.calibration,
        ),
        Level.floor,
      );
    });

    test('faster right answers never progress less', () {
      final updater = LevelUpdater();

      int levelFor(int elapsedMs) {
        final answers = List.generate(
          4,
          (_) => AnswerOutcome(isCorrect: true, elapsedMs: elapsedMs),
        );
        return updater.update(currentLevel: fifty, answers: answers).hundredths;
      }

      final fast = levelFor(2000);
      final mid = levelFor(5000);
      final slow = levelFor(8000);

      expect(fast, greaterThanOrEqualTo(mid));
      expect(mid, greaterThanOrEqualTo(slow));
    });

    test('a wrong answer never earns credit, whatever the time', () {
      final updater = LevelUpdater();
      final fastWrong = List.generate(
        4,
        (_) => const AnswerOutcome(isCorrect: false, elapsedMs: 0),
      );
      final slowWrong = List.generate(
        4,
        (_) => const AnswerOutcome(isCorrect: false, elapsedMs: 100000),
      );

      expect(
        updater.update(currentLevel: fifty, answers: fastWrong),
        updater.update(currentLevel: fifty, answers: slowWrong),
      );
    });

    test(
      'a step under one level still counts (no rounding to whole levels)',
      () {
        // Before continuous levels, +0.49 rounded to 0: the level never moved.
        final updater = LevelUpdater();
        final answers = [
          for (var i = 0; i < 4; i++)
            AnswerOutcome(isCorrect: true, elapsedMs: i < 3 ? 0 : 6000),
        ];
        final next = updater.update(currentLevel: fifty, answers: answers);
        expect(next.hundredths, greaterThan(5000));
        expect(next.whole, 50);
      },
    );

    test(
      'replayable over a history: folding over successive sessions rises then caps',
      () {
        final updater = LevelUpdater();
        final greatSession = List.generate(
          4,
          (_) => const AnswerOutcome(isCorrect: true, elapsedMs: 0),
        );

        // A "perfect" session gains 0.69 outside calibration: 73 of them
        // reach the cap from 50; 80 reach it and stay there.
        var level = fifty;
        final levels = <int>[];
        for (var i = 0; i < 80; i++) {
          level = updater.update(currentLevel: level, answers: greatSession);
          levels.add(level.hundredths);
        }

        for (var i = 1; i < levels.length; i++) {
          expect(levels[i], greaterThanOrEqualTo(levels[i - 1]));
        }
        expect(levels.last, 10000);
      },
    );
  });
}
