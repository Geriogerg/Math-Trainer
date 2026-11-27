import 'package:math_core/models/exercise.dart';
import 'package:math_core/models/operation_type.dart';

import '../exercise_prompt.dart' show integralTerms;

/// What a screen reader says for [exercise] (Phase 6b commit 6, review
/// M17: "12²" had no spoken label, "√169" read as a symbol). Words for
/// the signs, and numbers ungrouped — "4 789" would be read as two numbers.
/// Exhaustive `switch` without `default` (rule 11).
String spokenPrompt(Exercise exercise) => switch (exercise) {
  ArithmeticExercise e => [
    '${e.operandA}',
    '${e.operandB}',
    if (e.operandC case final c?) '$c',
  ].join(' ${_spokenOperator(e.operationType)} '),
  PowerExercise e => switch (e.exponent) {
    2 => '${e.base} squared',
    3 => '${e.base} cubed',
    final n => '${e.base} to the power $n',
  },
  SquareRootExercise e => switch (e.index) {
    2 => 'the square root of ${e.radicand}',
    3 => 'the cube root of ${e.radicand}',
    final n => 'the root $n of ${e.radicand}',
  },
  PercentageExercise e =>
    '${e.percent}${e.tenths == 0 ? '' : '.${e.tenths}'} percent of ${e.base}',
  IntegralExercise e =>
    'the integral from ${e.lower} to ${e.upper} of '
        '${_spokenPolynomial(e)}, d x',
};

String _spokenOperator(OperationType type) => switch (type) {
  OperationType.addition => 'plus',
  OperationType.subtraction => 'minus',
  OperationType.multiplication => 'times',
  OperationType.division => 'divided by',
};

/// "4 x cubed minus x plus 2", from the terms the prompt draws.
String _spokenPolynomial(IntegralExercise e) {
  final words = StringBuffer();
  for (final (i, term) in integralTerms(e).indexed) {
    if (i > 0) words.write(term.negative ? ' minus ' : ' plus ');
    final x = switch (term.power) {
      0 => '',
      1 => 'x',
      2 => 'x squared',
      3 => 'x cubed',
      final n => 'x to the power $n',
    };
    words.write(
      [
        if (term.coefficient.isNotEmpty) term.coefficient,
        x,
      ].where((part) => part.isNotEmpty).join(' '),
    );
  }
  return words.toString();
}
