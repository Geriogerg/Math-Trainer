import 'package:math_trainer/core/domain/leveling/answer_outcome.dart';
import 'package:math_trainer/core/domain/leveling/leveling_rules.dart';
import 'package:math_trainer/core/domain/leveling/level_updater.dart';
import 'package:test/test.dart';

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

        expect(updater.update(currentLevel: 50, answers: answers), 50);
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

        expect(updater.update(currentLevel: 50, answers: answers), 51);
      },
    );

    test('all wrong: the level falls (K_bas)', () {
      final updater = LevelUpdater();
      final answers = List.generate(
        4,
        (_) => const AnswerOutcome(isCorrect: false, elapsedMs: 0),
      );

      expect(updater.update(currentLevel: 50, answers: answers), 49);
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

        expect(updater.update(currentLevel: 50, answers: answers), 50);
      },
    );

    test('confidenceFactor: calibration moves the level more than normal', () {
      final updater = LevelUpdater();
      final answers = List.generate(
        4,
        (_) => const AnswerOutcome(isCorrect: true, elapsedMs: 0),
      );

      final normal = updater.update(currentLevel: 50, answers: answers);
      final calibration = updater.update(
        currentLevel: 50,
        answers: answers,
        confidence: ConfidenceMultiplier.calibration,
      );

      expect(normal, 51);
      expect(calibration, 53);
      expect(calibration - 50, greaterThan(normal - 50));
    });

    test('Δ_max caps the change, even with a strong confidence multiplier', () {
      final updater = LevelUpdater(rules: LevelingRules(deltaMax: 1));
      final answers = List.generate(
        4,
        (_) => const AnswerOutcome(isCorrect: true, elapsedMs: 0),
      );

      // Without a cap at 1, this same scenario would give 53 (see previous test).
      expect(
        updater.update(
          currentLevel: 50,
          answers: answers,
          confidence: ConfidenceMultiplier.calibration,
        ),
        51,
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
          currentLevel: 99,
          answers: answers,
          confidence: ConfidenceMultiplier.calibration,
        ),
        100,
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
          currentLevel: 2,
          answers: answers,
          confidence: ConfidenceMultiplier.calibration,
        ),
        1,
      );
    });

    test('faster right answers never progress less', () {
      final updater = LevelUpdater();

      int levelFor(int elapsedMs) {
        final answers = List.generate(
          4,
          (_) => AnswerOutcome(isCorrect: true, elapsedMs: elapsedMs),
        );
        return updater.update(currentLevel: 50, answers: answers);
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
        updater.update(currentLevel: 50, answers: fastWrong),
        updater.update(currentLevel: 50, answers: slowWrong),
      );
    });

    test('rejects a level outside [1, 100]', () {
      final updater = LevelUpdater();
      final answers = List.generate(
        4,
        (_) => const AnswerOutcome(isCorrect: true, elapsedMs: 0),
      );

      expect(
        () => updater.update(currentLevel: 0, answers: answers),
        throwsArgumentError,
      );
      expect(
        () => updater.update(currentLevel: 101, answers: answers),
        throwsArgumentError,
      );
    });

    test(
      'replayable over a history: folding over successive sessions rises then caps',
      () {
        final updater = LevelUpdater();
        final greatSession = List.generate(
          4,
          (_) => const AnswerOutcome(isCorrect: true, elapsedMs: 0),
        );

        // With these parameters, a "perfect" session gains ~1 level: enough
        // of them are needed to reach the cap from 50 and stay there.
        var level = 50;
        final levels = <int>[];
        for (var i = 0; i < 60; i++) {
          level = updater.update(currentLevel: level, answers: greatSession);
          levels.add(level);
        }

        for (var i = 1; i < levels.length; i++) {
          expect(levels[i], greaterThanOrEqualTo(levels[i - 1]));
        }
        expect(levels.last, 100);
      },
    );
  });
}
