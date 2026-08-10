import 'package:math_trainer/core/domain/generation/debt_aware_type_selection_strategy.dart';
import 'package:math_trainer/core/domain/models/exercise_type.dart';
import 'package:test/test.dart';

void main() {
  group('DebtAwareTypeSelectionStrategy', () {
    final sortedFourTypes = [
      ExerciseType.addition,
      ExerciseType.subtraction,
      ExerciseType.multiplication,
      ExerciseType.division,
    ];

    List<ExerciseType> sortedTypes(int count) => sortedFourTypes.take(count).toList();

    Map<ExerciseType, int> countByType(List<ExerciseType> sequence) {
      final counts = <ExerciseType, int>{};
      for (final type in sequence) {
        counts[type] = (counts[type] ?? 0) + 1;
      }
      return counts;
    }

    test('couverture garantie sous le plafond : chaque type actif apparaît exactement n_min fois', () {
      for (final k in [1, 2, 3]) {
        final strategy = DebtAwareTypeSelectionStrategy(
          exerciseCount: 8 * k,
          nMin: 8,
          sessionsPlayedByType: const {},
        );
        final sequence = strategy.sequenceFor(sortedTypes(k));

        expect(sequence, hasLength(8 * k));
        final counts = countByType(sequence);
        for (final type in sortedTypes(k)) {
          expect(counts[type], 8, reason: '$type devrait apparaître exactement 8 fois');
        }
      }
    });

    test('au-delà du plafond, le type le plus joué (le moins endetté) est exclu', () {
      final strategy = DebtAwareTypeSelectionStrategy(
        exerciseCount: 24, // plafond, budget pour 3 blocs de 8 sur 4 types actifs
        nMin: 8,
        sessionsPlayedByType: const {
          ExerciseType.addition: 0,
          ExerciseType.subtraction: 0,
          ExerciseType.multiplication: 5,
          ExerciseType.division: 10, // le plus joué : le moins endetté
        },
      );
      final sequence = strategy.sequenceFor(sortedFourTypes);
      final counts = countByType(sequence);

      expect(sequence, hasLength(24));
      expect(counts[ExerciseType.addition], 8);
      expect(counts[ExerciseType.subtraction], 8);
      expect(counts[ExerciseType.multiplication], 8);
      expect(counts.containsKey(ExerciseType.division), isFalse);
    });

    test('égalité de dette tranchée par ordre .index', () {
      final strategy = DebtAwareTypeSelectionStrategy(
        exerciseCount: 24,
        nMin: 8,
        sessionsPlayedByType: const {
          ExerciseType.addition: 0,
          ExerciseType.subtraction: 0,
          ExerciseType.multiplication: 0,
          ExerciseType.division: 0,
        },
      );
      final counts = countByType(strategy.sequenceFor(sortedFourTypes));

      // À dette égale, les 3 premiers par .index (addition, subtraction,
      // multiplication) passent avant division.
      expect(counts[ExerciseType.addition], 8);
      expect(counts[ExerciseType.subtraction], 8);
      expect(counts[ExerciseType.multiplication], 8);
      expect(counts.containsKey(ExerciseType.division), isFalse);
    });

    test('reste non nul réparti aux types suivants, pas aux types déjà pleins', () {
      // 2 types, n_min=8, budget=20 : 2 blocs complets (16) puis 4 de reste.
      // Avec 2 types seulement, tout le monde a déjà un bloc complet : le
      // reste doit alors se répartir en bonus (pool de secours), pas rester
      // bloqué.
      final strategy = DebtAwareTypeSelectionStrategy(
        exerciseCount: 20,
        nMin: 8,
        sessionsPlayedByType: const {},
      );
      final sequence = strategy.sequenceFor(sortedTypes(2));
      final counts = countByType(sequence);

      expect(sequence, hasLength(20));
      expect(counts.values.reduce((a, b) => a + b), 20);
      expect(counts[ExerciseType.addition]! >= 8, isTrue);
      expect(counts[ExerciseType.subtraction]! >= 8, isTrue);
    });

    test('reste réparti à un 3e type qui n\'a pas de bloc complet', () {
      // 3 types, n_min=8, budget=17 : 2 blocs complets (16) puis 1 de
      // reste. Le 3e type (le plus endetté restant) doit recevoir ce
      // dernier, pas un des 2 déjà pleins.
      final strategy = DebtAwareTypeSelectionStrategy(
        exerciseCount: 17,
        nMin: 8,
        sessionsPlayedByType: const {},
      );
      final counts = countByType(strategy.sequenceFor(sortedTypes(3)));

      expect(counts[ExerciseType.addition], 8);
      expect(counts[ExerciseType.subtraction], 8);
      expect(counts[ExerciseType.multiplication], 1);
    });

    test('entrelacement : un type ne monopolise ni le début ni la fin de la séquence', () {
      final strategy = DebtAwareTypeSelectionStrategy(
        exerciseCount: 16,
        nMin: 8,
        sessionsPlayedByType: const {},
      );
      final sequence = strategy.sequenceFor(sortedTypes(2));

      // Round-robin strict sur 2 types à quota égal : alternance parfaite.
      expect(sequence.first, ExerciseType.addition);
      expect(sequence[1], ExerciseType.subtraction);
      expect(sequence.last, ExerciseType.subtraction);
    });

    test('même dette et même budget produisent toujours la même séquence (déterminisme)', () {
      final debt = {ExerciseType.addition: 2, ExerciseType.subtraction: 0};
      final strategyA = DebtAwareTypeSelectionStrategy(
        exerciseCount: 16,
        nMin: 8,
        sessionsPlayedByType: debt,
      );
      final strategyB = DebtAwareTypeSelectionStrategy(
        exerciseCount: 16,
        nMin: 8,
        sessionsPlayedByType: debt,
      );

      expect(strategyA.sequenceFor(sortedTypes(2)), equals(strategyB.sequenceFor(sortedTypes(2))));
    });

    test('rotation sur plusieurs sessions simulées : les 4 types finissent tous couverts', () {
      final sessionsPlayed = <ExerciseType, int>{};
      final coveredAtLeastOnce = <ExerciseType>{};

      for (var session = 0; session < 4; session++) {
        final strategy = DebtAwareTypeSelectionStrategy(
          exerciseCount: 24,
          nMin: 8,
          sessionsPlayedByType: Map.of(sessionsPlayed),
        );
        final counts = countByType(strategy.sequenceFor(sortedFourTypes));

        // Simule _computeLevelUpdates : seuls les types ayant reçu un bloc
        // complet voient leur sessionsPlayed incrémenté.
        for (final entry in counts.entries) {
          if (entry.value >= 8) {
            sessionsPlayed[entry.key] = (sessionsPlayed[entry.key] ?? 0) + 1;
            coveredAtLeastOnce.add(entry.key);
          }
        }
      }

      expect(coveredAtLeastOnce, equals(sortedFourTypes.toSet()));
    });
  });
}
