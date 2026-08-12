import 'package:math_trainer/core/domain/leveling/answer_outcome.dart';
import 'package:math_trainer/core/domain/leveling/leveling_rules.dart';
import 'package:math_trainer/core/domain/leveling/level_updater.dart';
import 'package:test/test.dart';

void main() {
  group('LevelUpdater', () {
    test('moins de n_min réponses : le niveau ne bouge pas (échantillon de bruit)', () {
      final updater = LevelUpdater();
      final answers = List.generate(3, (_) => const AnswerOutcome(isCorrect: true, elapsedMs: 0));

      expect(updater.update(currentLevel: 50, answers: answers), 50);
    });

    test('exactement n_min réponses, toutes justes et rapides : le niveau monte (K_haut)', () {
      final updater = LevelUpdater();
      final answers = List.generate(4, (_) => const AnswerOutcome(isCorrect: true, elapsedMs: 0));

      expect(updater.update(currentLevel: 50, answers: answers), 51);
    });

    test('toutes fausses : le niveau descend (K_bas)', () {
      final updater = LevelUpdater();
      final answers = List.generate(
        4,
        (_) => const AnswerOutcome(isCorrect: false, elapsedMs: 0),
      );

      expect(updater.update(currentLevel: 50, answers: answers), 49);
    });

    test('performance proche de la cible : bande morte, le niveau ne bouge pas', () {
      final updater = LevelUpdater();
      final answers = [
        ...List.generate(2, (_) => const AnswerOutcome(isCorrect: true, elapsedMs: 0)),
        ...List.generate(2, (_) => const AnswerOutcome(isCorrect: true, elapsedMs: 8000)),
      ];

      expect(updater.update(currentLevel: 50, answers: answers), 50);
    });

    test('confidenceFactor : calibration fait bouger le niveau davantage que normal', () {
      final updater = LevelUpdater();
      final answers = List.generate(4, (_) => const AnswerOutcome(isCorrect: true, elapsedMs: 0));

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

    test('Δ_max plafonne la variation, même avec un fort multiplicateur de confiance', () {
      final updater = LevelUpdater(rules: LevelingRules(deltaMax: 1));
      final answers = List.generate(4, (_) => const AnswerOutcome(isCorrect: true, elapsedMs: 0));

      // Sans plafond à 1, ce même scénario donnerait 53 (voir test précédent).
      expect(
        updater.update(currentLevel: 50, answers: answers, confidence: ConfidenceMultiplier.calibration),
        51,
      );
    });

    test('le niveau est borné à 100', () {
      final updater = LevelUpdater();
      final answers = List.generate(4, (_) => const AnswerOutcome(isCorrect: true, elapsedMs: 0));

      expect(
        updater.update(currentLevel: 99, answers: answers, confidence: ConfidenceMultiplier.calibration),
        100,
      );
    });

    test('le niveau est borné à 1', () {
      final updater = LevelUpdater();
      final answers = List.generate(
        4,
        (_) => const AnswerOutcome(isCorrect: false, elapsedMs: 0),
      );

      expect(
        updater.update(currentLevel: 2, answers: answers, confidence: ConfidenceMultiplier.calibration),
        1,
      );
    });

    test('des réponses correctes plus rapides ne font jamais moins progresser', () {
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

    test('une réponse fausse ne rapporte jamais de crédit, quel que soit le temps', () {
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

    test('refuse un niveau hors [1, 100]', () {
      final updater = LevelUpdater();
      final answers = List.generate(4, (_) => const AnswerOutcome(isCorrect: true, elapsedMs: 0));

      expect(() => updater.update(currentLevel: 0, answers: answers), throwsArgumentError);
      expect(() => updater.update(currentLevel: 101, answers: answers), throwsArgumentError);
    });

    test('rejouable sur un historique : plier sur des sessions successives monte puis plafonne', () {
      final updater = LevelUpdater();
      final greatSession = List.generate(
        4,
        (_) => const AnswerOutcome(isCorrect: true, elapsedMs: 0),
      );

      // À ces paramètres, une session « parfaite » fait gagner ~1 niveau : il
      // en faut assez pour atteindre le plafond depuis 50 et y rester.
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
    });
  });
}
