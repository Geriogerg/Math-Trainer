import 'dart:math';

import 'package:math_core/challenges/count.dart';
import 'package:math_core/duel/duel_config.dart';
import 'package:math_core/duel/duel_mode.dart';
import 'package:math_core/leveling/rules_version.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/persistence/exercise_codec.dart';
import 'package:math_core/tiers/tier.dart';
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

/// One line per Get the count round.
List<String> _rounds(DuelConfig config) => [
  for (final (puzzle, solution) in config.rounds())
    '${puzzle.numbers.join(' ')} → ${puzzle.target} in ${solution.length}',
];

/// Rules v8: the pins below were recorded under it.
DuelConfig _duel(DuelMode mode, int seed, int difficulty) => DuelConfig(
  mode: mode,
  seed: seed,
  difficulty: difficulty,
  rulesVersion: RulesVersion.v8,
);

/// Phase 7 commit 1: a duel's content depends on its config only — pinned
/// here, and this file runs on the VM and compiled to JavaScript like every
/// core test, so both players' browsers and the server draw the same.
void main() {
  // Recorded on the VM at Phase 7 commit 1, when duels moved from Phase
  // 5.2's rating brackets to the plan's modes (no duel was stored before).
  // Never regenerate to make a JavaScript failure pass: a difference is a
  // bug — and every stored duel would change.
  const pinnedQuestions = {
    (DuelMode.basics, 1, 4): [
      'addition 7216 681 = 7897',
      'subtraction 4263 933 = 3330',
      'addition 3151 798 = 3949',
      'division 518 2 = 259',
      'division 882 6 = 147',
      'multiplication 18 6 = 108',
      'subtraction 8178 221 = 7957',
      'multiplication 341 50 = 17050',
    ],
    (DuelMode.basics, 20261125, 0): [
      'division 3 3 = 1',
      'addition 3 5 = 8',
      'multiplication 7 4 = 28',
      'addition 7 3 = 10',
      'subtraction 5 4 = 1',
      'multiplication 6 5 = 30',
      'division 3 3 = 1',
      'subtraction 4 1 = 3',
    ],
    (DuelMode.advanced, 987654321, 9): [
      'percentage 26 400 = 104',
      'integral 1 3 0 -2 0 0 5 = 234',
      'percentage 25 32000000 = 8000000',
      'power 195 2 = 38025',
      'integral 239 241 0 2 0 0 = 960',
      'squareRoot 30976 = 176',
      'squareRoot 1018081 = 1009',
      'power 135 2 = 18225',
    ],
    (DuelMode.advanced, 7, 4): [
      'power 2 7 = 128',
      'power 25 2 = 625',
      'squareRoot 441 = 21',
      'percentage 25 3148 = 787',
      'integral 0 5 0 0 3 0 = 125',
      'squareRoot 2025 = 45',
      'integral 0 2 0 0 3 0 = 8',
      'percentage 24 25 = 6',
    ],
  };
  const pinnedRounds = {
    (1, 0): [
      '100 9 6 2 8 2 → 620 in 3',
      '50 7 9 8 3 6 → 987 in 3',
      '25 100 75 9 4 1 → 476 in 3',
    ],
    (20261125, 1): [
      '50 3 2 8 1 4 → 205 in 3',
      '50 8 9 3 9 1 → 491 in 3',
      '100 6 4 5 8 2 → 573 in 4',
    ],
    (987654321, 2): [
      '100 25 50 4 7 1 → 442 in 4',
      '75 100 6 7 1 2 → 847 in 4',
      '75 100 7 4 4 2 → 205 in 4',
    ],
  };

  test('same config: the pinned questions and rounds, VM and JavaScript', () {
    for (final MapEntry(key: (mode, seed, tier), value: expected)
        in pinnedQuestions.entries) {
      expect(_lines(_duel(mode, seed, tier)), expected, reason: '$seed');
    }
    for (final MapEntry(key: (seed, band), value: expected)
        in pinnedRounds.entries) {
      expect(_rounds(_duel(DuelMode.count, seed, band)), expected);
    }
  });

  test('asked twice, the same content; another seed, another', () {
    expect(
      _lines(_duel(DuelMode.basics, 42, 3)),
      _lines(_duel(DuelMode.basics, 42, 3)),
    );
    expect(
      _lines(_duel(DuelMode.basics, 43, 3)),
      isNot(_lines(_duel(DuelMode.basics, 42, 3))),
    );
    expect(
      _rounds(_duel(DuelMode.count, 42, 1)),
      _rounds(_duel(DuelMode.count, 42, 1)),
    );
  });

  test('two of each of the mode\'s four types, mixed by the seed', () {
    for (final mode in [DuelMode.basics, DuelMode.advanced]) {
      final orders = <String>{};
      for (var seed = 0; seed < 20; seed++) {
        final config = _duel(mode, seed, 5);
        final sequence = config.typeSequence();
        expect(sequence.length, duelQuestionCount);
        for (final type in mode.types) {
          expect(sequence.where((t) => t == type).length, 2);
        }
        expect([for (final q in config.questions()) q.type], sequence);
        orders.add(sequence.join(','));
      }
      expect(orders.length, greaterThan(10), reason: mode.name);
    }
  });

  test('drawn exactly as a game at the tier draws them', () {
    // Every question of a duel at tier t is one the tier's game can draw:
    // its level-band digits stay those of the tier (spot check on the
    // operands' size across tiers).
    int largest(DuelConfig c) => c
        .questions()
        .where((q) => q.type == ExerciseType.addition)
        .map((q) => q.correctAnswer)
        .reduce(max);
    var low = 0;
    var high = 0;
    for (var seed = 0; seed < 30; seed++) {
      low = max(low, largest(_duel(DuelMode.basics, seed, 0)));
      high = max(high, largest(_duel(DuelMode.basics, seed, 9)));
    }
    expect(low, lessThanOrEqualTo(20));
    expect(high, greaterThan(1000));
  });

  test('rating → tier: 150 points a tier from 900', () {
    expect(duelTierFor(0), Tier.t0);
    expect(duelTierFor(899), Tier.t0);
    expect(duelTierFor(900), Tier.t0);
    expect(duelTierFor(1049), Tier.t0);
    expect(duelTierFor(1050), Tier.t1);
    expect(duelTierFor(1500), Tier.t4);
    expect(duelTierFor(2249), Tier.t8);
    expect(duelTierFor(2250), Tier.t9);
    expect(duelTierFor(3000), Tier.t9);
    expect(
      DuelConfig.forRating(mode: DuelMode.advanced, seed: 1, rating: 1500),
      // A new duel draws under the current game rules (v9 from Phase 6b).
      DuelConfig(mode: DuelMode.advanced, seed: 1, difficulty: 4),
    );
  });

  test('rating → count band: below 1300, 1300–1700, above 1700', () {
    expect(countBandFor(1299), 0);
    expect(countBandFor(1300), 1);
    expect(countBandFor(1700), 1);
    expect(countBandFor(1701), 2);
    expect(countBandOperations(0), (2, 3));
    expect(countBandOperations(1), (3, 4));
    expect(countBandOperations(2), (4, 5));
    expect(() => countBandOperations(3), throwsArgumentError);
    expect(
      DuelConfig.forRating(mode: DuelMode.count, seed: 1, rating: 1300),
      DuelConfig(mode: DuelMode.count, seed: 1, difficulty: 1),
    );
  });

  test('count rounds: targets in their band, solutions exact', () {
    var offBand = 0;
    var rounds = 0;
    for (var band = 0; band < countBands; band++) {
      final (minOps, maxOps) = countBandOperations(band);
      for (var seed = 0; seed < 60; seed++) {
        for (final (puzzle, solution) in _duel(
          DuelMode.count,
          seed,
          band,
        ).rounds()) {
          rounds++;
          expect(solution.last.result, puzzle.target);
          // The solution is the shortest: its length is the target's.
          expect(
            shortestCountLength(puzzle.numbers, puzzle.target),
            solution.length,
          );
          if (solution.length < minOps || solution.length > maxOps) {
            offBand++;
          }
        }
      }
    }
    // The fallback (no target of the band in range) is rare.
    expect(offBand, lessThan(rounds ~/ 20), reason: '$offBand of $rounds');
  });

  test('the band fallback: the nearest length, shorter first', () {
    // A draw with a band of 1 operation only finds 1-operation targets if
    // the numbers make some in range; whatever it returns is reachable.
    final random = Random(3);
    final (puzzle, solution) = drawCountPuzzleInBand(
      random,
      minOps: 5,
      maxOps: 5,
    );
    expect(solution.last.result, puzzle.target);
    expect(
      () => drawCountPuzzleInBand(Random(1), minOps: 0, maxOps: 2),
      throwsArgumentError,
    );
  });

  test('a mode asks only for its own content', () {
    expect(() => _duel(DuelMode.count, 1, 0).questions(), throwsStateError);
    expect(() => _duel(DuelMode.basics, 1, 0).rounds(), throwsStateError);
    expect(() => _duel(DuelMode.count, 1, 0).tier, throwsStateError);
    expect(_duel(DuelMode.count, 1, 0).length, 3);
    expect(_duel(DuelMode.basics, 1, 0).length, 8);
  });

  test('invariants by throw: difficulty range, retired rules', () {
    expect(() => _duel(DuelMode.basics, 1, 10), throwsArgumentError);
    expect(() => _duel(DuelMode.basics, 1, -1), throwsArgumentError);
    expect(() => _duel(DuelMode.count, 1, 3), throwsArgumentError);
    expect(
      () => DuelConfig(
        mode: DuelMode.basics,
        seed: 1,
        difficulty: 0,
        rulesVersion: RulesVersion.v1,
      ),
      throwsArgumentError,
    );
  });

  test('a duel keeps its rules: v6 and v8 draw the same questions', () {
    // v8 changed only the weak-spot schedule; duels never hold weak spots.
    for (var seed = 0; seed < 10; seed++) {
      final v6 = DuelConfig(
        mode: DuelMode.basics,
        seed: seed,
        difficulty: 6,
        rulesVersion: RulesVersion.v6,
      );
      expect(_lines(v6), _lines(_duel(DuelMode.basics, seed, 6)));
    }
  });

  test('JSON: round trip, strict', () {
    for (final config in [
      _duel(DuelMode.basics, 1, 4),
      _duel(DuelMode.count, -5, 2),
    ]) {
      expect(DuelConfig.fromJson(config.toJson()), config);
    }
    expect(_duel(DuelMode.count, 3, 1).toJson(), {
      'mode': 'count',
      'seed': 3,
      'difficulty': 1,
      'rules': 8,
      'duelRules': 1,
    });
    final good = _duel(DuelMode.basics, 1, 4).toJson();
    for (final bad in [
      null,
      'x',
      {...good, 'mode': 'chain'},
      {...good, 'seed': '1'},
      {...good, 'difficulty': 10},
      {...good, 'rules': 1},
      {...good, 'rules': 99},
      {...good, 'duelRules': 2},
      {...good}..remove('duelRules'),
    ]) {
      expect(() => DuelConfig.fromJson(bad), throwsFormatException);
    }
  });

  test('the pattern family of each question, as the game reports it', () {
    var patterned = 0;
    for (var seed = 0; seed < 40; seed++) {
      final config = _duel(DuelMode.basics, seed, 5);
      final families = config.questionFamilies();
      expect(families.length, duelQuestionCount);
      // Drawing the families never moves the questions.
      expect(_lines(config), _lines(_duel(DuelMode.basics, seed, 5)));
      for (final (i, q) in config.questions().indexed) {
        final family = families[i];
        if (family == null) continue;
        patterned++;
        expect(family.type, q.type, reason: '$seed/$i');
      }
    }
    expect(patterned, greaterThan(40), reason: 'T5 draws pattern questions');
    expect(
      () => _duel(DuelMode.count, 1, 0).questionFamilies(),
      throwsStateError,
    );
  });

  // Rules v9 (Phase 6b commit 1): a new duel draws under the game rules it
  // stores, v9 from now on — no question twice in a duel. Recorded on the VM
  // when v9 became current; never regenerate (every stored v9 duel would
  // change), and v8's pins above stay as they were.
  const pinnedQuestionsV9 = {
    (DuelMode.basics, 1, 4): [
      'addition 8781 634 = 9415',
      'subtraction 4784 451 = 4333',
      'addition 1376 759 = 2135',
      'division 868 4 = 217',
      'division 8216 2 = 4108',
      'multiplication 989 5 = 4945',
      'subtraction 10000 3271 = 6729',
      'multiplication 96 8 = 768',
    ],
    (DuelMode.basics, 20261127, 0): [
      'division 16 2 = 8',
      'subtraction 9 3 = 6',
      'multiplication 3 3 = 9',
      'subtraction 3 2 = 1',
      'addition 3 3 = 6',
      'multiplication 1 7 = 7',
      'addition 1 9 = 10',
      'division 40 5 = 8',
    ],
    (DuelMode.advanced, 7, 1): [
      'power 4 3 = 64',
      'power 2 7 = 128',
      'squareRoot 361 = 19',
      'percentage 20 40 = 8',
      'integral 0 8 0 2 0 0 = 64',
      'squareRoot 121 = 11',
      'integral 0 4 0 2 0 0 = 16',
      'percentage 25 100 = 25',
    ],
    (DuelMode.advanced, 1763510400, 9): [
      'integral 2 5 0 -2 0 0 5 = 3072',
      'squareRoot 28900 = 170',
      'percentage 45 900 = 405',
      'squareRoot 16900 = 130',
      'percentage 28 625 = 175',
      'power 134 2 = 17956',
      'power 133 2 = 17689',
      'integral 2 4 0 0 9 8 = 648',
    ],
  };
  for (final MapEntry(key: (mode, seed, tier), value: expected)
      in pinnedQuestionsV9.entries) {
    test('rules v9: ${mode.name} at T$tier, seed $seed — pinned', () {
      final config = DuelConfig(
        mode: mode,
        seed: seed,
        difficulty: tier,
        rulesVersion: RulesVersion.v9,
      );
      expect(_lines(config), expected);
      expect(config, DuelConfig.fromJson(config.toJson()));
    });
  }
}
