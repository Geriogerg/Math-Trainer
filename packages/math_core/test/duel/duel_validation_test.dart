import 'package:math_core/challenges/count.dart';
import 'package:math_core/duel/duel_config.dart';
import 'package:math_core/duel/duel_mode.dart';
import 'package:math_core/duel/duel_run.dart';
import 'package:math_core/duel/duel_validation.dart';
import 'package:math_core/leveling/rules_version.dart';
import 'package:math_core/validation/session_validation.dart';
import 'package:test/test.dart';

/// The pinned Basics duel (`duel_config_test.dart`): its answers in order.
final _basics = DuelConfig(
  mode: DuelMode.basics,
  seed: 1,
  difficulty: 4,
  rulesVersion: RulesVersion.v8,
);
const _basicsAnswers = [7897, 3330, 3949, 259, 147, 108, 7957, 17050];

/// The pinned Get the count duel: targets 442, 847, 205 (4 operations).
final _count = DuelConfig(
  mode: DuelMode.count,
  seed: 987654321,
  difficulty: 2,
  rulesVersion: RulesVersion.v8,
);

QuizRun _quiz(List<int> values, {int ms = 4000}) =>
    QuizRun([for (final v in values) DuelAnswer(value: v, elapsedMs: ms)]);

/// Every round solved by its shortest solution at [ms].
CountRun _solved({int ms = 9000}) => CountRun([
  for (final (puzzle, solution) in _count.rounds())
    CountRoundRun([
      CountImprovement(atMs: ms, value: puzzle.target, steps: solution),
    ]),
]);

DuelRunValid _valid(DuelConfig config, DuelRun run) {
  final verdict = validateDuelRun(config, run);
  if (verdict is DuelRunInvalid) {
    fail('refused: ${verdict.problem} ${verdict.detail}');
  }
  return verdict as DuelRunValid;
}

DuelRunProblem? _problem(DuelConfig config, DuelRun run) =>
    switch (validateDuelRun(config, run)) {
      DuelRunInvalid(:final problem) => problem,
      DuelRunValid() => null,
    };

void main() {
  group('question runs', () {
    test('correctness recomputed; score = correct, then total time', () {
      final values = [..._basicsAnswers];
      values[2] = 1; // wrong
      values[5] = timeoutValue; // a timeout
      final valid = _valid(_basics, _quiz(values));
      expect(valid.score.points, 6);
      expect(valid.score.totalMs, 8 * 4000);
      final lane = valid.lane as QuizLane;
      expect(
        [for (final a in lane.answers) a.correct],
        [true, true, false, true, true, false, true, true],
      );
      expect(valid.flags, isEmpty);
    });

    test('the lane never carries the values typed', () {
      final lane = _valid(_basics, _quiz(_basicsAnswers)).lane;
      expect(lane.toJson().toString(), isNot(contains('7897')));
      expect(
        DuelLane.fromJson(lane.toJson(), DuelMode.basics).score,
        lane.score,
      );
    });

    test('refused: wrong length, a time out of range, rounds', () {
      expect(
        _problem(_basics, _quiz(_basicsAnswers.take(7).toList())),
        DuelRunProblem.wrongShape,
      );
      expect(
        _problem(_basics, _quiz(_basicsAnswers, ms: 30001)),
        DuelRunProblem.badElapsed,
      );
      expect(
        _problem(_basics, _quiz(_basicsAnswers, ms: -1)),
        DuelRunProblem.badElapsed,
      );
      expect(_problem(_basics, _solved()), DuelRunProblem.wrongShape);
      expect(
        _problem(_count, _quiz(_basicsAnswers)),
        DuelRunProblem.wrongShape,
      );
    });

    test('implausible timing is flagged, never refused', () {
      // Multi-digit right answers in 150 ms.
      final valid = _valid(_basics, _quiz(_basicsAnswers, ms: 150));
      expect(valid.flags, contains(ValidationFlag.implausiblyFast));
      // Eight right answers all at exactly 4 s: flat times.
      expect(
        _valid(_basics, _quiz(_basicsAnswers)).flags,
        contains(ValidationFlag.flatTimes),
      );
    });

    test('quitting: the questions left are timeouts at 30 s', () {
      final partial = _quiz(_basicsAnswers.take(3).toList());
      final sent = partial.completedWithTimeouts();
      expect(sent.answers.length, 8);
      expect(sent.answers.last, DuelAnswer.none);
      final valid = _valid(_basics, sent);
      expect(valid.score.points, 3);
      expect(valid.score.totalMs, 3 * 4000 + 5 * 30000);
    });
  });

  group('Get the count runs', () {
    test('every round solved: distance 0, time = when each was reached', () {
      final valid = _valid(_count, _solved());
      expect(valid.score.points, 0);
      expect(valid.score.totalMs, 3 * 9000);
      expect(valid.flags, isEmpty);
    });

    test('never improved: the six numbers\' distance at 0 s', () {
      final valid = _valid(
        _count,
        CountRun([for (var i = 0; i < 3; i++) CountRoundRun(const [])]),
      );
      final expected = [
        for (final (p, _) in _count.rounds()) baseCountDistance(p),
      ].fold(0, (a, b) => a + b);
      expect(valid.score.points, expected);
      expect(valid.score.totalMs, 0);
      // 442 from 100: 342; 847 from 100: 747; 205 from 100: 105.
      expect(expected, 342 + 747 + 105);
    });

    test('an improvement then the target: the lane keeps both', () {
      final (puzzle, solution) = _count.rounds().first;
      final partial = solution.sublist(0, 1); // its first step only
      final run = CountRun([
        CountRoundRun([
          CountImprovement(
            atMs: 2000,
            value: partial.last.result,
            steps: partial,
          ),
          CountImprovement(atMs: 7000, value: puzzle.target, steps: solution),
        ]),
        CountRoundRun(const []),
        CountRoundRun(const []),
      ]);
      final valid = _valid(_count, run);
      final round = (valid.lane as CountLane).rounds.first;
      expect(round.improvements.length, 2);
      expect(round.distanceAt(1000), round.baseDistance);
      expect(round.distanceAt(2000), (partial.last.result - 442).abs());
      expect(round.distanceAt(30000), 0);
      expect(
        DuelLane.fromJson(valid.lane.toJson(), DuelMode.count).score,
        valid.score,
      );
    });

    CountRun firstRound(List<CountImprovement> improvements) => CountRun([
      CountRoundRun(improvements),
      CountRoundRun(const []),
      CountRoundRun(const []),
    ]);

    test('refused: a forged derivation', () {
      // 100 × 4 = 400 then 400 + 42 = 442: 42 is not one of the numbers.
      final forged = [
        const CountStep(100, CountOperator.multiply, 4, 400),
        const CountStep(400, CountOperator.add, 42, 442),
      ];
      expect(
        _problem(
          _count,
          firstRound([CountImprovement(atMs: 5000, value: 442, steps: forged)]),
        ),
        DuelRunProblem.badDerivation,
      );
      // A number used twice (one 4 only): 100 × 4 = 400, 4 + 1 = 5…
      final twice = [
        const CountStep(100, CountOperator.multiply, 4, 400),
        const CountStep(4, CountOperator.add, 1, 5),
      ];
      expect(
        _problem(
          _count,
          firstRound([CountImprovement(atMs: 5000, value: 5, steps: twice)]),
        ),
        DuelRunProblem.badDerivation,
      );
      // A wrong result.
      expect(
        _problem(
          _count,
          firstRound([
            CountImprovement(
              atMs: 5000,
              value: 401,
              steps: const [CountStep(100, CountOperator.multiply, 4, 401)],
            ),
          ]),
        ),
        DuelRunProblem.badDerivation,
      );
      // Claimed value differs from what the steps make.
      expect(
        _problem(
          _count,
          firstRound([
            CountImprovement(
              atMs: 5000,
              value: 441,
              steps: const [CountStep(100, CountOperator.multiply, 4, 400)],
            ),
          ]),
        ),
        DuelRunProblem.badDerivation,
      );
    });

    test('refused: not closer, not later, after the target, off the clock', () {
      const make400 = [CountStep(100, CountOperator.multiply, 4, 400)];
      const make500 = [CountStep(100, CountOperator.multiply, 5, 500)];
      final (puzzle, solution) = _count.rounds().first;
      expect(puzzle.numbers, contains(4));
      expect(
        _problem(
          _count,
          firstRound([
            CountImprovement(atMs: 1000, value: 400, steps: make400),
            CountImprovement(atMs: 2000, value: 400, steps: make400),
          ]),
        ),
        DuelRunProblem.notCloser,
      );
      expect(
        _problem(
          _count,
          firstRound([
            CountImprovement(atMs: 3000, value: 400, steps: make400),
            CountImprovement(atMs: 3000, value: 442, steps: solution),
          ]),
        ),
        DuelRunProblem.notLater,
      );
      expect(
        _problem(
          _count,
          firstRound([
            CountImprovement(atMs: 3000, value: 442, steps: solution),
            CountImprovement(atMs: 4000, value: 400, steps: make400),
          ]),
        ),
        DuelRunProblem.afterTarget,
      );
      expect(
        _problem(
          _count,
          firstRound([
            CountImprovement(atMs: 30001, value: 400, steps: make400),
          ]),
        ),
        DuelRunProblem.badElapsed,
      );
      // 5 is not among this round's numbers.
      expect(puzzle.numbers, isNot(contains(5)));
      expect(
        _problem(
          _count,
          firstRound([
            CountImprovement(atMs: 1000, value: 500, steps: make500),
          ]),
        ),
        DuelRunProblem.badDerivation,
      );
      expect(
        _problem(_count, CountRun([CountRoundRun(const [])])),
        DuelRunProblem.wrongShape,
      );
    });

    test('two 4-operation targets in under 3 s: flagged', () {
      expect(_valid(_count, _solved(ms: 2500)).flags, {
        ValidationFlag.implausiblyFast,
      });
    });

    test('quitting: the rounds left are never improved', () {
      final sent = CountRun([
        CountRoundRun(const []),
      ]).completedWithEmptyRounds();
      expect(sent.rounds.length, 3);
      expect(validateDuelRun(_count, sent), isA<DuelRunValid>());
    });
  });

  group('JSON', () {
    test('runs round trip; the shape must match the mode', () {
      final quiz = _quiz(_basicsAnswers);
      final back = DuelRun.fromJson(quiz.toJson(), DuelMode.basics) as QuizRun;
      expect(back.answers, quiz.answers);
      final count = _solved();
      final again = DuelRun.fromJson(count.toJson(), DuelMode.count);
      expect(_valid(_count, again).score, _valid(_count, count).score);
      expect(
        () => DuelRun.fromJson(quiz.toJson(), DuelMode.count),
        throwsFormatException,
      );
      expect(
        () => DuelRun.fromJson(count.toJson(), DuelMode.advanced),
        throwsFormatException,
      );
    });

    test('strict: wrong types and unknown operators throw', () {
      for (final bad in [
        null,
        {'answers': 'x'},
        {
          'answers': [
            {'value': '1', 'ms': 1},
          ],
        },
        {
          'answers': [
            {'value': 1},
          ],
        },
      ]) {
        expect(
          () => DuelRun.fromJson(bad, DuelMode.basics),
          throwsFormatException,
        );
      }
      for (final step in [
        [1, 'pow', 2, 1],
        [1, 'add', 2],
        ['1', 'add', 2, 3],
      ]) {
        expect(
          () => DuelRun.fromJson({
            'rounds': [
              {
                'improvements': [
                  {
                    'ms': 1,
                    'value': 3,
                    'steps': [step],
                  },
                ],
              },
            ],
          }, DuelMode.count),
          throwsFormatException,
        );
      }
      expect(
        () => DuelLane.fromJson({
          'answers': [
            {'ms': 1, 'correct': 1},
          ],
        }, DuelMode.basics),
        throwsFormatException,
      );
    });
  });

  group('the winner', () {
    DuelScore quiz(int points, int ms) =>
        DuelScore(mode: DuelMode.basics, points: points, totalMs: ms);
    DuelScore count(int points, int ms) =>
        DuelScore(mode: DuelMode.count, points: points, totalMs: ms);

    test('question modes: more correct, then less time, else a draw', () {
      expect(duelResult(quiz(7, 38000), quiz(6, 31000)), 1);
      expect(duelResult(quiz(6, 31000), quiz(7, 38000)), 0);
      expect(duelResult(quiz(6, 30000), quiz(6, 31000)), 1);
      expect(duelResult(quiz(6, 32000), quiz(6, 31000)), 0);
      expect(duelResult(quiz(6, 31000), quiz(6, 31000)), 0.5);
    });

    test('Get the count: less distance, then less time, else a draw', () {
      expect(duelResult(count(3, 60000), count(5, 10000)), 1);
      expect(duelResult(count(5, 10000), count(3, 60000)), 0);
      expect(duelResult(count(0, 20000), count(0, 25000)), 1);
      expect(duelResult(count(0, 20000), count(0, 20000)), 0.5);
    });
  });
}

/// A timeout, as stored.
const timeoutValue = -1;
