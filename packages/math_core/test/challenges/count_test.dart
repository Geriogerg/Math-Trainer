import 'package:math_core/challenges/count.dart';
import 'package:test/test.dart';

/// Replays [steps] from [numbers] under the rules: every step uses values
/// still available, every result is valid; returns the last result.
int _replay(List<int> numbers, List<CountStep> steps) {
  final pool = [...numbers];
  for (final step in steps) {
    expect(pool.remove(step.left), isTrue, reason: '$step: ${step.left}');
    expect(pool.remove(step.right), isTrue, reason: '$step: ${step.right}');
    expect(step.operator.apply(step.left, step.right), step.result);
    pool.add(step.result);
  }
  return steps.last.result;
}

void _checkSeed(int seed) {
  final (puzzle, solution) = generateCountPuzzleWithSolution(seed);
  final bigs = puzzle.numbers.where(countBigNumbers.contains).length;
  expect(bigs, inInclusiveRange(1, 3));
  expect(puzzle.target, inInclusiveRange(101, 999));
  expect(solution.length, inInclusiveRange(1, 5));
  expect(_replay(puzzle.numbers, solution), puzzle.target);
}

void main() {
  test(
    'thousands of seeds: every target in range, solvable, the solution '
    'valid under the rules',
    () {
      for (var seed = 0; seed < 2000; seed++) {
        _checkSeed(seed);
      }
    },
    // The full sweep on the VM (a few seconds); JavaScript runs the pinned
    // and smaller checks below — the same code, the same integers.
    testOn: 'vm',
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test('a sample of seeds, VM and JavaScript alike', () {
    for (var seed = 5000; seed < 5040; seed++) {
      _checkSeed(seed);
    }
  });

  test('pinned on VM and JavaScript', () {
    final (puzzle, solution) = generateCountPuzzleWithSolution(1);
    expect(puzzle.numbers, [100, 9, 6, 2, 8, 2]);
    expect(puzzle.target, 817);
    expect(solution.map((s) => '$s'), [
      '100 × 8 = 800',
      '800 + 2 = 802',
      '802 + 6 = 808',
      '808 + 9 = 817',
    ]);
  });

  test('the solver finds the fewest operations', () {
    expect(solveCount([25, 4, 1, 1, 2, 3], 100)!.map((s) => '$s'), [
      '25 × 4 = 100',
    ]);
    // Unreachable: two smalls cannot make 999.
    expect(solveCount([1, 2], 999), isNull);
  });

  group('rules', () {
    test('whole, positive, exact division only', () {
      expect(CountOperator.subtract.apply(3, 5), isNull);
      expect(CountOperator.subtract.apply(5, 5), isNull);
      expect(CountOperator.divide.apply(7, 2), isNull);
      expect(CountOperator.divide.apply(8, 2), 4);
      expect(CountOperator.multiply.apply(25, 4), 100);
    });

    test('invalid puzzles throw (rule 13)', () {
      expect(
        () => CountPuzzle(numbers: [1, 2, 3, 4, 5, 6], target: 200),
        throwsArgumentError,
      ); // no big
      expect(
        () => CountPuzzle(numbers: [25, 25, 1, 2, 3, 4], target: 200),
        throwsArgumentError,
      ); // a big twice
      expect(
        () => CountPuzzle(numbers: [25, 3, 3, 3, 1, 2], target: 200),
        throwsArgumentError,
      ); // a small three times
      expect(
        () => CountPuzzle(numbers: [25, 1, 2, 3, 4, 5], target: 100),
        throwsArgumentError,
      ); // target out of range
    });
  });

  group('CountBoard', () {
    final puzzle = CountPuzzle(numbers: [75, 6, 3, 8, 100, 2], target: 637);

    test('a result takes the second tile\'s place; the first fades', () {
      final board = CountBoard.start(
        puzzle,
      ).combine(0, CountOperator.multiply, 3)!;
      expect(board.tiles[0].used, isTrue);
      expect(board.tiles[3].value, 600);
      expect(board.tiles[3].used, isFalse);
      expect(board.solved, isFalse);
    });

    test('forbidden moves give null: a used tile, the same tile, a bad '
        'result', () {
      final start = CountBoard.start(puzzle);
      final once = start.combine(0, CountOperator.multiply, 3)!;
      expect(once.combine(0, CountOperator.add, 1), isNull); // 75 is used
      expect(start.combine(1, CountOperator.add, 1), isNull);
      expect(start.combine(2, CountOperator.subtract, 1), isNull); // 3 − 6
      expect(start.combine(1, CountOperator.divide, 3), isNull); // 6 ÷ 8
    });

    test('solved when a tile equals the target; undo and reset', () {
      final easy = CountPuzzle(numbers: [100, 6, 3, 8, 75, 2], target: 106);
      var board = CountBoard.start(easy);
      board = board.combine(0, CountOperator.add, 1)!; // 100 + 6, id 6
      expect(board.solved, isTrue);
      expect(board.closest, 106);
      final undone = board.undo();
      expect(undone.solved, isFalse);
      expect(undone.canUndo, isFalse);
      // Two moves, then reset: every tile back, none used.
      final two = undone
          .combine(0, CountOperator.add, 2)! // 100 + 3 = 103, id 6
          .combine(3, CountOperator.add, 6)!; // 8 + 103 = 111, id 7
      expect(two.tiles.where((t) => t.used), hasLength(2));
      expect(two.reset().tiles.every((t) => !t.used), isTrue);
    });

    test('the closest value ever on the board', () {
      var board = CountBoard.start(puzzle);
      board = board.combine(0, CountOperator.multiply, 3)!; // 600
      board = board.undo();
      // 600 was seen before the undo but is no longer on this board's
      // history: the closest is among this board's values.
      expect(board.closest, 100);
      board = board.combine(0, CountOperator.multiply, 3)!;
      expect(board.closest, 600);
    });

    test('each tile carries the operations that made it (Phase 7)', () {
      var board = CountBoard.start(puzzle); // 75 6 3 8 100 2 → 637
      expect(board.tiles.every((t) => t.steps.isEmpty), isTrue);
      board = board.combine(2, CountOperator.multiply, 3)!; // 3 × 8 = 24
      final made24 = board.tiles.firstWhere((t) => t.value == 24);
      board = board.combine(made24.id, CountOperator.add, 0)!; // 24 + 75
      final made99 = board.tiles.firstWhere((t) => t.value == 99);
      expect(made99.steps, const [
        CountStep(3, CountOperator.multiply, 8, 24),
        CountStep(24, CountOperator.add, 75, 99),
      ]);
      // The used tile keeps its own steps; undo restores the earlier ones.
      expect(board.undo().tiles.any((t) => t.value == 99), isFalse);
      expect(
        board.undo().tiles.firstWhere((t) => t.value == 24).steps.length,
        1,
      );
    });
  });
}
