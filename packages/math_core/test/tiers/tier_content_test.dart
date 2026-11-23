import 'dart:math';

import 'package:math_core/difficulty/structural_features.dart';
import 'package:math_core/models/exercise.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/models/operation_type.dart';
import 'package:math_core/tiers/tier.dart';
import 'package:math_core/tiers/tier_content.dart';
import 'package:test/test.dart';

/// Draws per tier and operation: enough to reach every form and edge.
const _draws = 3000;

int _digits(int n) => '$n'.length;
bool _isDigits(int n, int digits) => _digits(n) == digits;
int _carries(ArithmeticExercise e) => structuralFeatures(e).carries;
int _borrows(ArithmeticExercise e) => structuralFeatures(e).borrows;

/// Each tier's content under rules v2 and v3 ([exerciseAt]), as a
/// predicate: `doc/levels.md` section 5, except addition and subtraction,
/// an earlier draft's tables (4 digits at most) — the spec's own are
/// `long_arithmetic_tiers_test.dart`'s. The spec file itself is checked by
/// `test/spec/levels_spec_conformance_test.dart`. A question passes when
/// it is of one of the tier's kinds.
typedef _Spec = bool Function(Exercise e);

bool _add(Exercise e, bool Function(int a, int b, ArithmeticExercise e) f) =>
    e is ArithmeticExercise &&
    e.operationType == OperationType.addition &&
    f(e.operandA, e.operandB, e);

bool _sub(Exercise e, bool Function(int a, int b, ArithmeticExercise e) f) =>
    e is ArithmeticExercise &&
    e.operationType == OperationType.subtraction &&
    e.operandA >= e.operandB &&
    f(e.operandA, e.operandB, e);

bool _mul(Exercise e, bool Function(int a, int b) f) =>
    e is ArithmeticExercise &&
    e.operationType == OperationType.multiplication &&
    (f(e.operandA, e.operandB) || f(e.operandB, e.operandA));

bool _div(Exercise e, bool Function(int divisor, int quotient) f) =>
    e is ArithmeticExercise &&
    e.operationType == OperationType.division &&
    e.operandA % e.operandB == 0 &&
    f(e.operandB, e.operandA ~/ e.operandB);

bool _in(int n, int min, int max) => n >= min && n <= max;

bool _pow(Exercise e, bool Function(int base, int exponent) f) =>
    e is PowerExercise && f(e.base, e.exponent);

bool _root(Exercise e, bool Function(int root, int index) f) =>
    e is SquareRootExercise && _exactRoot(e) && f(e.correctAnswer, e.index);

bool _exactRoot(SquareRootExercise e) {
  final r = e.correctAnswer;
  return (e.index == 2 ? r * r : r * r * r) == e.radicand;
}

bool _pct(Exercise e, bool Function(int percent, int tenths, int base) f) =>
    e is PercentageExercise &&
    (e.percent * 10 + e.tenths) * e.base % 1000 == 0 &&
    f(e.percent, e.tenths, e.base);

bool _int(Exercise e, bool Function(IntegralExercise e) f) =>
    e is IntegralExercise && f(e);

/// p's non-zero terms as {power: coefficient}.
Map<int, int> _terms(IntegralExercise e) => {
  for (var k = 0; k < 5; k++)
    if (e.coefficients[k] != 0) k: e.coefficients[k],
};

final Map<ExerciseType, List<_Spec>> _specs = {
  ExerciseType.addition: [
    (e) => _add(e, (a, b, _) => _in(a, 1, 9) && _in(b, 1, 9) && a + b <= 10),
    (e) => _add(e, (a, b, _) => _in(a, 1, 9) && _in(b, 1, 9) && a + b > 10),
    (e) => _add(e, (a, b, _) => _isDigits(a, 2) && _isDigits(b, 1)),
    (e) => _add(
      e,
      (a, b, x) =>
          _isDigits(a, 2) &&
          _isDigits(b, 2) &&
          (_carries(x) == 0 || (a % 10 == 0 && b % 10 == 0)),
    ),
    (e) => _add(
      e,
      (a, b, _) => _isDigits(a, 2) && _isDigits(b, 2) && a % 10 + b % 10 >= 10,
    ),
    (e) => _add(e, (a, b, _) => _isDigits(a, 3) && _isDigits(b, 2)),
    (e) => _add(
      e,
      (a, b, x) =>
          _isDigits(a, 3) &&
          _isDigits(b, 3) &&
          _carries(x) <= 1 &&
          a + b < 1000,
    ),
    (e) => _add(
      e,
      (a, b, x) => _isDigits(a, 3) && _isDigits(b, 3) && _carries(x) >= 2,
    ),
    (e) => _add(e, (a, b, _) => _isDigits(a, 4) && _isDigits(b, 3)),
    (e) => _add(
      e,
      (a, b, x) => _isDigits(a, 4) && _isDigits(b, 4) && _carries(x) >= 2,
    ),
  ],
  ExerciseType.subtraction: [
    (e) => _sub(e, (a, b, _) => a <= 10 && b >= 1 && a - b >= 1),
    (e) => _sub(e, (a, b, _) => _in(a, 11, 19) && _in(b, 1, 9) && a % 10 < b),
    (e) =>
        _sub(e, (a, b, _) => _isDigits(a, 2) && _isDigits(b, 1) && a % 10 < b),
    (e) => _sub(
      e,
      (a, b, x) =>
          _isDigits(a, 2) &&
          _isDigits(b, 2) &&
          (_borrows(x) == 0 || (a % 10 == 0 && b % 10 == 0)),
    ),
    (e) => _sub(
      e,
      (a, b, _) => _isDigits(a, 2) && _isDigits(b, 2) && a % 10 < b % 10,
    ),
    (e) => _sub(e, (a, b, _) => _isDigits(a, 3) && _isDigits(b, 2)),
    (e) => _sub(
      e,
      (a, b, x) => _isDigits(a, 3) && _isDigits(b, 3) && _borrows(x) <= 1,
    ),
    (e) => _sub(
      e,
      (a, b, x) => _isDigits(a, 3) && _isDigits(b, 3) && _borrows(x) >= 2,
    ),
    (e) => _sub(e, (a, b, _) => _isDigits(a, 4) && _isDigits(b, 3)),
    (e) => _sub(
      e,
      (a, b, x) => _isDigits(a, 4) && _isDigits(b, 4) && _borrows(x) >= 2,
    ),
  ],
  ExerciseType.multiplication: [
    (e) => _mul(e, (t, m) => _in(t, 1, 5) && _in(m, 1, 10)),
    (e) => _mul(e, (t, m) => _in(t, 6, 10) && _in(m, 1, 10)),
    (e) => _mul(
      e,
      (a, b) =>
          (_in(a, 10, 15) || (a % 10 == 0 && _in(a, 10, 90))) && _in(b, 1, 9),
    ),
    (e) => _mul(
      e,
      (a, b) =>
          (_in(a, 16, 25) && _in(b, 2, 9)) || (_isDigits(a, 2) && b == 11),
    ),
    (e) => _mul(e, (a, b) => _isDigits(a, 2) && _in(b, 2, 9)),
    (e) => _mul(
      e,
      (a, b) =>
          (_in(a, 11, 19) && _in(b, 11, 19)) ||
          (_isDigits(a, 2) && [5, 25, 50].contains(b)),
    ),
    (e) => _mul(
      e,
      (a, b) =>
          (_in(a, 11, 40) && _in(b, 11, 40)) ||
          (a % 10 == 0 && _in(a, 20, 90) && _isDigits(b, 2)),
    ),
    (e) => _mul(e, (a, b) => _isDigits(a, 3) && _in(b, 2, 9)),
    (e) => _mul(e, (a, b) => _isDigits(a, 2) && _isDigits(b, 2)),
    (e) => _mul(e, (a, b) => _in(a, 100, 250) && _in(b, 10, 50)),
  ],
  ExerciseType.division: [
    (e) => _div(e, (d, q) => _in(d, 1, 5) && _in(q, 1, 10)),
    (e) => _div(e, (d, q) => _in(d, 6, 10) && _in(q, 1, 10)),
    (e) => _div(
      e,
      (d, q) => _in(d, 2, 9) && (_in(q, 10, 15) || (q % 10 == 0 && q <= 90)),
    ),
    (e) => _div(e, (d, q) => _in(d, 2, 9) && _in(q, 16, 25)),
    (e) => _div(e, (d, q) => _in(d, 2, 9) && _isDigits(d * q, 3)),
    (e) => _div(e, (d, q) => _in(d, 11, 19) || [5, 25, 50].contains(d)),
    (e) => _div(e, (d, q) => _in(d, 11, 40) && _isDigits(d * q, 3)),
    (e) => _div(e, (d, q) => _in(d, 2, 9) && _isDigits(d * q, 4)),
    (e) => _div(e, (d, q) => _isDigits(d, 2) && _isDigits(d * q, 4)),
    (e) =>
        _div(e, (d, q) => _isDigits(d, 2) && _isDigits(d * q, 4) && q >= 100),
  ],
  ExerciseType.power: [
    (e) => _pow(e, (b, x) => x == 2 && _in(b, 1, 10)),
    (e) => _pow(
      e,
      (b, x) => (x == 2 && _in(b, 11, 15)) || (b == 2 && _in(x, 1, 6)),
    ),
    (e) => _pow(
      e,
      (b, x) => (x == 2 && _in(b, 16, 20)) || (x == 3 && _in(b, 1, 5)),
    ),
    (e) => _pow(
      e,
      (b, x) => x == 2 && _in(b, 10, 95) && (b % 10 == 5 || b % 10 == 0),
    ),
    (e) => _pow(
      e,
      (b, x) => (x == 2 && _in(b, 21, 30)) || (b == 2 && _in(x, 7, 10)),
    ),
    (e) => _pow(
      e,
      (b, x) => (x == 2 && _in(b, 31, 50)) || (x == 3 && _in(b, 6, 10)),
    ),
    (e) => _pow(
      e,
      (b, x) => (x == 2 && _in(b, 51, 70)) || (b == 3 && _in(x, 1, 6)),
    ),
    (e) => _pow(e, (b, x) => x == 2 && _in(b, 71, 100)),
    (e) => _pow(
      e,
      (b, x) => (x == 2 && _in(b, 101, 125)) || (x == 3 && _in(b, 11, 15)),
    ),
    (e) => _pow(
      e,
      (b, x) => (x == 2 && _in(b, 126, 200)) || (x == 4 && _in(b, 5, 7)),
    ),
  ],
  ExerciseType.squareRoot: [
    (e) => _root(e, (r, i) => i == 2 && _in(r, 1, 10)),
    (e) => _root(e, (r, i) => i == 2 && _in(r, 11, 15)),
    (e) => _root(
      e,
      (r, i) => (i == 2 && _in(r, 16, 20)) || (i == 3 && _in(r, 1, 5)),
    ),
    (e) => _root(
      e,
      (r, i) => i == 2 && _in(r, 10, 95) && (r % 10 == 5 || r % 10 == 0),
    ),
    (e) => _root(e, (r, i) => i == 2 && _in(r, 21, 30)),
    (e) => _root(
      e,
      (r, i) => (i == 2 && _in(r, 31, 50)) || (i == 3 && _in(r, 6, 10)),
    ),
    (e) => _root(e, (r, i) => i == 2 && _in(r, 51, 70)),
    (e) => _root(e, (r, i) => i == 2 && _in(r, 71, 100)),
    (e) => _root(
      e,
      (r, i) => (i == 2 && _in(r, 101, 125)) || (i == 3 && _in(r, 11, 15)),
    ),
    (e) => _root(e, (r, i) => i == 2 && _in(r, 126, 200)),
  ],
  ExerciseType.percentage: [
    (e) => _pct(
      e,
      (p, t, b) => [50, 10].contains(p) && t == 0 && b % 10 == 0 && b <= 100,
    ),
    (e) => _pct(e, (p, t, b) => [25, 20].contains(p) && t == 0 && b % 10 == 0),
    (e) => _pct(
      e,
      (p, t, b) => [10, 20, 50].contains(p) && t == 0 && _in(b, 10, 999),
    ),
    (e) => _pct(e, (p, t, b) => [5, 75].contains(p) && t == 0),
    (e) => _pct(
      e,
      (p, t, b) => [1, 15, 30, 40].contains(p) && t == 0 && b % 100 == 0,
    ),
    (e) => _pct(e, (p, t, b) => p % 5 == 0 && _in(p, 5, 95) && t == 0),
    (e) => _pct(e, (p, t, b) => _in(p, 1, 99) && t == 0 && b % 100 == 0),
    (e) => _pct(e, (p, t, b) => [12, 37, 62, 87].contains(p) && t == 5),
    (e) => _pct(e, (p, t, b) => p > 100 && t == 0 && _isDigits(b, 2)),
    (e) => _pct(e, (p, t, b) => _in(p, 1, 99) && t == 0 && _isDigits(b, 3)),
  ],
  ExerciseType.integral: [
    (e) => _int(
      e,
      (x) =>
          x.lower == 0 &&
          _terms(x).keys.toSet().containsAll({0}) &&
          _terms(x).length == 1,
    ),
    (e) => _int(
      e,
      (x) => x.lower == 0 && _terms(x).length == 1 && _terms(x)[1] == 2,
    ),
    (e) => _int(
      e,
      (x) => x.lower > 0 && _terms(x).length == 1 && _terms(x)[1] == 2,
    ),
    (e) => _int(
      e,
      (x) =>
          x.lower == 0 &&
          _terms(x).length == 2 &&
          _terms(x)[1] == 2 &&
          _terms(x)[0]! > 0,
    ),
    (e) => _int(
      e,
      (x) => x.lower == 0 && _terms(x).length == 1 && _terms(x)[2] == 3,
    ),
    (e) => _int(
      e,
      (x) => x.lower > 0 && _terms(x).length == 1 && _terms(x)[2] == 3,
    ),
    (e) => _int(
      e,
      (x) =>
          _terms(x).keys.toSet().containsAll({2, 1}) && _terms(x).length == 2,
    ),
    (e) => _int(
      e,
      (x) => x.lower <= 1 && _terms(x).length == 1 && _terms(x)[3] == 4,
    ),
    (e) => _int(
      e,
      (x) =>
          _terms(x).containsKey(3) &&
          _terms(x).length >= 2 &&
          !_terms(x).containsKey(4),
    ),
    (e) => _int(
      e,
      (x) =>
          (_terms(x).containsKey(3) || _terms(x).containsKey(4)) &&
          _terms(x).length == 2,
    ),
  ],
};

/// One example per tier, as the question each one is: the spec's, except
/// for addition and subtraction (the earlier draft's).
final Map<ExerciseType, List<Exercise>> _examples = {
  ExerciseType.addition: [
    for (final (a, b) in [
      (4, 5),
      (8, 7),
      (47, 8),
      (34, 52),
      (47, 38),
      (347, 58),
      (342, 251),
      (478, 365),
      (2468, 785),
      (4789, 3657),
    ])
      ArithmeticExercise(
        operandA: a,
        operandB: b,
        operationType: OperationType.addition,
      ),
  ],
  ExerciseType.subtraction: [
    for (final (a, b) in [
      (9, 4),
      (15, 7),
      (43, 7),
      (86, 34),
      (72, 38),
      (342, 67),
      (685, 243),
      (403, 178),
      (3042, 687),
      (7003, 2468),
    ])
      ArithmeticExercise(
        operandA: a,
        operandB: b,
        operationType: OperationType.subtraction,
      ),
  ],
  ExerciseType.multiplication: [
    for (final (a, b) in [
      (4, 7),
      (8, 7),
      (13, 6),
      (24, 7),
      (87, 6),
      (14, 17),
      (23, 34),
      (347, 6),
      (67, 84),
      (125, 36),
    ])
      ArithmeticExercise(
        operandA: a,
        operandB: b,
        operationType: OperationType.multiplication,
      ),
  ],
  ExerciseType.division: [
    for (final (a, b) in [
      (28, 4),
      (56, 8),
      (78, 6),
      (168, 7),
      (522, 6),
      (238, 14),
      (782, 34),
      (2082, 6),
      (5628, 67),
      (4500, 36),
    ])
      ArithmeticExercise(
        operandA: a,
        operandB: b,
        operationType: OperationType.division,
      ),
  ],
  ExerciseType.power: [
    for (final (b, x) in [
      (7, 2),
      (13, 2),
      (18, 2),
      (35, 2),
      (27, 2),
      (46, 2),
      (58, 2),
      (87, 2),
      (112, 2),
      (175, 2),
    ])
      PowerExercise(base: b, exponent: x),
  ],
  ExerciseType.squareRoot: [
    for (final (r, i) in [
      (49, 2),
      (169, 2),
      (324, 2),
      (1225, 2),
      (729, 2),
      (2116, 2),
      (3364, 2),
      (7569, 2),
      (12544, 2),
      (30625, 2),
    ])
      SquareRootExercise(radicand: r, index: i),
  ],
  ExerciseType.percentage: [
    PercentageExercise(percent: 50, base: 80),
    PercentageExercise(percent: 25, base: 120),
    PercentageExercise(percent: 20, base: 350),
    PercentageExercise(percent: 75, base: 64),
    PercentageExercise(percent: 15, base: 600),
    PercentageExercise(percent: 35, base: 140),
    PercentageExercise(percent: 37, base: 300),
    PercentageExercise(percent: 37, tenths: 5, base: 64),
    PercentageExercise(percent: 150, base: 86),
    PercentageExercise(percent: 64, base: 175),
  ],
  ExerciseType.integral: [
    IntegralExercise(lower: 0, upper: 4, c0: 3, c1: 0, c2: 0, c3: 0),
    IntegralExercise(lower: 0, upper: 3, c0: 0, c1: 2, c2: 0, c3: 0),
    IntegralExercise(lower: 2, upper: 5, c0: 0, c1: 2, c2: 0, c3: 0),
    IntegralExercise(lower: 0, upper: 3, c0: 4, c1: 2, c2: 0, c3: 0),
    IntegralExercise(lower: 0, upper: 3, c0: 0, c1: 0, c2: 3, c3: 0),
    IntegralExercise(lower: 1, upper: 3, c0: 0, c1: 0, c2: 3, c3: 0),
    IntegralExercise(lower: 0, upper: 2, c0: 0, c1: 2, c2: 3, c3: 0),
    IntegralExercise(lower: 1, upper: 2, c0: 0, c1: 0, c2: 0, c3: 4),
    IntegralExercise(lower: 0, upper: 2, c0: 0, c1: 6, c2: 0, c3: 4),
    IntegralExercise(lower: 1, upper: 3, c0: 0, c1: 0, c2: -3, c3: 0, c4: 5),
  ],
};

void main() {
  test('every type has ten tiers of specs and examples', () {
    for (final type in ExerciseType.values) {
      expect(_specs[type], hasLength(10), reason: type.name);
      expect(_examples[type], hasLength(10), reason: type.name);
    }
  });

  for (final type in ExerciseType.values) {
    group(type.name, () {
      for (final tier in Tier.values) {
        test('${tier.label}: every question is of its kind, whole and exact; '
            'its example is too', () {
          final spec = _specs[type]![tier.index];
          expect(
            spec(_examples[type]![tier.index]),
            isTrue,
            reason: 'example ${_examples[type]![tier.index]}',
          );
          final random = Random(7919 * (type.index + 1) + tier.index);
          for (var i = 0; i < _draws; i++) {
            final e = exerciseAt(type, tier, random);
            expect(e.type, type);
            expect(spec(e), isTrue, reason: '${tier.label} drew ${_show(e)}');
            // Whole, never negative.
            expect(e.correctAnswer, greaterThanOrEqualTo(0), reason: _show(e));
          }
        });
      }
    });
  }

  test("the spec's integral example is 216, and its integrand stays ≥ 0", () {
    final e = _examples[ExerciseType.integral]![9] as IntegralExercise;
    expect(e.correctAnswer, 216);
  });

  test('every form of a two-form tier appears', () {
    // A sample of tiers with two kinds: both show up in 3000 draws.
    final random = Random(1);
    final draws = [
      for (var i = 0; i < _draws; i++)
        exerciseAt(ExerciseType.power, Tier.t1, random) as PowerExercise,
    ];
    expect(draws.any((p) => p.base == 2 && p.exponent != 2), isTrue);
    expect(draws.any((p) => p.exponent == 2 && p.base >= 11), isTrue);
    final roots = [
      for (var i = 0; i < _draws; i++)
        exerciseAt(ExerciseType.squareRoot, Tier.t8, random)
            as SquareRootExercise,
    ];
    expect(roots.any((r) => r.index == 3), isTrue);
    expect(roots.any((r) => r.index == 2), isTrue);
    final integrals = [
      for (var i = 0; i < _draws; i++)
        exerciseAt(ExerciseType.integral, Tier.t9, random) as IntegralExercise,
    ];
    expect(integrals.any((x) => x.coefficients.any((c) => c < 0)), isTrue);
    final subtractions = [
      for (var i = 0; i < _draws; i++)
        exerciseAt(ExerciseType.subtraction, Tier.t7, random)
            as ArithmeticExercise,
    ];
    expect(subtractions.any((s) => s.operandA ~/ 10 % 10 == 0), isTrue);
  });
}

String _show(Exercise e) => switch (e) {
  ArithmeticExercise(:final operandA, :final operandB, :final operationType) =>
    '$operandA ${operationType.name} $operandB',
  PowerExercise(:final base, :final exponent) => '$base^$exponent',
  SquareRootExercise(:final radicand, :final index) => 'root$index($radicand)',
  PercentageExercise(:final percent, :final tenths, :final base) =>
    '$percent.$tenths% of $base',
  IntegralExercise(:final lower, :final upper, :final coefficients) =>
    'int[$lower,$upper] $coefficients',
};
