import 'package:math_trainer/core/domain/leveling/answer_outcome.dart';
import 'package:math_trainer/core/domain/leveling/leveling_rules.dart';
import 'package:test/test.dart';

import '../../tool/src/replay_metrics.dart';

void main() {
  group('mean', () {
    test('liste vide : null', () {
      expect(mean([]), isNull);
    });

    test('moyenne simple', () {
      expect(mean([1, 2, 3]), 2.0);
    });
  });

  group('convergenceIndex', () {
    test('trajectoire plate : convergence immédiate', () {
      expect(convergenceIndex([50, 50, 50, 50, 50]), 0);
    });

    test('ne converge jamais si aucune fenêtre ne descend sous la cible', () {
      // Amplitude > 2 dans n'importe quelle fenêtre de 5 : montée constante.
      final levels = List.generate(20, (i) => i * 5);
      expect(convergenceIndex(levels), isNull);
    });

    test('un seul écart tardif n\'empêche plus la détection (fenêtre bornée)', () {
      // 19 valeurs stables à 50, puis un écart isolé à la toute fin.
      final levels = [...List.generate(19, (_) => 50), 90];

      // Avec l'ancienne définition (amplitude sur tout le reste de la
      // trajectoire), aucun indice n'aurait convergé : l'écart final
      // apparaît dans la queue de chaque indice testé. Avec la fenêtre
      // bornée (5), la convergence est détectée dès l'indice 0 : ses 5
      // premières valeurs (toutes 50) n'incluent pas l'écart final.
      expect(convergenceIndex(levels), 0);
    });

    test('détecte la fenêtre stable même après une phase instable', () {
      final levels = [10, 90, 10, 90, 50, 51, 50, 51, 50, 51];
      // Les 5 premières valeurs oscillent bien au-delà de la cible ; la
      // fenêtre [50,51,50,51,50] (indice 4) est la première sous la cible.
      expect(convergenceIndex(levels), 4);
    });

    test('une fenêtre de longueur 1 en fin de trajectoire n\'est jamais prise pour une '
        'convergence', () {
      // Instable jusqu'au bout ; la toute dernière fenêtre ne contient
      // qu'un seul élément (indice 4, un seul élément restant) — une
      // amplitude de 0 par construction qu'il ne faut pas laisser passer
      // pour une convergence.
      expect(convergenceIndex([10, 90, 10, 90, 30]), isNull);
    });
  });

  group('replay', () {
    test('8 réponses justes et instantanées, niveau de départ toujours 1 (rejeu à froid, '
        'pas le niveau figé d\'une vraie session)', () {
      final trajectory = [
        List.generate(8, (_) => const AnswerOutcome(isCorrect: true, elapsedMs: 0)),
      ];

      final levels = replay(trajectory, LevelingRules(), DateTime.utc(2026, 1, 1));

      // Depuis 1, confiance calibration (jamais joué) : deadbandRemoved=0.23,
      // k=kHaut=3.0, confidenceFactor=kCalib=4.0, pondération volume √(8/4) —
      // largement au-delà de deltaMax, clampé à 3.0 → 1 + 3 = 4.
      expect(levels, [4]);
    });

    test('rejoue plusieurs sessions dans l\'ordre, chaque niveau nourrit la suivante', () {
      final trajectory = [
        List.generate(8, (_) => const AnswerOutcome(isCorrect: true, elapsedMs: 0)),
        List.generate(8, (_) => const AnswerOutcome(isCorrect: true, elapsedMs: 0)),
      ];

      final levels = replay(trajectory, LevelingRules(), DateTime.utc(2026, 1, 1));

      // Session 1 : niveau 1 → confiance calibration (jamais joué) ; borné
      // par deltaMax (3) dans les deux sens du calcul, donc 1 + 3 = 4.
      // Session 2 : sessionsPlayed=1 < 3, encore calibration ; 4 + 3 = 7.
      expect(levels, [4, 7]);
    });
  });

  group('averageMetrics', () {
    test('moyenne convergence/oscillation/biais sur plusieurs trajectoires', () {
      // Deux trajectoires de 2 sessions chacune, toutes fausses : niveau de
      // départ 1, reste bloqué à 1 (borné bas) dès la première session — la
      // fenêtre [1, 1] converge à l'indice 0 pour les deux trajectoires.
      final allFalseSession = List.generate(
        8,
        (_) => const AnswerOutcome(isCorrect: false, elapsedMs: 0),
      );
      final trajectories = [
        [allFalseSession, allFalseSession],
        [allFalseSession, allFalseSession],
      ];

      final metrics = averageMetrics(trajectories, LevelingRules(), DateTime.utc(2026, 1, 1));

      expect(metrics.convergence, 0.0);
      expect(metrics.oscillation, 0.0);
      expect(metrics.bias, 0.0);
    });

    test('une trajectoire trop courte pour converger n\'est pas comptée', () {
      // Une seule session ne peut jamais "converger" au sens de la fenêtre
      // (il faut au moins 2 valeurs) : exclue du calcul, pas de crash.
      final trajectories = [
        [List.generate(8, (_) => const AnswerOutcome(isCorrect: true, elapsedMs: 0))],
      ];

      final metrics = averageMetrics(trajectories, LevelingRules(), DateTime.utc(2026, 1, 1));

      expect(metrics.convergence, isNull);
      expect(metrics.oscillation, isNull);
      expect(metrics.bias, isNull);
    });
  });
}
