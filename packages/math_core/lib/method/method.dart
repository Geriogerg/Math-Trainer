import '../models/exercise.dart';
import '../patterns/pattern_family.dart';
import '../strategies/strategy.dart';
import 'method_expr.dart';

/// How two terms of a line relate.
enum Relation { equals, lessThan }

/// One line of a Method: terms joined by relations ("80² < 7 569 < 90²",
/// "43 × 11 = 430 + 43 = 473"). A line that [continues] starts with "=":
/// its first term equals the previous line's last — or, for the first
/// line, the question shown above it ("= (20 − 3)(20 + 3)").
final class MethodLine {
  /// Throws unless there is one relation fewer than terms (rule 13).
  MethodLine(this.terms, this.relations, {this.continues = false}) {
    if (terms.isEmpty || relations.length != terms.length - 1) {
      throw ArgumentError.value(
        (terms.length, relations.length),
        'line',
        'needs n terms and n − 1 relations.',
      );
    }
  }

  /// "= a = b …", following on.
  factory MethodLine.then(List<Expr> terms) => MethodLine(terms, [
    for (var i = 1; i < terms.length; i++) Relation.equals,
  ], continues: true);

  /// "a = b …", standing alone.
  factory MethodLine.equal(List<Expr> terms) => MethodLine(terms, [
    for (var i = 1; i < terms.length; i++) Relation.equals,
  ]);

  final List<Expr> terms;
  final List<Relation> relations;
  final bool continues;
}

/// A worked method for one question (`doc/levels.md` section 9): the
/// strategy it follows and 2 to 4 lines of arithmetic with the question's
/// own numbers, the last ending on the answer. The strategy is the pattern
/// family's for a pattern question, the detector's otherwise, or — neither
/// set — the operation's fallback.
final class Method {
  const Method({required this.lines, this.family, this.strategy});

  final List<MethodLine> lines;
  final PatternFamily? family;
  final Strategy? strategy;

  bool get isFallback => family == null && strategy == null;
}

/// What is wrong with [method] as a method for [exercise]; empty when it
/// is sound: 1 to 4 lines; every term exact, never negative; every
/// relation true; a following line equal to what it follows (the answer,
/// for the first); the last term of the last line the answer itself.
List<String> methodProblems(Method method, Exercise exercise) {
  final problems = <String>[];
  final lines = method.lines;
  if (lines.isEmpty || lines.length > 4) {
    problems.add('${lines.length} lines');
    return problems;
  }
  final answer = exercise.correctAnswer;
  int? previous = answer;
  for (final (i, line) in lines.indexed) {
    final List<int> values;
    try {
      values = [for (final t in line.terms) t.value];
    } on ArgumentError catch (e) {
      problems.add('line ${i + 1}: ${e.message}');
      previous = null;
      continue;
    }
    for (final (j, t) in line.terms.indexed) {
      if (_hasNegative(t)) problems.add('line ${i + 1}, term ${j + 1}: < 0');
    }
    if (line.continues && previous != null && values.first != previous) {
      problems.add('line ${i + 1}: ${values.first} follows $previous with "="');
    }
    for (final (j, r) in line.relations.indexed) {
      final ok = switch (r) {
        Relation.equals => values[j] == values[j + 1],
        Relation.lessThan => values[j] < values[j + 1],
      };
      if (!ok) {
        problems.add(
          'line ${i + 1}: ${methodText(line.terms[j])} ${r.name} '
          '${methodText(line.terms[j + 1])} is false',
        );
      }
    }
    previous = values.last;
  }
  final last = lines.last.terms.last;
  if (last != Num(answer)) {
    problems.add('ends on ${methodText(last)}, not $answer');
  }
  return problems;
}

bool _hasNegative(Expr e) => switch (e) {
  Num(:final n) => n < 0,
  Bin(:final left, :final right) => _hasNegative(left) || _hasNegative(right),
  Group(:final inner) => _hasNegative(inner),
  Pow(:final base) => _hasNegative(base),
  RootOf(:final radicand) => radicand < 0,
  PercentOf(:final base) => base < 0,
};

/// [method] as plain text, one line per line: for test messages only.
String methodDebugText(Method method) => [
  for (final line in method.lines)
    [
      if (line.continues) '=',
      for (final (i, t) in line.terms.indexed) ...[
        if (i > 0) line.relations[i - 1] == Relation.equals ? '=' : '<',
        methodText(t),
      ],
    ].join(' '),
].join('\n');
