import 'package:math_core/duel/duel_config.dart';
import 'package:math_core/leveling/level.dart';
import 'package:math_core/leveling/rules_version.dart';
import 'package:math_core/models/exercise.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/persistence/exercise_codec.dart';
import 'package:test/test.dart';

/// One line per question, as pinned below.
List<String> _lines(DuelConfig config) => [
  for (final q in config.questions())
    () {
      final d = describeExerciseForStorage(q);
      return '${d.operationType} ${d.operands.values.join(' ')} = '
          '${q.correctAnswer}';
    }(),
];

/// Rules v3: the pins below were recorded under it.
DuelConfig _standard(int seed, int bracket) => DuelConfig(
  seed: seed,
  quotas: standardDuelQuotas,
  bracket: bracket,
  rulesVersion: RulesVersion.v3,
);

/// Phase 5.2 commit 2 (Phase 7 commit 1): a duel's questions depend on
/// (seed, config) only — pinned here, and this file runs on the VM and
/// compiled to JavaScript like every core test, so both players' browsers
/// and the server draw the same questions.
void main() {
  // Recorded on the VM — first when the duel configuration was written,
  // again on purpose at the Levels phase's commit 4, when duels moved to
  // the tiers of `doc/levels.md` (no duel was stored yet). Never regenerate
  // to make a JavaScript failure pass: a difference is a bug.
  const pinned = {
    (1, 7): [
      'addition 16 68 = 84',
      'division 518 2 = 259',
      'squareRoot 529 = 23',
      'percentage 5 180 = 9',
      'multiplication 24 7 = 168',
      'subtraction 70 18 = 52',
      'division 84 4 = 21',
      'power 2 7 = 128',
      'subtraction 51 20 = 31',
      'percentage 30 300 = 90',
      'multiplication 78 2 = 156',
      'addition 50 60 = 110',
    ],
    (20261120, 0): [
      'power 6 2 = 36',
      'division 16 4 = 4',
      'percentage 50 30 = 15',
      'squareRoot 16 = 4',
      'addition 2 6 = 8',
      'subtraction 5 3 = 2',
      'addition 6 3 = 9',
      'subtraction 3 2 = 1',
      'multiplication 1 4 = 4',
      'percentage 10 50 = 5',
      'multiplication 5 5 = 25',
      'division 4 4 = 1',
    ],
    (987654321, 14): [
      'addition 568 832 = 1400',
      'subtraction 904 577 = 327',
      'addition 609 329 = 938',
      'division 855 15 = 57',
      'percentage 91 400 = 364',
      'percentage 12 64 5 = 8',
      'division 3950 2 = 1975',
      'multiplication 269 5 = 1345',
      'subtraction 503 303 = 200',
      'squareRoot 5625 = 75',
      'multiplication 20 41 = 820',
      'power 83 2 = 6889',
    ],
  };

  test('same (seed, config): the pinned questions, VM and JavaScript', () {
    for (final MapEntry(key: (seed, bracket), value: expected)
        in pinned.entries) {
      expect(_lines(_standard(seed, bracket)), expected, reason: '$seed');
    }
  });

  test('asked twice, the same questions; another seed, others', () {
    expect(_lines(_standard(42, 7)), _lines(_standard(42, 7)));
    expect(_lines(_standard(43, 7)), isNot(_lines(_standard(42, 7))));
  });

  test('fixed quotas: exactly that many of each type', () {
    final config = _standard(7, 7);
    final sequence = config.typeSequence();
    expect(sequence.length, 12);
    for (final type in ExerciseType.values) {
      expect(
        sequence.where((t) => t == type).length,
        standardDuelQuotas[type] ?? 0,
        reason: type.name,
      );
    }
    // The questions follow the sequence.
    expect([for (final q in config.questions()) q.type], sequence);
    // A type at 0 or absent is never asked.
    final sums = DuelConfig(
      seed: 7,
      quotas: {ExerciseType.addition: 3, ExerciseType.division: 0},
      bracket: 7,
    );
    expect(sums.questions().map((q) => q.type).toSet(), {
      ExerciseType.addition,
    });
  });

  test('the shuffle mixes the types (not grouped by type)', () {
    final sequences = {
      for (var seed = 0; seed < 20; seed++)
        _standard(seed, 7).typeSequence().join(','),
    };
    expect(sequences.length, greaterThan(15));
  });

  test('difficulty comes from the bracket alone', () {
    // No level of any player goes in: the config has none to take.
    expect(_standard(1, 0).level, Level.whole(5));
    expect(_standard(1, 7).level, Level.whole(40));
    expect(_standard(1, 14).level, Level.whole(75));
    int largestSum(int bracket) {
      var largest = 0;
      for (var seed = 0; seed < 30; seed++) {
        for (final q in DuelConfig(
          seed: seed,
          quotas: {ExerciseType.addition: 5},
          bracket: bracket,
        ).questions()) {
          final a = q as ArithmeticExercise;
          final top = a.operandA > a.operandB ? a.operandA : a.operandB;
          if (top > largest) largest = top;
        }
      }
      return largest;
    }

    expect(largestSum(14), greaterThan(largestSum(0)));
  });

  test('rating brackets: 100 points wide, 1500 in bracket 7', () {
    expect(duelBracketFor(-50), 0);
    expect(duelBracketFor(899), 0);
    expect(duelBracketFor(900), 1);
    expect(duelBracketFor(1499), 6);
    expect(duelBracketFor(1500), 7);
    expect(duelBracketFor(2199), 13);
    expect(duelBracketFor(2200), 14);
    expect(duelBracketFor(3000), 14);
  });

  group('invalid configurations throw', () {
    test('a negative quota', () {
      expect(
        () => DuelConfig(
          seed: 1,
          quotas: {ExerciseType.addition: 3, ExerciseType.power: -1},
          bracket: 7,
        ),
        throwsArgumentError,
      );
    });
    test('no question, or too many', () {
      expect(
        () => DuelConfig(seed: 1, quotas: const {}, bracket: 7),
        throwsArgumentError,
      );
      expect(
        () => DuelConfig(
          seed: 1,
          quotas: {ExerciseType.addition: maxDuelQuestions + 1},
          bracket: 7,
        ),
        throwsArgumentError,
      );
    });
    test('a bracket out of range', () {
      for (final bracket in [-1, duelBracketCount]) {
        expect(
          () =>
              DuelConfig(seed: 1, quotas: standardDuelQuotas, bracket: bracket),
          throwsArgumentError,
        );
        expect(() => duelBracketLevel(bracket), throwsArgumentError);
      }
    });
  });

  test('a duel keeps its rules: its questions never move when new games '
      'change rules; JSON carries them (absent: v3); v1 throws', () {
    final v4 = DuelConfig(
      seed: 1,
      quotas: standardDuelQuotas,
      bracket: 7,
      rulesVersion: RulesVersion.v4,
    );
    expect(_lines(v4), isNot(_lines(_standard(1, 7))));
    expect(DuelConfig.fromJson(v4.toJson()), v4);
    expect(v4.toJson()['rules'], 4);
    final old = Map<String, Object?>.of(_standard(1, 7).toJson())
      ..remove('rules');
    expect(DuelConfig.fromJson(old), _standard(1, 7));
    expect(
      () => DuelConfig(
        seed: 1,
        quotas: standardDuelQuotas,
        bracket: 7,
        rulesVersion: RulesVersion.v1,
      ),
      throwsArgumentError,
    );
  });

  test('JSON: round trip, the same for any quota order, strict', () {
    final config = _standard(99, 3);
    final back = DuelConfig.fromJson(config.toJson());
    expect(back, config);
    expect(back.hashCode, config.hashCode);
    expect(_lines(back), _lines(config));
    final reordered = DuelConfig(
      seed: 99,
      quotas: Map.fromEntries(standardDuelQuotas.entries.toList().reversed),
      bracket: 3,
      rulesVersion: RulesVersion.v3,
    );
    expect(reordered, config);
    expect(reordered.toJson(), config.toJson());
    for (final bad in [
      null,
      {'seed': 1, 'bracket': 3},
      {
        'seed': '1',
        'bracket': 3,
        'quotas': {'addition': 1},
      },
      {
        'seed': 1,
        'bracket': 3,
        'quotas': {'addtion': 1},
      },
      {
        'seed': 1,
        'bracket': 3,
        'quotas': {'addition': 1.5},
      },
      {
        'seed': 1,
        'bracket': 99,
        'quotas': {'addition': 1},
      },
    ]) {
      expect(
        () => DuelConfig.fromJson(bad),
        throwsFormatException,
        reason: '$bad',
      );
    }
  });
}
