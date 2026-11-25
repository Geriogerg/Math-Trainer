import 'dart:math';

/// Get the count (Redesign phase commit 8): six numbers, a target, the four
/// operations. Solo for now, seeded and pure so Phase 7 can replay it on a
/// server.

const countBigNumbers = [25, 50, 75, 100];
const countTargetMin = 101;
const countTargetMax = 999;
const countRoundSeconds = 45;

enum CountOperator {
  add('+'),
  subtract('−'),
  multiply('×'),
  divide('÷');

  const CountOperator(this.symbol);

  final String symbol;

  /// `a op b` under the rules — whole, positive, division only when exact —
  /// or `null` when the rules forbid it. 0 is refused too: it is never
  /// useful and would allow a division by zero.
  int? apply(int a, int b) {
    final result = switch (this) {
      CountOperator.add => a + b,
      CountOperator.subtract => a - b,
      CountOperator.multiply => a * b,
      CountOperator.divide => b != 0 && a % b == 0 ? a ~/ b : null,
    };
    return result != null && result > 0 ? result : null;
  }
}

/// One operation of a solution: `left op right = result`.
final class CountStep {
  const CountStep(this.left, this.operator, this.right, this.result);

  final int left;
  final CountOperator operator;
  final int right;
  final int result;

  @override
  bool operator ==(Object other) =>
      other is CountStep &&
      other.left == left &&
      other.operator == operator &&
      other.right == right &&
      other.result == result;

  @override
  int get hashCode => Object.hash(left, operator, right, result);

  @override
  String toString() => '$left ${operator.symbol} $right = $result';
}

final class CountPuzzle {
  CountPuzzle({required List<int> numbers, required this.target})
    : numbers = List.unmodifiable(numbers) {
    if (numbers.length != 6) {
      throw ArgumentError.value(numbers, 'numbers', 'must be six numbers.');
    }
    final bigs = numbers.where(countBigNumbers.contains).toList();
    final smalls = numbers.where((n) => !countBigNumbers.contains(n)).toList();
    if (bigs.isEmpty || bigs.length > 3 || bigs.toSet().length != bigs.length) {
      throw ArgumentError.value(numbers, 'numbers', '1 to 3 distinct bigs.');
    }
    for (final s in smalls) {
      if (s < 1 || s > 9 || smalls.where((x) => x == s).length > 2) {
        throw ArgumentError.value(numbers, 'numbers', 'smalls 1–9, twice max.');
      }
    }
    if (target < countTargetMin || target > countTargetMax) {
      throw ArgumentError.value(target, 'target', 'must be in [101, 999].');
    }
  }

  final List<int> numbers;
  final int target;
}

/// A puzzle from [seed], **built backwards** (rule 10): the six numbers
/// first — 1 to 3 distinct bigs, the smalls drawn from two of each 1–9 —
/// then the target drawn among the values in [101, 999] those numbers can
/// actually make. A solution therefore always exists. That set is never
/// empty: with B the largest big and the smalls' running sums rising by at
/// most 9, some B × (s₁ + … + sₖ) or B × s lands in range (proof in
/// `doc/decisions.md`); the tests check thousands of seeds too.
CountPuzzle generateCountPuzzle(int seed) => _generate(seed).$1;

/// The puzzle and its shortest solution, from one pass of the solver.
(CountPuzzle, List<CountStep>) generateCountPuzzleWithSolution(int seed) {
  final (puzzle, solver) = _generate(seed);
  return (puzzle, solver.shortest(puzzle.target)!);
}

(CountPuzzle, _CountSolver) _generate(int seed) {
  final random = Random(seed);
  final numbers = _drawNumbers(random);
  final solver = _CountSolver(numbers);
  final reachable = <int>{};
  for (final values in solver.valuesByMask) {
    for (final v in values.keys) {
      if (v >= countTargetMin && v <= countTargetMax) reachable.add(v);
    }
  }
  if (reachable.isEmpty) {
    // Impossible by the argument above; a bug if it ever happens.
    throw StateError('no target reachable from $numbers');
  }
  final targets = reachable.toList()..sort();
  return (
    CountPuzzle(
      numbers: numbers,
      target: targets[random.nextInt(targets.length)],
    ),
    solver,
  );
}

/// The six numbers: 1 to 3 distinct bigs, then the smalls drawn from two
/// of each 1–9 — one draw per number, from [random].
List<int> _drawNumbers(Random random) {
  final bigCount = 1 + random.nextInt(3);
  final bigs = [...countBigNumbers];
  final smallsPool = [
    for (var n = 1; n <= 9; n++) ...[n, n],
  ];
  return <int>[
    for (var i = 0; i < bigCount; i++)
      bigs.removeAt(random.nextInt(bigs.length)),
    for (var i = 0; i < 6 - bigCount; i++)
      smallsPool.removeAt(random.nextInt(smallsPool.length)),
  ];
}

/// A duel's round of Get the count (Phase 7): the six numbers drawn from
/// [random] as in solo, then the target drawn among the values in
/// [101, 999] whose **shortest solution takes [minOps] to [maxOps]
/// operations** — the difficulty band of the players' rating. Built
/// backwards like solo (rule 10): every candidate is reachable.
///
/// When the numbers make no value of that length in range (rare), the
/// nearest length they do make, the shorter first — the round stays
/// playable, a little off its band. Returns the puzzle and its shortest
/// solution.
(CountPuzzle, List<CountStep>) drawCountPuzzleInBand(
  Random random, {
  required int minOps,
  required int maxOps,
}) {
  if (minOps < 1 || maxOps < minOps || maxOps > 5) {
    throw ArgumentError('operations band $minOps–$maxOps: 1 ≤ min ≤ max ≤ 5');
  }
  final numbers = _drawNumbers(random);
  final solver = _CountSolver(numbers);
  final lengths = solver.shortestLengths();
  List<int> withLengths(bool Function(int ops) keep) => [
    for (final MapEntry(key: value, value: ops) in lengths.entries)
      if (value >= countTargetMin && value <= countTargetMax && keep(ops))
        value,
  ]..sort();
  var targets = withLengths((ops) => ops >= minOps && ops <= maxOps);
  for (var d = 1; targets.isEmpty && d <= 5; d++) {
    targets = withLengths((ops) => ops == minOps - d);
    if (targets.isEmpty) targets = withLengths((ops) => ops == maxOps + d);
  }
  if (targets.isEmpty) {
    // Impossible: some value in range is always reachable (see
    // generateCountPuzzle), and every length 1–5 is tried above.
    throw StateError('no target reachable from $numbers');
  }
  final target = targets[random.nextInt(targets.length)];
  return (
    CountPuzzle(numbers: numbers, target: target),
    solver.shortest(target)!,
  );
}

/// The number of operations of the shortest way to [target] from
/// [numbers], or `null` if none.
int? shortestCountLength(List<int> numbers, int target) =>
    _CountSolver(numbers).shortestLengths()[target];

/// The shortest way to [target] from [numbers] (fewest operations, i.e. the
/// fewest numbers used), or `null` if none: the round's correction.
List<CountStep>? solveCount(List<int> numbers, int target) =>
    _CountSolver(numbers).shortest(target);

int _bits(int mask) {
  var n = 0;
  for (var m = mask; m != 0; m &= m - 1) {
    n++;
  }
  return n;
}

/// How a value was made from a subset: a leaf (one of the numbers) or two
/// disjoint subsets combined.
final class _Origin {
  const _Origin.leaf()
    : left = 0,
      leftValue = 0,
      operator = null,
      right = 0,
      rightValue = 0;
  const _Origin(
    this.left,
    this.leftValue,
    this.operator,
    this.right,
    this.rightValue,
  );

  final int left;
  final int leftValue;
  final CountOperator? operator;
  final int right;
  final int rightValue;
}

/// Every value each subset of the numbers can make, subsets in order of
/// size (a subset of k numbers needs exactly k − 1 operations). The first
/// way found to make a value is kept: deterministic, integers only.
class _CountSolver {
  _CountSolver(this.numbers) {
    final n = numbers.length;
    valuesByMask = List.generate(1 << n, (_) => <int, _Origin>{});
    final masks = [for (var m = 1; m < 1 << n; m++) m]
      ..sort((a, b) {
        final bySize = _bits(a) - _bits(b);
        return bySize != 0 ? bySize : a - b;
      });
    for (final mask in masks) {
      final values = valuesByMask[mask];
      if (_bits(mask) == 1) {
        values[numbers[_lowestIndex(mask)]] = const _Origin.leaf();
        continue;
      }
      // Each unordered split once: the part holding the mask's lowest bit
      // on the left.
      final low = mask & -mask;
      for (var left = (mask - 1) & mask; left > 0; left = (left - 1) & mask) {
        if (left & low == 0) continue;
        final right = mask ^ left;
        final lefts = valuesByMask[left].keys.toList();
        final rights = valuesByMask[right].keys.toList();
        for (final a in lefts) {
          for (final b in rights) {
            // The larger first: a subtraction or a division only ever
            // works that way round (results are positive).
            final aFirst = a >= b;
            final x = aFirst ? a : b;
            final y = aFirst ? b : a;
            final l = aFirst ? left : right;
            final r = aFirst ? right : left;
            void keep(int value, CountOperator op) {
              if (!values.containsKey(value)) {
                values[value] = _Origin(l, x, op, r, y);
              }
            }

            keep(x + y, CountOperator.add);
            if (x > y) keep(x - y, CountOperator.subtract);
            keep(x * y, CountOperator.multiply);
            if (x % y == 0) keep(x ~/ y, CountOperator.divide);
          }
        }
      }
    }
  }

  final List<int> numbers;
  late final List<Map<int, _Origin>> valuesByMask;

  int _lowestIndex(int mask) {
    var i = 0;
    while (mask & (1 << i) == 0) {
      i++;
    }
    return i;
  }

  /// Every value the numbers make, with the fewest operations it takes
  /// (a subset of k numbers takes k − 1).
  Map<int, int> shortestLengths() {
    final lengths = <int, int>{};
    for (var mask = 1; mask < valuesByMask.length; mask++) {
      final ops = _bits(mask) - 1;
      for (final value in valuesByMask[mask].keys) {
        final known = lengths[value];
        if (known == null || ops < known) lengths[value] = ops;
      }
    }
    return lengths;
  }

  List<CountStep>? shortest(int target) {
    int? best;
    for (var mask = 1; mask < valuesByMask.length; mask++) {
      if (!valuesByMask[mask].containsKey(target)) continue;
      if (best == null || _bits(mask) < _bits(best)) best = mask;
    }
    return best == null ? null : steps(best, target);
  }

  List<CountStep> steps(int mask, int value) {
    final origin = valuesByMask[mask][value]!;
    final op = origin.operator;
    if (op == null) return const [];
    return [
      ...steps(origin.left, origin.leftValue),
      ...steps(origin.right, origin.rightValue),
      CountStep(origin.leftValue, op, origin.rightValue, value),
    ];
  }
}

/// A tile on the board: one of the six numbers or a result.
final class CountTile {
  const CountTile({required this.id, required this.value, this.used = false});

  final int id;
  final int value;

  /// Consumed by an operation: shown faded, no longer playable.
  final bool used;
}

/// The board as the player moves it (pure; the app holds the current one).
/// A result takes the second tile's place; the first fades where it was.
final class CountBoard {
  CountBoard._(this.puzzle, this.tiles, this._history, this.seen);

  factory CountBoard.start(CountPuzzle puzzle) => CountBoard._(
    puzzle,
    [for (final (i, n) in puzzle.numbers.indexed) CountTile(id: i, value: n)],
    const [],
    List.unmodifiable(puzzle.numbers),
  );

  final CountPuzzle puzzle;

  /// Six places, in order.
  final List<CountTile> tiles;

  /// The boards before each move, for undo.
  final List<CountBoard> _history;

  /// Every value that has been on the board, for the closest value.
  final List<int> seen;

  bool get solved => tiles.any((t) => !t.used && t.value == puzzle.target);

  bool get canUndo => _history.isNotEmpty;

  /// The board after `first op second`, or `null` if the rules forbid it
  /// (a used tile, the same tile twice, a negative, zero or inexact result).
  CountBoard? combine(int firstId, CountOperator op, int secondId) {
    if (firstId == secondId) return null;
    final first = tiles.where((t) => t.id == firstId).firstOrNull;
    final second = tiles.where((t) => t.id == secondId).firstOrNull;
    if (first == null || second == null || first.used || second.used) {
      return null;
    }
    final result = op.apply(first.value, second.value);
    if (result == null) return null;
    final nextId = tiles.map((t) => t.id).reduce(max) + 1;
    return CountBoard._(
      puzzle,
      [
        for (final t in tiles)
          if (t.id == firstId)
            CountTile(id: t.id, value: t.value, used: true)
          else if (t.id == secondId)
            CountTile(id: nextId, value: result)
          else
            t,
      ],
      [..._history, this],
      [...seen, result],
    );
  }

  CountBoard undo() => _history.isEmpty ? this : _history.last;

  CountBoard reset() => _history.isEmpty ? this : _history.first;

  /// The closest value to the target ever on the board (ties: the first).
  int get closest {
    var best = seen.first;
    for (final v in seen) {
      if ((v - puzzle.target).abs() < (best - puzzle.target).abs()) best = v;
    }
    return best;
  }
}
