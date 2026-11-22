import 'package:math_core/duel/duel_config.dart';
import 'package:math_core/leveling/level.dart';
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

DuelConfig _standard(int seed, int bracket) =>
    DuelConfig(seed: seed, quotas: standardDuelQuotas, bracket: bracket);

/// Phase 5.2 commit 2 (Phase 7 commit 1): a duel's questions depend on
/// (seed, config) only — pinned here, and this file runs on the VM and
/// compiled to JavaScript like every core test, so both players' browsers
/// and the server draw the same questions.
void main() {
  // Recorded on the VM when the duel configuration was written. Never
  // regenerate to make a JavaScript failure pass: a difference is a bug.
  const pinned = {
    (1, 7): [
      'addition 375 196 = 571',
      'division 180 9 = 20',
      'squareRoot 36 = 6',
      'percentage 21 1000 = 210',
      'multiplication 18 11 = 198',
      'subtraction 345 273 = 72',
      'division 81 9 = 9',
      'power 2 3 = 8',
      'subtraction 360 41 = 319',
      'percentage 16 150 = 24',
      'multiplication 9 15 = 135',
      'addition 360 172 = 532',
    ],
    (20261120, 0): [
      'power 9 2 = 81',
      'division 30 5 = 6',
      'percentage 33 700 = 231',
      'squareRoot 25 = 5',
      'addition 30 31 = 61',
      'subtraction 22 15 = 7',
      'addition 4 19 = 23',
      'subtraction 20 5 = 15',
      'multiplication 5 2 = 10',
      'percentage 15 80 = 12',
      'multiplication 2 7 = 14',
      'division 12 2 = 6',
    ],
    (987654321, 14): [
      'addition 251 421 = 672',
      'subtraction 678 285 = 393',
      'addition 138 519 = 657',
      'division 864 24 = 36',
      'percentage 82 350 = 287',
      'percentage 57 600 = 342',
      'division 660 30 = 22',
      'multiplication 31 36 = 1116',
      'subtraction 703 631 = 72',
      'squareRoot 784 = 28',
      'multiplication 13 37 = 481',
      'power 5 4 = 625',
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
