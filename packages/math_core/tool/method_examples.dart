// The review's Method examples (review M11, `doc/levels.md` v1.6 section
// 9), printed as the app shows them: the method's kind, then its lines.
//
//   dart run tool/method_examples.dart

import 'package:math_core/method/method.dart';
import 'package:math_core/method/method_expr.dart';
import 'package:math_core/method/method_for.dart';
import 'package:math_core/models/exercise.dart';
import 'package:math_core/models/operation_type.dart';
import 'package:math_core/patterns/pattern_family.dart';

ArithmeticExercise _op(int a, int b, OperationType op) =>
    ArithmeticExercise(operandA: a, operandB: b, operationType: op);

/// The examples: the question, its family when it is a pattern question.
final examples = <(String, Exercise, PatternFamily?)>[
  (
    'near a base, near 1 000',
    _op(1009, 16, OperationType.multiplication),
    PatternFamily.nearBase,
  ),
  ('compensation, single digits', _op(7, 2, OperationType.addition), null),
  (
    'compensation that does not simplify',
    _op(4157, 9449, OperationType.addition),
    null,
  ),
  ('compensation (spec: yes)', _op(47, 68, OperationType.addition), null),
  ('a step that restates', _op(10, 7, OperationType.subtraction), null),
  ('long division', _op(5104, 4, OperationType.division), null),
  ('a split dividend (label)', _op(2082, 6, OperationType.division), null),
  ('a cube (label)', const PowerExercise(base: 2, exponent: 3), null),
  ('percentage fallback', PercentageExercise(percent: 64, base: 175), null),
  (
    'percentage, multiple of 5 %',
    PercentageExercise(percent: 35, base: 140),
    null,
  ),
];

String render(Method m) => [
  for (final line in m.lines)
    [
      if (line.continues) '=',
      for (final (i, t) in line.terms.indexed) ...[
        if (i > 0) line.relations[i - 1] == Relation.equals ? '=' : '<',
        methodText(t),
      ],
    ].join(' '),
].join('  |  ');

/// The question as the app writes it.
String question(Exercise e) => switch (e) {
  ArithmeticExercise(:final operandA, :final operandB, :final operationType) =>
    '$operandA ${switch (operationType) {
      OperationType.addition => '+',
      OperationType.subtraction => '−',
      OperationType.multiplication => '×',
      OperationType.division => '÷',
    }} $operandB',
  PowerExercise(:final base, :final exponent) => '$base^$exponent',
  PercentageExercise(:final percent, :final base) => '$percent % of $base',
  _ => '$e',
};

void main() {
  for (final (what, e, family) in examples) {
    final m = methodFor(e, family: family);
    final kind =
        m.family?.name ?? m.strategy?.name ?? 'fallback ${m.fallback?.name}';
    print('$what — ${question(e)} [$kind]');
    print('    ${render(m)}');
  }
}
