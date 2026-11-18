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

    test('guaranteed coverage under the cap: each active type appears exactly n_min times', () {
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
          expect(counts[type], 8, reason: '$type should appear exactly 8 times');
        }
      }
    });

    test('beyond the cap, the most played (least indebted) type is left out', () {
      final strategy = DebtAwareTypeSelectionStrategy(
        exerciseCount: 24, // the cap, budget for 3 blocks of 8 over 4 active types
        nMin: 8,
        sessionsPlayedByType: const {
          ExerciseType.addition: 0,
          ExerciseType.subtraction: 0,
          ExerciseType.multiplication: 5,
          ExerciseType.division: 10, // most played: least indebted
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

    test('equal debt broken by .index order', () {
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

      // At equal debt, the first 3 by .index (addition, subtraction,
      // multiplication) come before division.
      expect(counts[ExerciseType.addition], 8);
      expect(counts[ExerciseType.subtraction], 8);
      expect(counts[ExerciseType.multiplication], 8);
      expect(counts.containsKey(ExerciseType.division), isFalse);
    });

    test('a non-zero remainder goes to the next types, not to already full ones', () {
      // 2 types, n_min=8, budget=20: 2 full blocks (16) then 4 remaining.
      // With only 2 types, everyone already has a full block: the remainder
      // must then be spread as a bonus (fallback pool), not stay stuck.
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

    test('the remainder goes to a 3rd type without a full block', () {
      // 3 types, n_min=8, budget=17: 2 full blocks (16) then 1 remaining.
      // The 3rd type (the most indebted left) must get it, not one of the 2
      // already full.
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

    test('interleaving: no type monopolises the start or the end of the sequence', () {
      final strategy = DebtAwareTypeSelectionStrategy(
        exerciseCount: 16,
        nMin: 8,
        sessionsPlayedByType: const {},
      );
      final sequence = strategy.sequenceFor(sortedTypes(2));

      // Strict round-robin over 2 types with equal quotas: perfect alternation.
      expect(sequence.first, ExerciseType.addition);
      expect(sequence[1], ExerciseType.subtraction);
      expect(sequence.last, ExerciseType.subtraction);
    });

    test('the same debt and budget always produce the same sequence (determinism)', () {
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

    test('rotation over several simulated sessions: all 4 types end up covered', () {
      final sessionsPlayed = <ExerciseType, int>{};
      final coveredAtLeastOnce = <ExerciseType>{};

      for (var session = 0; session < 4; session++) {
        final strategy = DebtAwareTypeSelectionStrategy(
          exerciseCount: 24,
          nMin: 8,
          sessionsPlayedByType: Map.of(sessionsPlayed),
        );
        final counts = countByType(strategy.sequenceFor(sortedFourTypes));

        // Simulates _computeLevelUpdates: only types that received a full
        // block get their sessionsPlayed incremented.
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
