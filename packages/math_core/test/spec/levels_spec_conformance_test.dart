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
import 'package:math_core/patterns/pattern_spaces_v9.dart';
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
/// - Section 5b, under the current rules (v9, spec v1.6): each operation's
///   families in the spec's order, each from its tier; each example is a
///   question its family draws (left of "→" at its first tier, right of it
///   at T9, others at some tier). The size table, row by row: each entry is
///   the largest size its band draws, and the band never draws a lower
///   band's size (unless the entry names its own smallest, "(20–90)³");
///   a row-wide condition ("quotient never below 10") holds at every tier;
///   "mirror of powers of 2, two tiers later" is read from the Powers of 2
///   row. The hard limit, for every other family at T0–T8: no number shown
///   or answered with more significant digits than the standard questions
///   of its tier or the next. **Families grow** (v1.6): a family's median
///   answer never decreases from one tier where it is drawn to the next,
///   and — outside the size table — grows at least every two tiers until it
///   reaches its last size.
///
/// "A question it draws" is decided by sampling: exact when the sample
/// holds every question there is (its second half found none new);
/// otherwise digit by digit — the example's shape (operation, digit
/// counts) is drawn, and every column of it takes values drawn in that
/// column. Reads a file: VM only.
void main() {
  // The owner's file (Phase 6b commit 1: the frozen v1.5 copy Phase 6a read
  // while v8 was current is gone).
  final spec = File('../../doc/levels.md').readAsStringSync();
  final tiers = _tables(_section(spec, '## 5. ', '## 5b. '));
  final section5b = _section(spec, '## 5b. ', '## 6. ');
  final families = _tables(section5b);
  final sizeRows = _sizeTable(section5b);

  final standardSamples = <(ExerciseType, Tier), _Sample>{};
  _Sample standardSample(ExerciseType type, Tier tier) =>
      standardSamples[(type, tier)] ??= _Sample.of(
        (r) => _standardAt(type, tier, r),
      );
  final familySamples = <(PatternFamily, Tier), _Sample>{};
  _Sample familySample(PatternFamily family, Tier tier) =>
      familySamples[(family, tier)] ??= _Sample.of(
        (r) => _familyAt(family, tier, r),
        draws: 10000,
      );

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
      _Sample sampleOf(Tier tier) => standardSample(type, tier);

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
          for (final (text, at) in _familyExamples(examples)) {
            final example = _parse(type, text);
            expect(example.type, type, reason: text);
            final tiers = switch (at) {
              _At.first => [family.from],
              _At.last => [Tier.t9],
              _At.any => Tier.values.skip(family.from.index).toList(),
            };
            final why = <String>[];
            for (final tier in tiers) {
              final missing = familySample(family, tier).missing(example);
              if (missing == null) break;
              why.add('${tier.label}: $missing');
            }
            expect(
              why.length,
              lessThan(tiers.length),
              reason: '$name: $text (${at.name}) — ${why.join('; ')}',
            );
          }
        });
      }
    });
  }

  group('section 5b, size table', () {
    test('every row names a family the test knows how to measure', () {
      expect(sizeRows, isNotEmpty);
      expect(sizeRows.map((r) => r[0]).toSet(), _sizeFamilies.keys.toSet());
    });

    for (final [name, sizes] in sizeRows) {
      final (family, measure) = _sizeFamilies[name]!;
      test('$name (${family.name}): $sizes', () {
        final bands = sizes.startsWith('mirror of powers of 2')
            ? _mirrorBands(sizeRows)
            : _bands(sizes, measure);
        expect(family.from, bands.first.from, reason: 'first entry');
        final limits = <int, int>{};
        for (final (k, band) in bands.indexed) {
          final previous = Map.of(limits);
          limits.addAll(band.limits);
          final end = k + 1 < bands.length ? bands[k + 1].from.index : 10;
          for (final tier in Tier.values.sublist(band.from.index, end)) {
            final seen = <int, (int, int)>{};
            for (var seed = 0; seed < _seeds; seed++) {
              final e = _familyAt(family, tier, Random(seed));
              if (sizes.contains('quotient never below 10')) {
                final d = e as ArithmeticExercise;
                expect(
                  d.operandA ~/ d.operandB,
                  greaterThanOrEqualTo(10),
                  reason: '${tier.label}: $e',
                );
              }
              final measured = measure.of(e);
              if (measured == null) continue;
              final (key, value) = measured;
              final (low, high) = seen[key] ?? (value, value);
              seen[key] = (min(low, value), max(high, value));
              if (band.only5 && e is ArithmeticExercise) {
                expect(e.operandB, 5, reason: '${tier.label}: $e');
              }
            }
            for (final MapEntry(key: key, value: (low, high)) in seen.entries) {
              final reason = '${tier.label}, ${measure.name} $key';
              expect(limits.keys, contains(key), reason: '$reason: no limit');
              // Reaches its band's limit, never above it.
              expect(high, limits[key], reason: '$reason: largest');
              // "√64 to √1 024": the entry's smallest too.
              if (band.low != null) {
                expect(low, band.low, reason: '$reason: smallest');
              }
              // Never a lower band's size, for what this entry grows —
              // unless it names its own smallest.
              if (band.low == null &&
                  band.limits.containsKey(key) &&
                  previous[key] != null) {
                expect(
                  low,
                  greaterThan(previous[key]!),
                  reason: '$reason: smallest',
                );
              }
            }
          }
        }
      });
    }
  });

  group('section 5b, hard limit: at T0–T8 a family outside the size table '
      'never uses more significant digits than the standard questions of '
      'its tier or the next ($_seeds seeds a tier)', () {
    final sized = {for (final (f, _) in _sizeFamilies.values) f};
    for (final family in PatternFamily.values) {
      if (sized.contains(family)) continue;
      test(family.name, () {
        for (final tier in Tier.values.sublist(family.from.index, 9)) {
          final next = Tier.values[tier.index + 1];
          final limit = max(
            _mostSignificant(standardSample(family.type, tier).questions),
            _mostSignificant(standardSample(family.type, next).questions),
          );
          var most = 0;
          Exercise? largest;
          for (var seed = 0; seed < _seeds; seed++) {
            final e = _familyAt(family, tier, Random(seed));
            final size = _significantOf(e);
            if (size > most) (most, largest) = (size, e);
          }
          expect(
            most,
            lessThanOrEqualTo(limit),
            reason: '${tier.label}: $largest, limit $limit',
          );
        }
      });
    }
  });

  group('section 5b, families grow (v1.6): the median answer never '
      'decreases from a tier where the family is drawn to the next, and — '
      'outside the size table — grows at least every two tiers until it '
      'reaches its last size', () {
    final sized = {for (final (f, _) in _sizeFamilies.values) f};
    for (final family in PatternFamily.values) {
      test(family.name, () {
        final tiers = [
          for (final t in Tier.values.skip(family.from.index))
            if (familiesAtV9(family.type, t).contains(family)) t,
        ];
        if (tiers.isEmpty) return; // Skipped everywhere (fewer than 4).
        final medians = {for (final t in tiers) t: _medianAnswer(family, t)};
        for (var i = 0; i + 1 < tiers.length; i++) {
          expect(
            medians[tiers[i + 1]],
            greaterThanOrEqualTo(medians[tiers[i]]!),
            reason: '${tiers[i].label} → ${tiers[i + 1].label}: $medians',
          );
        }
        if (sized.contains(family)) return; // Its bands are the spec's.
        final last = medians[tiers.last]!;
        for (final t in tiers) {
          if (t.index + 2 > 9 || medians[t]! >= last) continue;
          final twoOn = medians[Tier.values[t.index + 2]];
          if (twoOn == null) continue;
          expect(
            twoOn,
            greaterThan(medians[t]!),
            reason: '${t.label} → T${t.index + 2}: $medians',
          );
        }
      });
    }
  });
}

/// A question of [family] at [tier] as the current rules draw it (v9: its
/// space, nothing yet asked).
Exercise _familyAt(PatternFamily family, Tier tier, Random random) =>
    familySpaceV9(family, tier).draw(random, const {});

/// The median answer of [family] at [tier]: every question of a listed
/// space, 2,001 draws of a larger one.
int _medianAnswer(PatternFamily family, Tier tier) {
  final space = familySpaceV9(family, tier);
  final List<int> answers;
  if (space.approximateDistinct <= 30000) {
    answers = [for (final q in space.questions) q.correctAnswer];
  } else {
    final random = Random(1);
    answers = [
      for (var i = 0; i < 2001; i++)
        _familyAt(family, tier, random).correctAnswer,
    ];
  }
  answers.sort();
  return answers[answers.length ~/ 2];
}

/// Seeds per family and tier for the size checks: each question from its
/// own `Random(seed)`.
const _seeds = 3000;

// --- Section 5b: examples and sizes -----------------------------------------

/// Where a family's example must be drawn: "A → B" is A at the family's
/// first tier and B at T9 (the largest size); a plain example at any tier.
enum _At { first, last, any }

/// Examples the spec contradicts elsewhere, checked at any tier instead —
/// each reported to the owner (`doc/decisions.md`, "Phase 6b", commit 1).
/// Once the spec is fixed the key no longer matches, and the example is
/// checked as written again.
List<(String, _At)> _familyExamples(String cell) => [
  for (final text in cell.split(', '))
    if (text.contains(' → '))
      for (final (i, part) in text.split(' → ').indexed)
        (_examples(part).single, i == 0 ? _At.first : _At.last)
    else
      (_examples(text).single, _At.any),
];

/// What a size-table row measures on its family's questions: a key (the
/// base, for powers of 3, 4, 5; 0 otherwise) and a value.
enum _Measure {
  /// The digits of the big number: the factor beside 5 or 50, the
  /// dividend, the base of the percentage.
  digits,

  /// The exponent of a power of 2.
  exponentOf2,

  /// The radicand of a square root.
  radicand,

  /// The exponent, per base.
  exponentPerBase,

  /// The base of a square.
  squareBase,

  /// The upper bound of an integral from 0.
  upperBound,

  /// The root of a round cube (∛8 000 → 20); other questions of the family
  /// (∛1 331) are not measured.
  roundCubeRoot;

  /// What this measures on [e]; `null` when it does not apply to it.
  (int, int)? of(Exercise e) => switch ((this, e)) {
    (digits, ArithmeticExercise(:final operandA)) => (0, _digits(operandA)),
    (digits, PercentageExercise(:final base)) => (0, _digits(base)),
    (exponentOf2, PowerExercise(:final base, :final exponent)) when base == 2 =>
      (0, exponent),
    (radicand, SquareRootExercise(radicand: final n, :final index))
        when index == 2 =>
      (0, n),
    (exponentPerBase, PowerExercise(:final base, :final exponent)) => (
      base,
      exponent,
    ),
    (squareBase, PowerExercise(:final base, :final exponent))
        when exponent == 2 =>
      (0, base),
    (upperBound, IntegralExercise(:final lower, :final upper))
        when lower == 0 =>
      (0, upper),
    (roundCubeRoot, SquareRootExercise(:final index, :final correctAnswer))
        when index == 3 =>
      correctAnswer % 10 == 0 ? (0, correctAnswer) : null,
    _ => throw StateError('$name does not measure $e'),
  };

  /// An entry's limits, per key.
  Map<int, int> limitsIn(String text) => switch (this) {
    digits => {
      0: switch (RegExp(r'(\d+)[- ]digit').firstMatch(text)) {
        final m? => int.parse(m[1]!),
        // "bases 125, 250, 500 (36 % of 250)": the largest named.
        null => _digits(
          RegExp(r'\d[\d ]*\d|\d')
              .allMatches(text.split('(').first)
              .map((m) => _number(m[0]!.trim()))
              .reduce(max),
        ),
      },
    },
    exponentOf2 => {
      0: _script(
        RegExp('2([$_superscripts]+)').firstMatch(text)![1]!,
        _superscripts,
      ),
    },
    exponentPerBase => {
      for (final m in RegExp('([0-9]+)([$_superscripts]+)').allMatches(text))
        int.parse(m[1]!): _script(m[2]!, _superscripts),
    },
    radicand => {0: _number(_roots(text).last)},
    squareBase => {0: int.parse(RegExp('([0-9]+)²').firstMatch(text)![1]!)},
    upperBound => {0: int.parse(RegExp(r'b ≤ (\d+)').firstMatch(text)![1]!)},
    roundCubeRoot => {0: _cubeRanges(text).map((r) => r.$2).reduce(max)},
  };
}

/// The size table's rows, by the spec's name, and what each measures.
final _sizeFamilies = <String, (PatternFamily, _Measure)>{
  '× 5, × 50': (PatternFamily.times5, _Measure.digits),
  'Big numbers ÷ 2': (PatternFamily.halveBig, _Measure.digits),
  'Big numbers ÷ 3, 4, 5': (PatternFamily.bigBy3To5, _Measure.digits),
  'Big numbers ÷ 6, 7, 8, 9': (PatternFamily.bigBy6To9, _Measure.digits),
  '50 %, 25 % of big numbers': (
    PatternFamily.halfAndQuarterOfBig,
    _Measure.digits,
  ),
  'Powers of 2': (PatternFamily.powersOf2, _Measure.exponentOf2),
  '√ of powers of 2 and 4': (PatternFamily.rootsOfPowersOf2, _Measure.radicand),
  'Powers of 3, 4, 5': (PatternFamily.powersOf3To5, _Measure.exponentPerBase),
  'Squares ending in 5': (PatternFamily.squaresEndingIn5, _Measure.squareBase),
  '∫₀ᵇ 2x dx': (PatternFamily.twoXFromZero, _Measure.upperBound),
  '∫₀ᵇ 3x² dx': (PatternFamily.threeXSquaredFromZero, _Measure.upperBound),
  '∫₀ᵇ 4x³ dx': (PatternFamily.fourXCubedFromZero, _Measure.upperBound),
  'Swap (v9)': (PatternFamily.swap, _Measure.digits),
  'Round-number division (v9)': (PatternFamily.roundDivision, _Measure.digits),
  '∛ of round cubes (v9)': (
    PatternFamily.cubeRootsRepunitAndRound,
    _Measure.roundCubeRoot,
  ),
};

/// The ranges of round cubes an entry writes: "(20–90)³ and (200–500)³".
List<(int, int)> _cubeRanges(String text) => [
  for (final m in RegExp(r'\((\d+)–(\d+)\)³').allMatches(text))
    (int.parse(m[1]!), int.parse(m[2]!)),
];

/// "mirror of powers of 2, two tiers later": the Powers of 2 row's bands,
/// two tiers on, each up to the square root of its largest even power.
List<_Band> _mirrorBands(List<List<String>> rows) {
  final powers = rows.firstWhere((r) => r[0] == 'Powers of 2')[1];
  return [
    for (final band in _bands(powers, _Measure.exponentOf2))
      if (band.from.index + 2 <= 9)
        (
          from: Tier.values[band.from.index + 2],
          limits: {0: _powerOf2(band.limits[0]! ~/ 2 * 2)},
          low: null,
          only5: false,
        ),
  ];
}

int _powerOf2(int exponent) {
  var p = 1;
  for (var i = 0; i < exponent; i++) {
    p *= 2;
  }
  return p;
}

/// One entry of a size-table row: from its tier up to the next entry's.
/// [low]: the smallest it draws, when the entry names it ("√64 to
/// √1 024").
typedef _Band = ({Tier from, Map<int, int> limits, int? low, bool only5});

/// "T2: 2-digit × 5 · T4: 3-digit · T6: 4-digit".
/// Entries without a tier ("quotient never below 10") are conditions on
/// the whole row, checked by the row's test.
List<_Band> _bands(String sizes, _Measure measure) => [
  for (final entry in sizes.split(' · '))
    if (RegExp(r'^T(\d): (.+)$').firstMatch(entry.trim()) case final m?)
      (
        from: Tier.values[int.parse(m[1]!)],
        limits: measure.limitsIn(m[2]!),
        low: RegExp('^√[0-9 ]+ to √').hasMatch(m[2]!)
            ? _number(_roots(m[2]!).first)
            : measure == _Measure.roundCubeRoot
            ? _cubeRanges(m[2]!).map((r) => r.$1).reduce(min)
            : null,
        only5: m[2]!.contains('× 5'),
      ),
];

/// The radicands an entry writes ("√64 to √1 024").
List<String> _roots(String text) => [
  for (final m in RegExp(r'√([0-9][0-9 ]*[0-9]|[0-9])').allMatches(text)) m[1]!,
];

/// The size table: its rows' cells (family, size by tier).
List<List<String>> _sizeTable(String section) {
  final part = section
      .split('\n### ')
      .firstWhere((p) => p.startsWith('Size limits'));
  final rows = [
    for (final line in part.split('\n').skip(1))
      if (line.startsWith('|')) _cells(line),
  ];
  return rows.skip(2).toList();
}

/// Significant digits: trailing zeros of a round number don't count
/// (250 000 counts as 25).
int _significant(int n) {
  var m = n.abs();
  if (m == 0) return 1;
  while (m % 10 == 0) {
    m ~/= 10;
  }
  return _digits(m);
}

/// The most significant digits of any number a question shows, or of its
/// answer.
int _significantOf(Exercise e) => [
  ...switch (e) {
    ArithmeticExercise(:final operandA, :final operandB, :final operandC) => [
      operandA,
      operandB,
      ?operandC,
    ],
    PowerExercise(:final base, :final exponent) => [base, exponent],
    SquareRootExercise(:final radicand) => [radicand],
    PercentageExercise(:final percent, :final base) => [percent, base],
    IntegralExercise(:final lower, :final upper, :final coefficients) => [
      lower,
      upper,
      for (final c in coefficients)
        if (c != 0) c,
    ],
  },
  e.correctAnswer,
].map(_significant).reduce(max);

int _mostSignificant(List<Exercise> questions) =>
    questions.map(_significantOf).reduce(max);

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
    // Section 5b's size table is read by `_sizeTable`.
    if (heading.startsWith('Size limits')) continue;
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
  _Sample.of(Exercise? Function(Random) draw, {int draws = _draws}) {
    final random = Random(20261123);
    var newInSecondHalf = 0;
    for (var i = 0; i < draws; i++) {
      final e = draw(random);
      if (e == null) continue;
      questions.add(e);
      if (_seen.add(e) && i >= draws ~/ 2) newInSecondHalf++;
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
  // The base digit by digit: a 6-digit base (25 % of 486 400) has too
  // many values for a sample to hold them all.
  PercentageExercise(:final percent, :final tenths, :final base) => (
    'percentage $percent.$tenths of ${_digits(base)} digits',
    [for (var k = 0; k < _digits(base); k++) _digitAt(base, k)],
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
