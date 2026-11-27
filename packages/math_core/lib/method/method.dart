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

/// What a fallback's lines do (`doc/levels.md` v1.6 section 9: "the
/// strategy name matches what the lines do") — the app names it. Not
/// stored: a Method is computed when it is shown.
enum MethodFallback {
  /// 8 + 7 = 8 + 2 + 5.
  makeTen,

  /// 4 + 5 = 4 + 4 + 1; 4 + 6 = 5 + 5.
  nearDouble,

  /// 7 + 2 = 7 + 1 + 1.
  countOn,

  /// 47 + 38 = (40 + 30) + (7 + 8): by place value, left to right.
  placeValue,

  /// 9 − 4: 4 + 5 = 9.
  thinkAddition,

  /// 43 − 7 = (10 − 7) + (43 − 10): up through a round number.
  countUp,

  /// 87 − 34 = 87 − 30 − 4: the subtrahend in parts.
  takeAwayInParts,

  /// 1 × 7, 10 × 7: the fact itself.
  timesOneOrTen,

  /// 8 × 7 = 8 × 5 + 8 × 2.
  fives,

  /// 3 × 4 = 4 + 4 + 4.
  repeatedAddition,

  /// 70 × 8 = 7 × 8 × 10.
  tensFirst,

  /// 47 × 6 = (40 + 7) × 6.
  splitFactor,

  /// 56 ÷ 8: 8 × 7 = 56.
  thinkMultiplication,

  /// 5 104 ÷ 4 = 4 000 ÷ 4 + 1 000 ÷ 4 + 104 ÷ 4.
  splitDividend,

  /// 47² = (50 − 3)².
  nearestTen,

  /// 70² = 7 × 7 × 100.
  squareTens,

  /// 7² = 7 × 7; 2³ = 2² × 2.
  multiplyOut,

  /// √49: 7² = 49.
  knownPower,

  /// √5 184: 70² < 5 184 < 80², then the last digit.
  lastDigitBracket,

  /// 50 % = half, 25 % = a quarter, 20 %, 10 %, 1 %, 75 %, eighths.
  friendlyFraction,

  /// 120 % of 45 = 45 + 45 ÷ 5: the whole and a friendly rest.
  wholeAndRest,

  /// From 50 %, 25 %, 10 %, 5 % and 1 % (and 100 %).
  buildPercentage,

  /// 64 % of 175 = 175 % of 64, then built.
  swapAndBuild,

  /// F(b) − F(a).
  antiderivative,

  /// p × base ÷ 100: only for a question no whole build fits, which rules
  /// v9 never draws (tested) — kept for older rules' questions.
  productOver100,
}

/// A worked method for one question (`doc/levels.md` section 9): the
/// strategy it follows and 2 to 4 lines of arithmetic with the question's
/// own numbers, the last ending on the answer. The strategy is the pattern
/// family's for a pattern question, the detector's otherwise, or the
/// operation's [fallback] — what its lines do.
final class Method {
  const Method({
    required this.lines,
    this.family,
    this.strategy,
    this.fallback,
  });

  final List<MethodLine> lines;
  final PatternFamily? family;
  final Strategy? strategy;

  /// Set exactly when neither [family] nor [strategy] is.
  final MethodFallback? fallback;

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
