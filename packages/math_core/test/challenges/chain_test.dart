import 'package:math_core/challenges/chain.dart';
import 'package:math_core/challenges/challenge_stats.dart';
import 'package:test/test.dart';

void main() {
  test('thousands of seeds: every value whole, in [1, 999], every division '
      'exact', () {
    for (final operations in chainOperationChoices) {
      for (var seed = 0; seed < 3000; seed++) {
        // The constructor checks exactness and the range on every step.
        final chain = generateChain(seed: seed, operations: operations);
        expect(chain.steps, hasLength(operations));
        expect(chain.start, inInclusiveRange(2, 20));
        final values = chain.values;
        expect(values, hasLength(operations + 1));
        for (final v in values) {
          expect(v, inInclusiveRange(1, chainMaxValue));
        }
        for (final (i, step) in chain.steps.indexed) {
          if (step.operator == ChainOperator.divide) {
            expect(values[i] % step.operand, 0);
          }
          expect(step.operand, inInclusiveRange(1, 9));
        }
      }
    }
  });

  test('every operator appears', () {
    final seen = {
      for (var seed = 0; seed < 200; seed++)
        for (final step in generateChain(seed: seed, operations: 15).steps)
          step.operator,
    };
    expect(seen, ChainOperator.values.toSet());
  });

  test('same seed, same chain; pinned on VM and JavaScript', () {
    final a = generateChain(seed: 42, operations: 5);
    expect(generateChain(seed: 42, operations: 5).steps, a.steps);
    expect(a.start, _pinnedStart);
    expect(a.steps.map((s) => '$s').toList(), _pinnedSteps);
  });

  test('invalid chains and settings throw (rule 13)', () {
    expect(() => generateChain(seed: 1, operations: 7), throwsArgumentError);
    expect(() => Chain(start: 0, steps: const []), throwsArgumentError);
    expect(
      () => Chain(start: 7, steps: const [ChainStep(ChainOperator.divide, 2)]),
      throwsArgumentError,
    );
    expect(
      () =>
          Chain(start: 5, steps: const [ChainStep(ChainOperator.subtract, 5)]),
      throwsArgumentError,
    );
    expect(
      () => Chain(
        start: 500,
        steps: const [ChainStep(ChainOperator.multiply, 2)],
      ),
      throwsArgumentError,
    );
  });

  group('ChallengeStats', () {
    test('counts games and solved rounds, keeps the best time', () {
      final stats = ChallengeStats.none
          .record(solved: true, elapsedMs: 9000)
          .record(solved: false, elapsedMs: 2000)
          .record(solved: true, elapsedMs: 7000)
          .record(solved: true, elapsedMs: 8000);
      expect(
        stats,
        const ChallengeStats(games: 4, solved: 3, bestTimeMs: 7000),
      );
    });

    test('a negative time throws', () {
      expect(
        () => ChallengeStats.none.record(solved: true, elapsedMs: -1),
        throwsArgumentError,
      );
    });
  });
}

// 19 + 1 = 20, − 7 = 13, × 9 = 117, − 8 = 109, − 7 = 102.
const _pinnedStart = 19;
const _pinnedSteps = ['+ 1', '− 7', '× 9', '− 8', '− 7'];
