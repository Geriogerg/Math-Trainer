import 'dart:math';

/// Chain operations (Redesign phase commit 7): a starting number, then one
/// operation per screen; the player keeps the running value in mind and
/// types the result at the end. Solo for now, seeded and pure so Phase 7
/// can replay it on a server.

/// Seconds each screen stays up (the setup page's choices).
const chainSecondsChoices = [1, 2, 3];

/// How many operations follow the starting number.
const chainOperationChoices = [5, 10, 15];

/// The chain's setup page: seconds per screen and operations. Remembered
/// between launches (`ChainSetupStore`; Redesign close-out). Throws on a
/// value the page does not offer (rule 13).
final class ChainSetup {
  ChainSetup({this.secondsPerScreen = 2, this.operations = 10}) {
    if (!chainSecondsChoices.contains(secondsPerScreen)) {
      throw ArgumentError.value(
        secondsPerScreen,
        'secondsPerScreen',
        'must be one of $chainSecondsChoices.',
      );
    }
    if (!chainOperationChoices.contains(operations)) {
      throw ArgumentError.value(
        operations,
        'operations',
        'must be one of $chainOperationChoices.',
      );
    }
  }

  final int secondsPerScreen;
  final int operations;

  ChainSetup copyWith({int? secondsPerScreen, int? operations}) => ChainSetup(
    secondsPerScreen: secondsPerScreen ?? this.secondsPerScreen,
    operations: operations ?? this.operations,
  );

  @override
  bool operator ==(Object other) =>
      other is ChainSetup &&
      other.secondsPerScreen == secondsPerScreen &&
      other.operations == operations;

  @override
  int get hashCode => Object.hash(secondsPerScreen, operations);
}

/// Every value of a chain stays within [1, chainMaxValue]: whole, never
/// negative (never 0 either — it would make × and ÷ trivial).
const chainMaxValue = 999;

enum ChainOperator {
  add('+'),
  subtract('−'),
  multiply('×'),
  divide('÷');

  const ChainOperator(this.symbol);

  /// As shown: the true minus, times and divide signs (`doc/design.md`).
  final String symbol;
}

final class ChainStep {
  const ChainStep(this.operator, this.operand);

  final ChainOperator operator;
  final int operand;

  int applyTo(int value) => switch (operator) {
    ChainOperator.add => value + operand,
    ChainOperator.subtract => value - operand,
    ChainOperator.multiply => value * operand,
    ChainOperator.divide => value ~/ operand,
  };

  @override
  bool operator ==(Object other) =>
      other is ChainStep &&
      other.operator == operator &&
      other.operand == operand;

  @override
  int get hashCode => Object.hash(operator, operand);

  @override
  String toString() => '${operator.symbol} $operand';
}

final class Chain {
  Chain({required this.start, required List<ChainStep> steps})
    : steps = List.unmodifiable(steps) {
    if (start < 1 || start > chainMaxValue) {
      throw ArgumentError.value(start, 'start', 'must be in [1, 999].');
    }
    var value = start;
    for (final (i, step) in steps.indexed) {
      if (step.operator == ChainOperator.divide &&
          (step.operand == 0 || value % step.operand != 0)) {
        throw ArgumentError.value(
          step,
          'steps[$i]',
          'is not an exact division.',
        );
      }
      value = step.applyTo(value);
      if (value < 1 || value > chainMaxValue) {
        throw ArgumentError.value(
          step,
          'steps[$i]',
          'leaves [1, 999]: $value.',
        );
      }
    }
  }

  final int start;
  final List<ChainStep> steps;

  /// The running value after the start and after every step: the
  /// correction, line by line.
  List<int> get values {
    final out = [start];
    for (final step in steps) {
      out.add(step.applyTo(out.last));
    }
    return out;
  }

  int get answer => values.last;
}

/// A chain of [operations] steps from [seed], **built forwards within the
/// rules** (rule 10): at each step only the operations that keep the value
/// whole and in [1, 999] are offered — subtraction below the value, a
/// product that stays ≤ 999, a divisor that divides — then one is drawn,
/// then its operand among the valid ones. Never a draw followed by a
/// check. Operands 1–9 (+ −) and 2–9 (× ÷); start 2–20.
Chain generateChain({required int seed, required int operations}) {
  if (!chainOperationChoices.contains(operations)) {
    throw ArgumentError.value(
      operations,
      'operations',
      'must be one of $chainOperationChoices.',
    );
  }
  final random = Random(seed);
  final start = 2 + random.nextInt(19);
  var value = start;
  final steps = <ChainStep>[];
  for (var i = 0; i < operations; i++) {
    final options = <ChainOperator, List<int>>{
      ChainOperator.add: [
        for (var k = 1; k <= 9; k++)
          if (value + k <= chainMaxValue) k,
      ],
      ChainOperator.subtract: [
        for (var k = 1; k <= 9; k++)
          if (value - k >= 1) k,
      ],
      ChainOperator.multiply: [
        for (var k = 2; k <= 9; k++)
          if (value * k <= chainMaxValue) k,
      ],
      ChainOperator.divide: [
        for (var k = 2; k <= 9; k++)
          if (value % k == 0) k,
      ],
    }..removeWhere((_, operands) => operands.isEmpty);
    // In enum order (a map literal keeps insertion order): deterministic.
    final operators = options.keys.toList();
    final operator = operators[random.nextInt(operators.length)];
    final operands = options[operator]!;
    final step = ChainStep(operator, operands[random.nextInt(operands.length)]);
    steps.add(step);
    value = step.applyTo(value);
  }
  return Chain(start: start, steps: steps);
}
