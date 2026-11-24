import '../models/exercise.dart';
import '../models/exercise_type.dart';
import '../models/operation_type.dart';
import '../tiers/power_tiers.dart';
import '../tiers/tier.dart';
import 'item.dart';

/// The fact [exercise] is, if it is one of the catalogue's (plan v3.5,
/// `doc/decisions.md` "Phase 4"); `null` otherwise. Commutative facts share
/// one entry: 7 × 8 and 8 × 7, 7 + 8 and 8 + 7.
FactItem? factOf(Exercise exercise) {
  final (type, numbers) = switch (exercise) {
    ArithmeticExercise(operandC: _?) => (ExerciseType.addition, null),
    ArithmeticExercise(
      :final operandA,
      :final operandB,
      :final operationType,
    ) =>
      switch (operationType) {
        OperationType.addition || OperationType.multiplication => (
          exercise.type,
          operandA <= operandB ? [operandA, operandB] : [operandB, operandA],
        ),
        OperationType.subtraction ||
        OperationType.division => (exercise.type, [operandA, operandB]),
      },
    PowerExercise(:final base, :final exponent) => (
      ExerciseType.power,
      [base, exponent],
    ),
    SquareRootExercise(:final index, :final radicand) => (
      ExerciseType.squareRoot,
      [index, radicand],
    ),
    PercentageExercise(:final percent, :final base, :final tenths) => (
      ExerciseType.percentage,
      tenths == 0 ? [percent, base] : null,
    ),
    IntegralExercise() => (ExerciseType.integral, null),
  };
  if (numbers == null || !isCanonicalFact(type, numbers)) return null;
  return FactItem(type, numbers);
}

/// Every question that asks [fact]: both orders of a commutative fact.
List<Exercise> exercisesOf(FactItem fact) {
  final n = fact.numbers;
  ArithmeticExercise arithmetic(int a, int b, OperationType op) =>
      ArithmeticExercise(operandA: a, operandB: b, operationType: op);
  return switch (fact.type) {
    ExerciseType.addition => [
      arithmetic(n[0], n[1], OperationType.addition),
      if (n[0] != n[1]) arithmetic(n[1], n[0], OperationType.addition),
    ],
    ExerciseType.multiplication => [
      arithmetic(n[0], n[1], OperationType.multiplication),
      if (n[0] != n[1]) arithmetic(n[1], n[0], OperationType.multiplication),
    ],
    ExerciseType.subtraction => [
      arithmetic(n[0], n[1], OperationType.subtraction),
    ],
    ExerciseType.division => [arithmetic(n[0], n[1], OperationType.division)],
    ExerciseType.power => [PowerExercise(base: n[0], exponent: n[1])],
    ExerciseType.squareRoot => [
      SquareRootExercise(index: n[0], radicand: n[1]),
    ],
    ExerciseType.percentage => [PercentageExercise(percent: n[0], base: n[1])],
    ExerciseType.integral => throw StateError('no integral fact'),
  };
}

/// The whole catalogue, by operation then key.
final List<FactItem> allFacts = () {
  final facts = <FactItem>[
    for (var a = 1; a <= 99; a++)
      for (var b = a; b <= 99; b++)
        if (a + b <= 20 || a + b == 100)
          FactItem(ExerciseType.addition, [a, b]),
    for (final s in [for (var s = 2; s <= 20; s++) s, 100])
      for (var a = 1; a < s; a++) FactItem(ExerciseType.subtraction, [s, a]),
    for (var a = 1; a <= 20; a++)
      for (var b = a; b <= 20; b++)
        FactItem(ExerciseType.multiplication, [a, b]),
    for (var divisor = 1; divisor <= 20; divisor++)
      for (var q = 1; q <= 20; q++)
        FactItem(ExerciseType.division, [divisor * q, divisor]),
    for (var b = 1; b <= 30; b++) FactItem(ExerciseType.power, [b, 2]),
    for (var b = 1; b <= 10; b++) FactItem(ExerciseType.power, [b, 3]),
    for (var e = 1; e <= 12; e++)
      if (e != 2 && e != 3) FactItem(ExerciseType.power, [2, e]),
    for (final r in [for (var r = 1; r <= 30; r++) r, 32, 64])
      FactItem(ExerciseType.squareRoot, [2, r * r]),
    for (var r = 1; r <= 10; r++)
      FactItem(ExerciseType.squareRoot, [3, r * r * r]),
    for (final p in friendlyFactPercents)
      for (var base = 10; base <= 1000; base += 10)
        if (p * base % 100 == 0) FactItem(ExerciseType.percentage, [p, base]),
  ];
  return List<FactItem>.unmodifiable(
    facts..sort((a, b) {
      final byType = a.type.index - b.type.index;
      return byType != 0 ? byType : a.compareTo(b);
    }),
  );
}();

/// The questions of [type] that are facts and that [tier]'s **standard**
/// questions draw (`doc/levels.md` section 5 under rules v4 and later,
/// `standardQuestionV4`) — what "a fact of the current tier" means
/// (`doc/decisions.md`, "Phase 4"). Built from the section 5 tables, range
/// by range; `fact_tiers_test.dart` checks it against the generator both
/// ways. Fixed order: the tables'.
List<Exercise> factsAt(ExerciseType type, Tier tier) =>
    _factsAt[type]![tier.index];

/// The questions of [fact] that [tier] draws: empty when the fact is not
/// one of that tier's.
List<Exercise> formsAt(FactItem fact, Tier tier) => [
  for (final exercise in factsAt(fact.type, tier))
    if (factOf(exercise) == fact) exercise,
];

/// The lowest tier whose standard questions draw [fact]; `null` for a fact
/// no tier draws as a standard question (2¹¹, 2¹², percentages of 1 000):
/// such a fact is never keyed, so never scheduled.
Tier? homeTier(FactItem fact) => _homeTiers[fact];

final Map<FactItem, Tier> _homeTiers = () {
  final homes = <FactItem, Tier>{};
  for (final type in ExerciseType.values) {
    for (final tier in Tier.values) {
      for (final exercise in factsAt(type, tier)) {
        homes.putIfAbsent(factOf(exercise)!, () => tier);
      }
    }
  }
  return homes;
}();

final Map<ExerciseType, List<List<Exercise>>> _factsAt = {
  for (final type in ExerciseType.values)
    type: List.unmodifiable([
      for (final tier in Tier.values)
        // A set keeps the first of each (insertion order, deterministic):
        // the either-order tables list a question twice.
        List<Exercise>.unmodifiable({
          for (final exercise in _standardCandidates(type, tier))
            if (factOf(exercise) != null) exercise,
        }),
    ]),
};

Iterable<int> _range(int min, int max) sync* {
  for (var i = min; i <= max; i++) {
    yield i;
  }
}

ArithmeticExercise _op(int a, int b, OperationType op) =>
    ArithmeticExercise(operandA: a, operandB: b, operationType: op);

int _ceilDiv(int a, int b) => (a + b - 1) ~/ b;

/// What a tier's standard questions can draw, in the generators' ranges —
/// where facts can be; the tiers where none can be draw nothing here (the
/// test samples them too). Mirrors `longArithmeticAt`, `arithmeticAt`,
/// `powerAt`, `rootAt` and `percentageAt`.
Iterable<Exercise> _standardCandidates(ExerciseType type, Tier tier) sync* {
  const add = OperationType.addition;
  const sub = OperationType.subtraction;
  const mul = OperationType.multiplication;
  const div = OperationType.division;
  switch (type) {
    case ExerciseType.addition:
      switch (tier) {
        case Tier.t0:
          for (final a in _range(1, 9)) {
            for (final b in _range(1, 10 - a)) {
              yield _op(a, b, add);
            }
          }
        case Tier.t1:
          for (final a in _range(2, 9)) {
            for (final b in _range(11 - a, 9)) {
              yield _op(a, b, add);
            }
          }
          for (final a in _range(10, 99)) {
            for (final b in _range(1, 9)) {
              yield _op(a, b, add);
            }
          }
        case Tier.t2:
          // 2-digit + 2-digit with a carry from the units.
          for (final ua in _range(1, 9)) {
            for (final ub in _range(10 - ua, 9)) {
              for (final ta in _range(1, 9)) {
                for (final tb in _range(1, 9)) {
                  yield _op(10 * ta + ua, 10 * tb + ub, add);
                }
              }
            }
          }
        case Tier.t3 ||
            Tier.t4 ||
            Tier.t5 ||
            Tier.t6 ||
            Tier.t7 ||
            Tier.t8 ||
            Tier.t9:
          // 3 digits and more: sums above 100.
          break;
      }
    case ExerciseType.subtraction:
      switch (tier) {
        case Tier.t0:
          for (final a in _range(2, 10)) {
            for (final b in _range(1, a - 1)) {
              yield _op(a, b, sub);
            }
          }
        case Tier.t1:
          for (final u in _range(1, 8)) {
            for (final b in _range(u + 1, 9)) {
              yield _op(10 + u, b, sub);
            }
          }
          for (final t in _range(2, 9)) {
            for (final u in _range(0, 8)) {
              for (final b in _range(u + 1, 9)) {
                yield _op(10 * t + u, b, sub);
              }
            }
          }
        case Tier.t2:
          for (final ua in _range(0, 8)) {
            for (final ub in _range(ua + 1, 9)) {
              for (final ta in _range(2, 9)) {
                for (final tb in _range(1, ta - 1)) {
                  yield _op(10 * ta + ua, 10 * tb + ub, sub);
                }
              }
            }
          }
        case Tier.t3:
          // Across a zero, a 2-digit subtrahend: 100 − 37 with a hundreds
          // digit of 1 (the 3-digit subtrahends start from 200).
          for (final ua in _range(0, 8)) {
            for (final ub in _range(ua + 1, 9)) {
              for (final t in _range(1, 9)) {
                for (final h in _range(1, 9)) {
                  yield _op(100 * h + ua, 10 * t + ub, sub);
                }
              }
            }
          }
        case Tier.t4 || Tier.t5 || Tier.t6 || Tier.t7 || Tier.t8 || Tier.t9:
          // 4-digit minuends and more.
          break;
      }
    case ExerciseType.multiplication:
      Iterable<ArithmeticExercise> grid(
        Iterable<int> as,
        Iterable<int> bs,
      ) sync* {
        for (final a in as) {
          for (final b in bs) {
            yield _op(a, b, mul);
          }
        }
      }
      switch (tier) {
        case Tier.t0:
          yield* grid(_range(1, 5), _range(1, 10));
          yield* grid(_range(1, 10), _range(1, 5));
        case Tier.t1:
          yield* grid(_range(6, 10), _range(1, 10));
          yield* grid(_range(1, 10), _range(6, 10));
        case Tier.t2:
          yield* grid(_range(10, 15), _range(1, 9));
          yield* grid([for (final k in _range(1, 9)) 10 * k], _range(1, 9));
        case Tier.t3:
          yield* grid(_range(16, 25), _range(2, 9));
          yield* grid(_range(10, 99), [11]);
        case Tier.t4:
          yield* grid(_range(10, 99), _range(2, 9));
        case Tier.t5:
          yield* grid(_range(11, 19), _range(11, 19));
          yield* grid(_range(10, 99), const [5, 25, 50]);
        case Tier.t6:
          yield* grid(_range(11, 40), _range(11, 40));
          yield* grid([for (final k in _range(2, 9)) 10 * k], _range(11, 99));
        case Tier.t8:
          yield* grid(_range(10, 99), _range(10, 99));
        case Tier.t7 || Tier.t9:
          // 3-digit factors.
          break;
      }
    case ExerciseType.division:
      Iterable<ArithmeticExercise> quotients(
        Iterable<int> divisors,
        Iterable<int> Function(int divisor) qs,
      ) sync* {
        for (final d in divisors) {
          for (final q in qs(d)) {
            yield _op(d * q, d, div);
          }
        }
      }
      switch (tier) {
        case Tier.t0:
          yield* quotients(_range(1, 5), (_) => _range(1, 10));
        case Tier.t1:
          yield* quotients(_range(6, 10), (_) => _range(1, 10));
        case Tier.t2:
          yield* quotients(_range(2, 9), (_) => _range(10, 15));
          yield* quotients(
            _range(2, 9),
            (_) => [for (final k in _range(1, 9)) 10 * k],
          );
        case Tier.t3:
          yield* quotients(_range(2, 9), (_) => _range(16, 25));
        case Tier.t4:
          yield* quotients(
            _range(2, 9),
            (d) => _range(_ceilDiv(100, d), 999 ~/ d),
          );
        case Tier.t5:
          yield* quotients(_range(11, 19), (_) => _range(11, 19));
          yield* quotients(const [5, 25, 50], (_) => _range(10, 99));
        case Tier.t6:
          yield* quotients(
            _range(11, 40),
            (d) => _range(_ceilDiv(100, d), 999 ~/ d),
          );
        case Tier.t7 || Tier.t8 || Tier.t9:
          // Quotients above 50.
          break;
      }
    case ExerciseType.power:
      yield* powerSupport(tier);
    case ExerciseType.squareRoot:
      yield* rootSupport(tier);
    case ExerciseType.percentage:
      PercentageExercise pct(int p, int base) =>
          PercentageExercise(percent: p, base: base);
      // `percentageAt`'s bases: multiples of 100 / gcd(p, 100) (and of
      // [roundTo]) in [min, max].
      Iterable<PercentageExercise> whole(
        Iterable<int> percents,
        int min,
        int max, {
        int roundTo = 1,
      }) sync* {
        for (final p in percents) {
          final step = _lcm(100 ~/ _gcd(p, 100), roundTo);
          for (var k = _ceilDiv(min, step); k <= max ~/ step; k++) {
            yield pct(p, step * k);
          }
        }
      }
      switch (tier) {
        case Tier.t0:
          for (final p in const [50, 10]) {
            for (final k in _range(1, 10)) {
              yield pct(p, 10 * k);
            }
          }
        case Tier.t1:
          yield* whole(const [25, 20], 10, 200, roundTo: 10);
        case Tier.t2:
          yield* whole(const [10, 20, 50], 10, 999);
        case Tier.t3:
          yield* whole(const [5, 75], 10, 400);
        case Tier.t5:
          yield* whole([for (var p = 5; p <= 95; p += 5) p], 20, 400);
        case Tier.t6:
          for (final p in _range(1, 99)) {
            for (final k in _range(1, 9)) {
              yield pct(p, 100 * k);
            }
          }
        case Tier.t9:
          yield* whole(_range(1, 99), 100, 999);
        case Tier.t4 || Tier.t7 || Tier.t8:
          // 1, 15, 30, 40 %; eighths; above 100 %: none friendly.
          break;
      }
    case ExerciseType.integral:
      break;
  }
}

int _gcd(int a, int b) => b == 0 ? a : _gcd(b, a % b);

int _lcm(int a, int b) => a ~/ _gcd(a, b) * b;
