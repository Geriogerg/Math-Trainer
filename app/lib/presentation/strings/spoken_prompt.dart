import 'package:math_core/models/exercise.dart';

import '../exercise_prompt.dart' show integralTerms;
import 'strings.dart';

/// What a screen reader says for [exercise] (Phase 6b commit 6, review
/// M17: "12²" had no spoken label, "√169" read as a symbol), in the
/// interface's language (`SpokenStrings`, Phase 6d). Words for the signs,
/// and numbers ungrouped — "4 789" would be read as two numbers.
/// Exhaustive `switch` without `default` (rule 11).
String spokenPrompt(Exercise exercise) => switch (exercise) {
  ArithmeticExercise e => [
    '${e.operandA}',
    '${e.operandB}',
    if (e.operandC case final c?) '$c',
  ].join(' ${strings.spoken.operator(e.operationType)} '),
  PowerExercise e => strings.spoken.power(e.base, e.exponent),
  SquareRootExercise e => strings.spoken.root(e.index, e.radicand),
  PercentageExercise e => strings.spoken.percent(e.percent, e.tenths, e.base),
  IntegralExercise e => strings.spoken.integral(
    e.lower,
    e.upper,
    _spokenPolynomial(e),
  ),
};

/// "4 x cubed minus x plus 2", from the terms the prompt draws.
String _spokenPolynomial(IntegralExercise e) {
  final words = StringBuffer();
  for (final (i, term) in integralTerms(e).indexed) {
    if (i > 0) words.write(strings.spoken.sign(negative: term.negative));
    final x = strings.spoken.xPower(term.power);
    words.write(
      [
        if (term.coefficient.isNotEmpty) term.coefficient,
        x,
      ].where((part) => part.isNotEmpty).join(' '),
    );
  }
  return words.toString();
}
