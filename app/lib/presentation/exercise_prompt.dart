import 'package:material_ui/material_ui.dart';

import 'package:math_core/models/exercise.dart';
import 'package:math_core/models/operation_type.dart';

/// Builds the display of an [Exercise] from its variant's fields — the
/// domain produces no text (`doc/decisions.md`, "`Exercise.prompt` left the
/// domain"). Exhaustive `switch` without `default` (rule 11): any new
/// exercise type fails to compile here until it has its rendering.
class ExercisePrompt extends StatelessWidget {
  const ExercisePrompt({super.key, required this.exercise, this.style});

  final Exercise exercise;

  /// Defaults to `displayMedium`, the session screen's size; the result
  /// screen's mistakes list passes a smaller one.
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final style = this.style ?? Theme.of(context).textTheme.displayMedium;
    return switch (exercise) {
      ArithmeticExercise e => Text(
        '${e.operandA} ${_operatorSymbol(e.operationType)} ${e.operandB}',
        style: style,
      ),
      PowerExercise e => _PowerPrompt(exercise: e, style: style),
      SquareRootExercise e => _SquareRootPrompt(exercise: e, style: style),
      PercentageExercise e => Text('${e.percent}% of ${e.base}', style: style),
    };
  }
}

String _operatorSymbol(OperationType type) => switch (type) {
  OperationType.addition => '+',
  // True minus sign U+2212, never the hyphen U+002D (`doc/design.md`).
  OperationType.subtraction => '−',
  OperationType.multiplication => '×',
  OperationType.division => '÷',
};

/// Raised exponent, ~55 % of the base's size (`doc/design.md`) — never `^`,
/// never the Unicode digits `²`/`³` (they render poorly across fonts and
/// stop at 3). The `WidgetSpan` aligned to the top of the line gives the
/// offset: smaller text aligned to the top of the line sits visually higher
/// than the base.
const _powerLineHeight = 57 / 48;

class _PowerPrompt extends StatelessWidget {
  const _PowerPrompt({required this.exercise, required this.style});

  final PowerExercise exercise;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final fontSize = style?.fontSize ?? 48;
    final exponentStyle = style?.copyWith(fontSize: fontSize * 0.55);
    return Text.rich(
      // The raised exponent makes this line taller than the others, by an
      // amount that depends on the face's metrics. Fixed at what it was in
      // Inter when the beta started (57 px at 48 sp): the digit face must
      // not move the answer below it (Phase 5 beta-safety rule,
      // `session_layout_pin_test.dart`).
      strutStyle: StrutStyle(
        fontSize: fontSize,
        height: _powerLineHeight,
        forceStrutHeight: true,
      ),
      TextSpan(
        style: style,
        children: [
          TextSpan(text: '${exercise.base}'),
          WidgetSpan(
            alignment: PlaceholderAlignment.top,
            child: Text('${exercise.exponent}', style: exponentStyle),
          ),
        ],
      ),
    );
  }
}

/// Horizontal bar over the radicand (`doc/design.md`): without it, `√169`
/// reads `√1` then `69`. `Border(top:)` on the radicand alone — the `√`
/// symbol is not under the bar, a simplification accepted by
/// `doc/design.md`.
class _SquareRootPrompt extends StatelessWidget {
  const _SquareRootPrompt({required this.exercise, required this.style});

  final SquareRootExercise exercise;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('√', style: style),
        Container(
          padding: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: style?.color ?? Theme.of(context).colorScheme.onSurface,
                width: 2,
              ),
            ),
          ),
          child: Text('${exercise.radicand}', style: style),
        ),
      ],
    );
  }
}
