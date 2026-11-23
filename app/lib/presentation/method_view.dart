import 'package:material_ui/material_ui.dart';

import 'package:math_core/method/method.dart';
import 'package:math_core/method/method_expr.dart';

import 'number_format.dart';

/// A Method's lines (`doc/levels.md` section 9), one per row, from the
/// core's tokens: grouped thousands, true minus sign, raised exponents, √
/// and a raised 3 for ∛ — the same notation as the game's prompts. A long
/// line shrinks to the width rather than wrapping mid-expression.
class MethodLines extends StatelessWidget {
  const MethodLines({super.key, required this.method, this.style});

  final Method method;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final style = this.style ?? Theme.of(context).textTheme.bodyLarge;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in method.lines)
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(style: style, children: methodLineSpans(line, style)),
              softWrap: false,
            ),
          ),
      ],
    );
  }
}

/// [line] as spans in [style].
List<InlineSpan> methodLineSpans(MethodLine line, TextStyle? style) {
  final fontSize = style?.fontSize ?? 16;
  final small = style?.copyWith(fontSize: fontSize * 0.6);
  final out = <InlineSpan>[];
  final text = StringBuffer();
  void flush() {
    if (text.isNotEmpty) {
      out.add(TextSpan(text: text.toString()));
      text.clear();
    }
  }

  void raised(String s) {
    flush();
    out.add(
      WidgetSpan(
        alignment: PlaceholderAlignment.top,
        child: Text(s, style: small),
      ),
    );
  }

  if (line.continues) text.write('= ');
  for (final (i, term) in line.terms.indexed) {
    if (i > 0) {
      text.write(switch (line.relations[i - 1]) {
        Relation.equals => ' = ',
        Relation.lessThan => ' < ',
      });
    }
    ExprToken? previous;
    for (final token in exprTokens(term)) {
      final glued =
          previous == null ||
          previous is OpenParen ||
          previous is RootToken ||
          token is CloseParen ||
          (token is OpenParen && previous is CloseParen);
      switch (token) {
        case ExponentToken(:final exponent):
          raised('$exponent');
        case RootToken(:final index):
          if (!glued) text.write(' ');
          if (index == 3) raised('3');
          text.write('√');
        case _:
          if (!glued) text.write(' ');
          text.write(switch (token) {
            NumberToken(:final value) => groupedNumber(value),
            OperatorToken(:final op) => switch (op) {
              Op.plus => '+',
              // True minus sign (`doc/design.md`).
              Op.minus => '−',
              Op.times => '×',
              Op.divide => '÷',
            },
            OpenParen() => '(',
            CloseParen() => ')',
            PercentToken(:final percent, :final tenths) =>
              '$percent${tenths == 0 ? '' : '.$tenths'}%',
            OfToken() => 'of',
            ExponentToken() || RootToken() => '',
          });
      }
      previous = token;
    }
  }
  flush();
  return out;
}

/// [line] as plain text — for semantics and tests ("= (20 − 3)(20 + 3)",
/// exponents as "^2").
String methodLineText(MethodLine line) => methodLineSpans(line, null)
    .map(
      (s) => switch (s) {
        TextSpan(:final text) => text ?? '',
        WidgetSpan(:final child) when child is Text => '^${child.data}',
        _ => '',
      },
    )
    .join();
