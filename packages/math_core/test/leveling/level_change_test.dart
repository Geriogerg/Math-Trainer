import 'package:math_core/leveling/answer_outcome.dart';
import 'package:math_core/leveling/level.dart';
import 'package:math_core/leveling/level_change.dart';
import 'package:math_core/leveling/level_rules.dart';
import 'package:test/test.dart';

const _fluentMs = 4000;

AnswerOutcome _fluent() =>
    const AnswerOutcome(isCorrect: true, elapsedMs: _fluentMs);
AnswerOutcome _slow() => const AnswerOutcome(isCorrect: true, elapsedMs: 9000);
AnswerOutcome _wrong() =>
    const AnswerOutcome(isCorrect: false, elapsedMs: 3000);
AnswerOutcome _timeout() =>
    const AnswerOutcome(isCorrect: false, elapsedMs: 30000);

/// The change in hundredths for [answers], from level 50 (no clamping).
int _change(List<AnswerOutcome> answers) =>
    levelAfterGame(
      current: Level.whole(50),
      answers: answers,
      fluentMs: _fluentMs,
    ).hundredths -
    5000;

/// As the spec prints it: one decimal.
double _oneDecimal(int hundredths) => (hundredths / 10).round() / 10;

void main() {
  group('credit per answer (doc/levels.md, section 3)', () {
    test('fluent 1.0, slow 0.75, wrong or timeout 0 — in quarters', () {
      int credit(AnswerOutcome a) =>
          answerCreditQuarters(answer: a, fluentMs: _fluentMs);
      expect(credit(_fluent()), 4);
      expect(credit(const AnswerOutcome(isCorrect: true, elapsedMs: 0)), 4);
      expect(
        credit(const AnswerOutcome(isCorrect: true, elapsedMs: _fluentMs + 1)),
        3,
      );
      expect(credit(_slow()), 3);
      expect(credit(const AnswerOutcome(isCorrect: true, elapsedMs: 29999)), 3);
      expect(credit(_wrong()), 0);
      expect(credit(_timeout()), 0);
    });
  });

  group("the spec's example table (4 questions per operation)", () {
    final cases = <(String, List<AnswerOutcome>, int, double)>[
      ('4 / 4 correct and fluent', List.generate(4, (_) => _fluent()), 300, 3),
      ('4 / 4 correct, all slow', List.generate(4, (_) => _slow()), 120, 1.2),
      (
        '3 / 4 fluent, 1 wrong',
        [_fluent(), _fluent(), _wrong(), _fluent()],
        120,
        1.2,
      ),
      (
        '3 / 4 correct, all slow',
        [_slow(), _slow(), _slow(), _timeout()],
        0,
        0,
      ),
      (
        '2 / 4 correct, fluent',
        [_fluent(), _wrong(), _fluent(), _wrong()],
        -29,
        -0.3,
      ),
      (
        '2 / 4 correct, slow',
        [_slow(), _wrong(), _timeout(), _slow()],
        -100,
        -1,
      ),
      ('0 / 4', List.generate(4, (_) => _wrong()), -200, -2),
    ];
    for (final (name, answers, hundredths, printed) in cases) {
      test('$name: $printed', () {
        expect(_change(answers), hundredths);
        expect(_oneDecimal(_change(answers)), printed);
      });
    }

    test('a correct-but-slow game raises the level', () {
      for (final n in [4, 5, 10, 20]) {
        expect(_change(List.generate(n, (_) => _slow())), greaterThan(0));
      }
    });
  });

  group('caps', () {
    test('a perfect game gains 3 / 3 / 4 / 5 levels at 4 / 5 / 10 / 20', () {
      for (final (n, levels) in [(4, 3), (5, 3), (10, 4), (20, 5)]) {
        expect(_change(List.generate(n, (_) => _fluent())), levels * 100);
      }
    });

    test('a bad game costs at most 2 levels, whatever its length', () {
      for (final n in [4, 5, 10, 20]) {
        expect(_change(List.generate(n, (_) => _timeout())), -200);
      }
    });

    test('quality 0.90 and above earns the whole cap; 0.20 and below costs '
        'the whole cap', () {
      // 20 questions: 18 fluent + 2 wrong = 0.90.
      expect(
        _change([...List.generate(18, (_) => _fluent()), _wrong(), _wrong()]),
        500,
      );
      // 20 questions: 4 fluent = 0.20.
      expect(
        _change([
          ...List.generate(4, (_) => _fluent()),
          ...List.generate(16, (_) => _wrong()),
        ]),
        -200,
      );
    });

    test('the dead band is closed at both ends: q = 0.55 and 0.65 stay', () {
      // 20 questions: 11 fluent = 0.55; 13 fluent = 0.65.
      List<AnswerOutcome> fluentOf20(int k) => [
        ...List.generate(k, (_) => _fluent()),
        ...List.generate(20 - k, (_) => _wrong()),
      ];
      expect(_change(fluentOf20(11)), 0);
      expect(_change(fluentOf20(13)), 0);
      expect(_change(fluentOf20(14)), greaterThan(0));
      expect(_change(fluentOf20(10)), lessThan(0));
    });
  });

  group('the level stays in [0, 100]', () {
    test('a bad game at level 0 stays at 0', () {
      final level = levelAfterGame(
        current: Level.zero,
        answers: List.generate(4, (_) => _wrong()),
        fluentMs: _fluentMs,
      );
      expect(level, Level.zero);
    });

    test('a perfect game at 99 stops at 100', () {
      final level = levelAfterGame(
        current: Level.whole(99),
        answers: List.generate(20, (_) => _fluent()),
        fluentMs: _fluentMs,
      );
      expect(level, Level.whole(100));
    });
  });

  test("the spec's grind estimate: perfect 10-question games reach 20 in 5 "
      'games and 50 in 13', () {
    var level = Level.zero;
    var games = 0;
    final reached = <int, int>{};
    while (level.whole < 50) {
      level = levelAfterGame(
        current: level,
        answers: List.generate(10, (_) => _fluent()),
        fluentMs: _fluentMs,
      );
      games++;
      for (final target in [20, 50]) {
        if (level.whole >= target) reached.putIfAbsent(target, () => games);
      }
    }
    expect(reached, {20: 5, 50: 13});
  });

  group('invalid input throws (rule 13)', () {
    test('no question, or more credit than questions allow', () {
      expect(
        () => levelChangeHundredths(questions: 0, creditQuarters: 0),
        throwsArgumentError,
      );
      expect(
        () => levelChangeHundredths(questions: 4, creditQuarters: 17),
        throwsArgumentError,
      );
      expect(
        () => levelChangeHundredths(questions: 4, creditQuarters: -1),
        throwsArgumentError,
      );
    });

    test('rules that make no sense', () {
      expect(() => LevelRules(slowCreditQuarters: 5), throwsArgumentError);
      expect(
        () => LevelRules(deadBandLowPercent: 70, deadBandHighPercent: 60),
        throwsArgumentError,
      );
      expect(() => LevelRules(upSpanPercent: 0), throwsArgumentError);
      expect(() => LevelRules(capDownLevels: -1), throwsArgumentError);
      expect(
        () => LevelRules(capUpLevels: const [(questions: 10, levels: 4)]),
        throwsArgumentError,
      );
    });
  });

  test('cap_up by number of questions', () {
    final rules = LevelRules.standard;
    expect(
      [
        for (final n in [1, 4, 5, 9, 10, 19, 20, 40]) rules.capUpFor(n),
      ],
      [3, 3, 3, 3, 4, 4, 5, 5],
    );
  });
}
