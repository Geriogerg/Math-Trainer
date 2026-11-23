@TestOn('vm')
library;

import 'dart:io';
import 'dart:math';

import 'package:math_core/generation/game_generator.dart';
import 'package:math_core/leveling/level.dart';
import 'package:math_core/leveling/rules_version.dart';
import 'package:math_core/models/exercise.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/models/operation_type.dart';
import 'package:math_core/patterns/pattern_family.dart';
import 'package:math_core/patterns/pattern_questions.dart';
import 'package:math_core/tiers/fluent_time.dart';
import 'package:math_core/tiers/tier.dart';
import 'package:math_core/tiers/tiered_game_generator.dart';
import 'package:test/test.dart';

/// `doc/levels.md` checked against the code by reading the spec file itself
/// (plan v3.4, "Patterns and Method outcome": the tests of addition and
/// subtraction once checked the code against itself, and missed that the
/// spec had moved on). A change to the spec's tables breaks this test
/// instead of drifting silently.
///
/// - Section 5, under [RulesVersion.current]: each tier's levels and fluent
///   time; each example is a question its tier draws; the digit counts its
///   content names are the ones it draws, and the heading's "up to N
///   digits" is the most it draws.
/// - Section 5b: each operation's families in the spec's order, each from
///   its tier; each example is a question its family draws.
///
/// "A question it draws" is decided by sampling: exact when the sample
/// holds every question there is (its second half found none new);
/// otherwise digit by digit — the example's shape (operation, digit
/// counts) is drawn, and every column of it takes values drawn in that
/// column. Reads a file: VM only.
void main() {
  final spec = File('../../doc/levels.md').readAsStringSync();
  final tiers = _tables(_section(spec, '## 5. ', '## 5b. '));
  final families = _tables(_section(spec, '## 5b. ', '## 6. '));

  test('the spec has a table of ten tiers for every operation, and a '
      'family table for every operation', () {
    expect(tiers.keys, unorderedEquals(ExerciseType.values));
    for (final MapEntry(key: type, value: table) in tiers.entries) {
      expect(table.rows, hasLength(10), reason: type.name);
    }
    expect(families.keys, unorderedEquals(ExerciseType.values));
  });

  for (final type in ExerciseType.values) {
    group('section 5, ${type.name}', () {
      final table = tiers[type]!;
      final samples = <Tier, _Sample>{};
      _Sample sampleOf(Tier tier) =>
          samples[tier] ??= _Sample.of((r) => _standardAt(type, tier, r));

      for (final tier in Tier.values) {
        test('${tier.label}: levels, fluent time, examples, digit counts', () {
          final row = table.rows[tier.index];
          final [label, levels, content, examples, fluent] = row;
          expect(label, tier.label);

          final range = RegExp(r'^(\d+)–(\d+)$').firstMatch(levels)!;
          for (final whole in [int.parse(range[1]!), int.parse(range[2]!)]) {
            expect(Tier.of(Level.whole(whole)), tier, reason: levels);
          }

          final seconds = int.parse(
            RegExp(r'^(\d+) s$').firstMatch(fluent)![1]!,
          );
          expect(
            fluentTimeMs(
              type,
              Level.whole(10 * tier.index),
              RulesVersion.current,
            ),
            seconds * 1000,
            reason: 'fluent time $fluent',
          );

          final sample = sampleOf(tier);
          for (final text in _examples(examples)) {
            final example = _parse(type, text);
            expect(example.type, type, reason: text);
            expect(sample.missing(example), isNull, reason: text);
          }

          _expectDigitCounts(type, content, sample.questions);
        });
      }

      final upTo = RegExp(r'up to (\d+) digits').firstMatch(table.heading);
      if (upTo != null) {
        test('"${upTo[0]}": the most digits any tier draws', () {
          var most = 0;
          for (final tier in Tier.values) {
            for (final e in sampleOf(tier).questions) {
              for (final n in _numbers(e)) {
                most = max(most, _digits(n));
              }
            }
          }
          expect(most, int.parse(upTo[1]!));
        });
      }
    });
  }

  for (final type in ExerciseType.values) {
    group('section 5b, ${type.name}', () {
      final rows = families[type]!.rows;
      final ofType = [
        for (final f in PatternFamily.values)
          if (f.type == type) f,
      ];

      test('as many families as the spec, in its order', () {
        expect(ofType, hasLength(rows.length));
      });

      for (final (i, family) in ofType.indexed) {
        test('${family.name}: from its tier, its examples drawn', () {
          final [name, examples, from] = rows[i];
          expect(family.from.label, from, reason: name);
          final sample = _Sample.of((r) => patternQuestion(family, r));
          for (final text in _examples(examples)) {
            final example = _parse(type, text);
            expect(example.type, type, reason: text);
            expect(sample.missing(example), isNull, reason: '$name: $text');
          }
        });
      }
    });
  }
}

// --- Reading the spec -------------------------------------------------------

/// The text from the heading starting with [from] to the one starting with
/// [to].
String _section(String spec, String from, String to) {
  final start = spec.indexOf('\n$from');
  final end = spec.indexOf('\n$to', start + 1);
  if (start < 0 || end < 0) {
    throw StateError('doc/levels.md has no section "$from" before "$to".');
  }
  return spec.substring(start, end);
}

/// One `###` table: its heading and its body rows, cell by cell.
typedef _Table = ({String heading, List<List<String>> rows});

/// The `###` tables of a section, by the operation their heading names.
Map<ExerciseType, _Table> _tables(String section) {
  final tables = <ExerciseType, _Table>{};
  for (final part in section.split('\n### ').skip(1)) {
    final lines = part.split('\n');
    final heading = lines.first.trim();
    final type = _typeNamed(heading);
    final rows = [
      for (final line in lines.skip(1))
        if (line.startsWith('|')) _cells(line),
    ];
    // Header and separator first.
    tables[type] = (heading: heading, rows: rows.skip(2).toList());
  }
  return tables;
}

ExerciseType _typeNamed(String heading) {
  for (final (word, type) in const [
    ('Addition', ExerciseType.addition),
    ('Subtraction', ExerciseType.subtraction),
    ('Multiplication', ExerciseType.multiplication),
    ('Division', ExerciseType.division),
    ('Powers', ExerciseType.power),
    ('Roots', ExerciseType.squareRoot),
    ('Percentages', ExerciseType.percentage),
    ('Integrals', ExerciseType.integral),
  ]) {
    if (heading.startsWith(word)) return type;
  }
  throw StateError('No operation is named by the heading "$heading".');
}

/// A table row's cells; `\|` is a pipe inside a cell.
List<String> _cells(String line) {
  final inner = line.trim().substring(1, line.trim().length - 1);
  return [
    for (final cell in inner.split(RegExp(r'(?<!\\)\|')))
      cell.replaceAll(r'\|', '|').trim(),
  ];
}

/// A cell's examples: comma-separated, each without what follows " = " or
/// " (= " (`2¹⁶ = 65 536`, `803 − 497 (= 806 − 500)`).
List<String> _examples(String cell) => [
  for (final text in cell.split(', '))
    text.split(' = ').first.split(' (= ').first.trim(),
];

const _superscripts = '⁰¹²³⁴⁵⁶⁷⁸⁹';
const _subscripts = '₀₁₂₃₄₅₆₇₈₉';

int _script(String text, String alphabet) {
  var n = 0;
  for (final char in text.split('')) {
    final digit = alphabet.indexOf(char);
    if (digit < 0) throw FormatException('Not a digit of $alphabet', text);
    n = 10 * n + digit;
  }
  return n;
}

/// A number as the spec writes it, digits grouped by spaces (`2 468`).
int _number(String text) => int.parse(text.replaceAll(' ', ''));

/// The question an example writes, as [type] stores it.
Exercise _parse(ExerciseType type, String text) {
  Never bad() => throw FormatException('Not a ${type.name} example', text);
  switch (type) {
    case ExerciseType.addition ||
        ExerciseType.subtraction ||
        ExerciseType.multiplication ||
        ExerciseType.division:
      final op = type.operationType!;
      final parts = text.split(' ${_symbol(op)} ').map(_number).toList();
      if (parts.length < 2 || parts.length > 3) bad();
      return ArithmeticExercise(
        operandA: parts[0],
        operandB: parts[1],
        operandC: parts.length == 3 ? parts[2] : null,
        operationType: op,
      );
    case ExerciseType.power:
      final m = RegExp('^([0-9]+)([$_superscripts]+)\$').firstMatch(text);
      if (m == null) bad();
      return PowerExercise(
        base: int.parse(m[1]!),
        exponent: _script(m[2]!, _superscripts),
      );
    case ExerciseType.squareRoot:
      final m = RegExp(r'^([√∛])([0-9 ]+)$').firstMatch(text);
      if (m == null) bad();
      return SquareRootExercise(
        radicand: _number(m[2]!),
        index: m[1] == '√' ? 2 : 3,
      );
    case ExerciseType.percentage:
      final m = RegExp(r'^(\d+)(?:\.(\d))? % of ([0-9 ]+)$').firstMatch(text);
      if (m == null) bad();
      return PercentageExercise(
        percent: int.parse(m[1]!),
        tenths: m[2] == null ? 0 : int.parse(m[2]!),
        base: _number(m[3]!),
      );
    case ExerciseType.integral:
      final m = RegExp(
        '^∫([$_subscripts]+)([$_superscripts]+) \\(?(.+?)\\)? dx\$',
      ).firstMatch(text);
      if (m == null) bad();
      final c = List.filled(5, 0);
      var sign = 1;
      for (final token in m[3]!.split(' ')) {
        if (token == '+' || token == '−') {
          sign = token == '+' ? 1 : -1;
          continue;
        }
        final term = RegExp(
          '^([0-9]*)(x([$_superscripts]*))?\$',
        ).firstMatch(token);
        if (term == null || token.isEmpty) bad();
        final coefficient = term[1]!.isEmpty ? 1 : int.parse(term[1]!);
        final power = term[2] == null
            ? 0
            : term[3]!.isEmpty
            ? 1
            : _script(term[3]!, _superscripts);
        c[power] += sign * coefficient;
        sign = 1;
      }
      return IntegralExercise(
        lower: _script(m[1]!, _subscripts),
        upper: _script(m[2]!, _superscripts),
        c0: c[0],
        c1: c[1],
        c2: c[2],
        c3: c[3],
        c4: c[4],
      );
  }
}

String _symbol(OperationType op) => switch (op) {
  OperationType.addition => '+',
  OperationType.subtraction => '−',
  OperationType.multiplication => '×',
  OperationType.division => '÷',
};

// --- What the code draws ------------------------------------------------------

/// A standard question (no pattern family) of [type] at [tier] under the
/// current rules, through the game generator itself: a game of one
/// question has no review, so it is drawn at its own tier. `null` for a
/// pattern question.
Exercise? _standardAt(ExerciseType type, Tier tier, Random random) {
  final generator =
      gameExerciseGenerator(
            rulesVersion: RulesVersion.current,
            enabledTypes: {type},
            levels: {type: Level.whole(10 * tier.index)},
            typeSequence: [type],
          )
          as TieredGameGenerator;
  final exercise = generator.next(random);
  if (generator.lastTier != tier) {
    throw StateError('A one-question game drew from ${generator.lastTier}.');
  }
  return generator.lastFamily == null ? exercise : null;
}

/// Draws per sample, in two halves.
const _draws = 40000;

/// What a tier or a family draws, sampled: every question, whether that is
/// all there are, and per shape the values each column takes.
class _Sample {
  _Sample.of(Exercise? Function(Random) draw) {
    final random = Random(20261123);
    var newInSecondHalf = 0;
    for (var i = 0; i < _draws; i++) {
      final e = draw(random);
      if (e == null) continue;
      questions.add(e);
      if (_seen.add(e) && i >= _draws ~/ 2) newInSecondHalf++;
      final (shape, columns) = _shapeOf(e);
      final sets = _columns.putIfAbsent(shape, () => []);
      for (final (k, value) in columns.indexed) {
        if (sets.length <= k) sets.add({});
        sets[k].add(value);
      }
    }
    if (questions.isEmpty) throw StateError('Nothing drawn.');
    complete = newInSecondHalf == 0;
  }

  final List<Exercise> questions = [];
  final Set<Exercise> _seen = {};
  final Map<String, List<Set<int>>> _columns = {};

  /// Every question there is was drawn.
  late final bool complete;

  /// Why [example] is not a question drawn here; `null` if it is.
  String? missing(Exercise example) {
    if (_seen.contains(example)) return null;
    if (complete) {
      return 'never drawn, and the ${_seen.length} questions drawn are all '
          'there are';
    }
    final (shape, columns) = _shapeOf(example);
    final sets = _columns[shape];
    if (sets == null) {
      return 'no question of its shape ($shape) is drawn; drawn: '
          '${_columns.keys.toList()..sort()}';
    }
    for (final (k, value) in columns.indexed) {
      if (!sets[k].contains(value)) {
        return 'its shape ($shape) is drawn, but never with $value in '
            'column $k (units first)';
      }
    }
    return null;
  }
}

int _digits(int n) => '$n'.length;

/// The digit of [n] at [column], units first.
int _digitAt(int n, int column) {
  for (var i = 0; i < column; i++) {
    n ~/= 10;
  }
  return n % 10;
}

/// A question's shape and its columns: for a sum or a difference or a
/// product, the operands' digit counts, and per column (units first) the
/// operands' digits in it; for a division, the dividend's digit count and
/// the divisor, and per column the quotient's digit; for the others, their
/// form and their numbers.
(String, List<int>) _shapeOf(Exercise e) => switch (e) {
  ArithmeticExercise(:final operationType, :final operandA, :final operandB)
      when operationType == OperationType.division =>
    (
      'division of ${_digits(operandA)} digits by $operandB',
      [
        for (var k = 0; k < _digits(operandA ~/ operandB); k++)
          _digitAt(operandA ~/ operandB, k),
      ],
    ),
  ArithmeticExercise(
    :final operationType,
    :final operandA,
    :final operandB,
    :final operandC,
  ) =>
    (
      '${operationType.name} of ${[operandA, operandB, ?operandC].map(_digits).join(', ')} digits',
      [
        for (
          var k = 0;
          k < [operandA, operandB, ?operandC].map(_digits).reduce(max);
          k++
        )
          100 * _digitAt(operandA, k) +
              10 * _digitAt(operandB, k) +
              (operandC == null ? 0 : _digitAt(operandC, k)),
      ],
    ),
  PowerExercise(:final base, :final exponent) => ('power ^$exponent', [base]),
  SquareRootExercise(:final index, :final correctAnswer) => (
    'root $index',
    [correctAnswer],
  ),
  PercentageExercise(:final percent, :final tenths, :final base) => (
    'percentage .$tenths of ${_digits(base)} digits',
    [percent, base],
  ),
  IntegralExercise(:final lower, :final upper, :final coefficients) => (
    'integral of terms ${[for (final (k, c) in coefficients.indexed)
      if (c != 0) k]}',
    [lower, upper, ...coefficients],
  ),
};

// --- Digit counts -----------------------------------------------------------

/// What a clause of a tier's content says about digit counts: of the
/// numbers left and right of its operator, or of all its numbers when it
/// has none. `null`: says nothing.
typedef _Claim = ({Set<int>? left, Set<int>? right, Set<int>? all});

/// The operator a clause of [type]'s content is written around; `null`
/// for the operations whose content names no digit counts.
String? _operatorOf(ExerciseType type) => switch (type) {
  ExerciseType.addition => '+',
  ExerciseType.subtraction => '−',
  ExerciseType.multiplication => '×',
  ExerciseType.division => '÷',
  ExerciseType.percentage => ' of ',
  ExerciseType.power ||
  ExerciseType.squareRoot ||
  ExerciseType.integral => null,
};

/// The numbers a question's digit counts are about: an operation's two
/// operands (the dividend and the divisor), a percentage's percent and
/// base.
(int, int) _sides(Exercise e) => switch (e) {
  ArithmeticExercise(:final operandA, :final operandB) => (operandA, operandB),
  PercentageExercise(:final percent, :final base) => (percent, base),
  PowerExercise() ||
  SquareRootExercise() ||
  IntegralExercise() => throw StateError('No sides: $e'),
};

/// The numbers a clause without an operator is about ("7- and 8-digit
/// numbers", "3-digit base").
List<int> _numbers(Exercise e) => switch (e) {
  ArithmeticExercise(:final operandA, :final operandB, :final operandC) => [
    operandA,
    operandB,
    ?operandC,
  ],
  PercentageExercise(:final base) => [base],
  PowerExercise() ||
  SquareRootExercise() ||
  IntegralExercise() => throw StateError('No numbers: $e'),
};

/// The digit counts a piece of content names: "3-digit", "2- and 3-digit",
/// and, beside an operator, every number of a range "16–25".
Set<int>? _digitCounts(String text, {required bool ranges}) {
  final counts = <int>{};
  for (final m in RegExp(r'(\d+)-(?: and (\d+)-)?digit').allMatches(text)) {
    counts.add(int.parse(m[1]!));
    if (m[2] != null) counts.add(int.parse(m[2]!));
  }
  if (ranges) {
    for (final m in RegExp(r'(\d+)–(\d+)').allMatches(text)) {
      for (var n = int.parse(m[1]!); n <= int.parse(m[2]!); n++) {
        counts.add(_digits(n));
      }
    }
  }
  return counts.isEmpty ? null : counts;
}

/// A content cell's claims, clause by clause: clauses split on ";", and on
/// " and " where both halves have the operator ("3-digit + 2-digit and
/// 3-digit + 3-digit").
List<_Claim> _claims(String content, String operator) {
  final claims = <_Claim>[];
  for (final part in content.split(';')) {
    final halves = part.split(' and ');
    final clauses =
        halves.length == 2 && halves.every((h) => h.contains(operator))
        ? halves
        : [part];
    for (final clause in clauses) {
      final at = clause.indexOf(operator);
      claims.add(
        at < 0
            ? (
                left: null,
                right: null,
                all: _digitCounts(clause, ranges: false),
              )
            : (
                left: _digitCounts(clause.substring(0, at), ranges: true),
                right: _digitCounts(
                  clause.substring(at + operator.length),
                  ranges: true,
                ),
                all: null,
              ),
      );
    }
  }
  return claims;
}

/// Every question drawn fits one of the content's clauses, and every digit
/// count a clause names is drawn by the questions that fit it. Sums and
/// products fit either way round.
void _expectDigitCounts(
  ExerciseType type,
  String content,
  List<Exercise> questions,
) {
  final operator = _operatorOf(type);
  if (operator == null) {
    expect(
      _digitCounts(content, ranges: false),
      isNull,
      reason:
          'content "$content" names digit counts: teach this test what '
          'they count for ${type.name}',
    );
    return;
  }
  final claims = _claims(content, operator);
  if (claims.every((c) => c.left == null && c.right == null && c.all == null)) {
    return; // Says nothing about digits ("within 10", "facts of tables 1–5").
  }
  final commutative =
      type == ExerciseType.addition || type == ExerciseType.multiplication;

  bool fits(_Claim c, int left, int right, List<int> all) =>
      (c.left?.contains(_digits(left)) ?? true) &&
      (c.right?.contains(_digits(right)) ?? true) &&
      (c.all == null || all.every((n) => c.all!.contains(_digits(n))));

  final drawn = [
    for (final _ in claims) (left: <int>{}, right: <int>{}, all: <int>{}),
  ];
  for (final e in questions) {
    final (a, b) = _sides(e);
    final all = _numbers(e);
    var fitted = false;
    for (final (i, c) in claims.indexed) {
      final (left, right) = fits(c, a, b, all)
          ? (a, b)
          : commutative && fits(c, b, a, all)
          ? (b, a)
          : (null, null);
      if (left == null || right == null) continue;
      fitted = true;
      drawn[i].left.add(_digits(left));
      drawn[i].right.add(_digits(right));
      drawn[i].all.addAll(all.map(_digits));
    }
    expect(fitted, isTrue, reason: '$e fits no clause of "$content"');
  }
  for (final (i, c) in claims.indexed) {
    if (c.left != null) {
      expect(drawn[i].left, c.left, reason: 'left of clause $i of "$content"');
    }
    if (c.right != null) {
      expect(
        drawn[i].right,
        c.right,
        reason: 'right of clause $i of "$content"',
      );
    }
    if (c.all != null) {
      expect(drawn[i].all, c.all, reason: 'clause $i of "$content"');
    }
  }
}
