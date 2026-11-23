/// The arithmetic of a Method line (`doc/levels.md` section 9): integer
/// expressions that evaluate themselves, so a test can check every line —
/// and that lay themselves out as tokens, so the app renders them without
/// deciding where parentheses go (the domain produces no display text:
/// numbers stay numbers, operators stay operators).
library;

/// An integer expression. [value] throws [ArgumentError] when a step is not
/// exact (a division with a remainder, a root of a non-power, a percentage
/// that is not whole): a Method line must never hide a rounding.
sealed class Expr {
  const Expr();

  int get value;

  /// How tightly it binds: sums 1, products 2, powers 3, atoms 4.
  int get _precedence;
}

/// A number shown as is (never negative in a Method).
final class Num extends Expr {
  const Num(this.n);

  final int n;

  @override
  int get value => n;

  @override
  int get _precedence => 4;

  @override
  bool operator ==(Object other) => other is Num && other.n == n;

  @override
  int get hashCode => n.hashCode;

  @override
  String toString() => '$n';
}

/// The four operators, as Method lines write them.
enum Op { plus, minus, times, divide }

/// `left op right`.
final class Bin extends Expr {
  const Bin(this.op, this.left, this.right);

  final Op op;
  final Expr left;
  final Expr right;

  @override
  int get value {
    final a = left.value;
    final b = right.value;
    return switch (op) {
      Op.plus => a + b,
      Op.minus => a - b,
      Op.times => a * b,
      Op.divide =>
        b != 0 && a % b == 0
            ? a ~/ b
            : throw ArgumentError.value((a, b), 'divide', 'is not exact.'),
    };
  }

  @override
  int get _precedence => switch (op) {
    Op.plus || Op.minus => 1,
    Op.times || Op.divide => 2,
  };

  @override
  String toString() => methodText(this);
}

/// Parentheses kept on purpose, where they show the move:
/// "(30 + 60) + (7 + 3)".
final class Group extends Expr {
  const Group(this.inner);

  final Expr inner;

  @override
  int get value => inner.value;

  @override
  int get _precedence => 4;

  @override
  String toString() => methodText(this);
}

/// `base^exponent`, the exponent raised.
final class Pow extends Expr {
  /// Throws for a negative exponent (rule 13).
  Pow(this.base, this.exponent) {
    if (exponent < 0) {
      throw ArgumentError.value(exponent, 'exponent', 'must be >= 0.');
    }
  }

  final Expr base;
  final int exponent;

  @override
  int get value {
    final b = base.value;
    var r = 1;
    for (var i = 0; i < exponent; i++) {
      r *= b;
    }
    return r;
  }

  @override
  int get _precedence => 3;

  @override
  String toString() => methodText(this);
}

/// `√radicand` or `∛radicand`: exact by construction, checked here.
final class RootOf extends Expr {
  const RootOf(this.radicand, {this.index = 2});

  final int radicand;
  final int index;

  @override
  int get value {
    var r = 0;
    while (_power(r + 1) <= radicand) {
      r++;
    }
    if (_power(r) != radicand) {
      throw ArgumentError.value(radicand, 'radicand', 'is not a power.');
    }
    return r;
  }

  int _power(int x) => index == 2 ? x * x : x * x * x;

  @override
  int get _precedence => 4;

  @override
  String toString() => methodText(this);
}

/// `percent.tenths % of base`, whole by construction, checked here.
final class PercentOf extends Expr {
  const PercentOf(this.percent, this.base, {this.tenths = 0});

  final int percent;
  final int tenths;
  final int base;

  @override
  int get value {
    final thousandths = (percent * 10 + tenths) * base;
    if (thousandths % 1000 != 0) {
      throw ArgumentError.value(thousandths, 'percentage', 'is not whole.');
    }
    return thousandths ~/ 1000;
  }

  @override
  int get _precedence => 2;

  @override
  String toString() => methodText(this);
}

/// One piece of an expression's layout, left to right.
sealed class ExprToken {
  const ExprToken();
}

final class NumberToken extends ExprToken {
  const NumberToken(this.value);
  final int value;
}

final class OperatorToken extends ExprToken {
  const OperatorToken(this.op);
  final Op op;
}

final class OpenParen extends ExprToken {
  const OpenParen();
}

final class CloseParen extends ExprToken {
  const CloseParen();
}

/// Raised after the token before it.
final class ExponentToken extends ExprToken {
  const ExponentToken(this.exponent);
  final int exponent;
}

/// √ (index 2) or a raised 3 and √ (index 3), before the radicand.
final class RootToken extends ExprToken {
  const RootToken(this.index);
  final int index;
}

/// "37.5 %": the percentage with its tenths and the sign.
final class PercentToken extends ExprToken {
  const PercentToken(this.percent, this.tenths);
  final int percent;
  final int tenths;
}

/// "of".
final class OfToken extends ExprToken {
  const OfToken();
}

/// [expr] laid out: parentheses only where precedence needs them or a
/// [Group] asks; two parenthesised factors side by side lose their ×
/// ("(20 − 3)(20 + 3)").
List<ExprToken> exprTokens(Expr expr) {
  final out = <ExprToken>[];
  void emit(Expr e) {
    switch (e) {
      case Num(:final n):
        out.add(NumberToken(n));
      case Group(:final inner):
        out.add(const OpenParen());
        emit(inner);
        out.add(const CloseParen());
      case Pow(:final base, :final exponent):
        _wrapped(base, base._precedence < 4, emit, out);
        out.add(ExponentToken(exponent));
      case RootOf(:final radicand, :final index):
        out
          ..add(RootToken(index))
          ..add(NumberToken(radicand));
      case PercentOf(:final percent, :final tenths, :final base):
        out
          ..add(PercentToken(percent, tenths))
          ..add(const OfToken())
          ..add(NumberToken(base));
      case Bin(:final op, :final left, :final right):
        final p = e._precedence;
        final leftParens = left._precedence < p;
        // Same precedence on the right: parentheses, but for a + (b + c)
        // and a × (b × c), which mean the same without.
        final rightParens =
            right._precedence < p ||
            (right._precedence == p &&
                !(right is Bin &&
                    right.op == op &&
                    (op == Op.plus || op == Op.times)));
        _wrapped(left, leftParens, emit, out);
        final leftClosed = leftParens || left is Group;
        final rightOpens = rightParens || right is Group;
        if (!(op == Op.times && leftClosed && rightOpens)) {
          out.add(OperatorToken(op));
        }
        _wrapped(right, rightParens, emit, out);
    }
  }

  emit(expr);
  return out;
}

void _wrapped(
  Expr e,
  bool parens,
  void Function(Expr) emit,
  List<ExprToken> out,
) {
  if (parens) out.add(const OpenParen());
  emit(e);
  if (parens) out.add(const CloseParen());
}

/// Plain text of [expr], for test messages and debugging only — the app
/// renders the tokens itself (grouped thousands, raised exponents).
String methodText(Expr expr) {
  final b = StringBuffer();
  ExprToken? previous;
  for (final t in exprTokens(expr)) {
    final glued =
        previous == null ||
        previous is OpenParen ||
        previous is RootToken ||
        t is CloseParen ||
        t is ExponentToken ||
        (t is OpenParen && previous is CloseParen);
    if (!glued) b.write(' ');
    b.write(switch (t) {
      NumberToken(:final value) => '$value',
      OperatorToken(:final op) => switch (op) {
        Op.plus => '+',
        Op.minus => '−',
        Op.times => '×',
        Op.divide => '÷',
      },
      OpenParen() => '(',
      CloseParen() => ')',
      ExponentToken(:final exponent) => '^$exponent',
      RootToken(:final index) => index == 2 ? '√' : '∛',
      PercentToken(:final percent, :final tenths) =>
        '$percent${tenths == 0 ? '' : '.$tenths'} %',
      OfToken() => 'of',
    });
    previous = t;
  }
  return b.toString();
}
