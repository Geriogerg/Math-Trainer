import 'package:math_core/leveling/answer_outcome.dart';
import 'package:math_core/leveling/level.dart';
import 'package:math_core/leveling/level_change.dart';
import 'package:math_core/leveling/level_rules.dart';
import 'package:math_core/leveling/rules_version.dart';
import 'package:test/test.dart';

const _fluentMs = 4000;

AnswerOutcome _fluent() =>
    const AnswerOutcome(isCorrect: true, elapsedMs: _fluentMs);
AnswerOutcome _slow() => const AnswerOutcome(isCorrect: true, elapsedMs: 9000);
AnswerOutcome _wrong() =>
    const AnswerOutcome(isCorrect: false, elapsedMs: 3000);
AnswerOutcome _timeout() =>
    const AnswerOutcome(isCorrect: false, elapsedMs: 30000);

/// The change in hundredths for [answers] under [rules] (v2 by default),
/// from level 50 (no clamping).
int _change(List<AnswerOutcome> answers, [LevelRules? rules]) =>
    levelAfterGame(
      current: Level.whole(50),
      answers: answers,
      fluentMs: _fluentMs,
      rules: rules ?? LevelRules.v2,
    ).hundredths -
    5000;

/// [k] fluent answers then wrong ones, [n] in all.
List<AnswerOutcome> _fluentOf(int n, int k) => [
  ...List.generate(k, (_) => _fluent()),
  ...List.generate(n - k, (_) => _wrong()),
];

/// As the spec prints it: one decimal.
double _oneDecimal(int hundredths) => (hundredths / 10).round() / 10;

void main() {
  group('credit per answer (doc/levels.md, section 3)', () {
    test('fluent 1.0, slow 0.75 (v2) or 0.85 (v3), wrong or timeout 0 — in '
        'percent', () {
      int credit(AnswerOutcome a, LevelRules rules) =>
          answerCreditPercent(answer: a, fluentMs: _fluentMs, rules: rules);
      for (final (rules, slow) in [(LevelRules.v2, 75), (LevelRules.v3, 85)]) {
        expect(credit(_fluent(), rules), 100);
        expect(
          credit(const AnswerOutcome(isCorrect: true, elapsedMs: 0), rules),
          100,
        );
        expect(
          credit(
            const AnswerOutcome(isCorrect: true, elapsedMs: _fluentMs + 1),
            rules,
          ),
          slow,
        );
        expect(credit(_slow(), rules), slow);
        expect(
          credit(const AnswerOutcome(isCorrect: true, elapsedMs: 29999), rules),
          slow,
        );
        expect(credit(_wrong(), rules), 0);
        expect(credit(_timeout(), rules), 0);
      }
    });
  });

  group("rules v2: the spec's example table (4 questions per operation)", () {
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

  group('rules v2: caps', () {
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
      expect(_change(_fluentOf(20, 11)), 0);
      expect(_change(_fluentOf(20, 13)), 0);
      expect(_change(_fluentOf(20, 14)), greaterThan(0));
      expect(_change(_fluentOf(20, 10)), lessThan(0));
    });
  });

  group('rules v3 (Levels close-out): the plan v3.2 targets', () {
    final v3 = LevelRules.v3;

    test('slow 0.85, dead band 0.62–0.72, down cap 3; spans and up caps as '
        'v2', () {
      expect(v3.slowCreditPercent, 85);
      expect((v3.deadBandLowPercent, v3.deadBandHighPercent), (62, 72));
      expect(v3.capDownLevels, 3);
      expect(v3.upSpanPercent, LevelRules.v2.upSpanPercent);
      expect(v3.downSpanPercent, LevelRules.v2.downSpanPercent);
      for (final n in [4, 5, 10, 20]) {
        expect(v3.capUpFor(n), LevelRules.v2.capUpFor(n));
      }
    });

    test('4 questions all correct but slow gain at least +1.5 (+1.56)', () {
      expect(_change(List.generate(4, (_) => _slow()), v3), 156);
      for (final n in [5, 10, 20]) {
        expect(_change(List.generate(n, (_) => _slow()), v3), greaterThan(0));
      }
    });

    test('a perfect game still gains the full cap: 3 / 3 / 4 / 5', () {
      for (final (n, levels) in [(4, 3), (5, 3), (10, 4), (20, 5)]) {
        expect(_change(List.generate(n, (_) => _fluent()), v3), levels * 100);
      }
    });

    test('a bad game never costs more than 3 levels', () {
      for (final n in [4, 5, 10, 20]) {
        expect(_change(List.generate(n, (_) => _timeout()), v3), -300);
      }
    });

    test("the spec's example games under v3 (4 questions per operation)", () {
      expect(_change(_fluentOf(4, 3), v3), 36); // q 0.75: +0.36
      // q 0.6375: inside the dead band.
      expect(_change([_slow(), _slow(), _slow(), _timeout()], v3), 0);
      expect(_change(_fluentOf(4, 2), v3), -103); // q 0.50: −1.03
      // q 0.425: −1.67.
      expect(_change([_slow(), _wrong(), _timeout(), _slow()], v3), -167);
      expect(_change(_fluentOf(4, 0), v3), -300);
    });

    test('the dead band is closed at both ends: q = 0.62 and 0.72 stay', () {
      int at(int creditPercent) => levelChangeHundredths(
        questions: 10,
        creditPercent: creditPercent,
        rules: v3,
      );
      expect(at(620), 0);
      expect(at(720), 0);
      expect(at(721), greaterThan(0));
      expect(at(619), lessThan(0));
    });
  });

  group('the level stays in [0, 100] (v2)', () {
    test('a bad game at level 0 stays at 0', () {
      final level = levelAfterGame(
        current: Level.zero,
        answers: List.generate(4, (_) => _wrong()),
        fluentMs: _fluentMs,
        rules: LevelRules.v2,
      );
      expect(level, Level.zero);
    });

    test('a perfect game at 99 stops at 100', () {
      final level = levelAfterGame(
        current: Level.whole(99),
        answers: List.generate(20, (_) => _fluent()),
        fluentMs: _fluentMs,
        rules: LevelRules.v2,
      );
      expect(level, Level.whole(100));
    });
  });

  test("the spec's grind estimate, under v2 and v3: perfect 10-question "
      'games reach 20 in 5 games and 50 in 13', () {
    for (final rules in [LevelRules.v2, LevelRules.v3]) {
      var level = Level.zero;
      var games = 0;
      final reached = <int, int>{};
      while (level.whole < 50) {
        level = levelAfterGame(
          current: level,
          answers: List.generate(10, (_) => _fluent()),
          fluentMs: _fluentMs,
          rules: rules,
        );
        games++;
        for (final target in [20, 50]) {
          if (level.whole >= target) reached.putIfAbsent(target, () => games);
        }
      }
      expect(reached, {20: 5, 50: 13});
    }
  });

  group('invalid input throws (rule 13)', () {
    test('no question, or more credit than questions allow', () {
      int change(int questions, int credit) => levelChangeHundredths(
        questions: questions,
        creditPercent: credit,
        rules: LevelRules.v2,
      );
      expect(() => change(0, 0), throwsArgumentError);
      expect(() => change(4, 401), throwsArgumentError);
      expect(() => change(4, -1), throwsArgumentError);
    });

    test('rules that make no sense', () {
      LevelRules rules({
        int slow = 75,
        int low = 55,
        int high = 65,
        int down = 2,
        int upSpan = 25,
        List<({int questions, int levels})> caps = const [
          (questions: 0, levels: 3),
        ],
      }) => LevelRules(
        slowCreditPercent: slow,
        deadBandLowPercent: low,
        deadBandHighPercent: high,
        capDownLevels: down,
        upSpanPercent: upSpan,
        capUpLevels: caps,
      );
      expect(rules, returnsNormally);
      expect(() => rules(slow: 101), throwsArgumentError);
      expect(() => rules(slow: -1), throwsArgumentError);
      expect(() => rules(low: 70, high: 60), throwsArgumentError);
      expect(() => rules(upSpan: 0), throwsArgumentError);
      expect(() => rules(down: -1), throwsArgumentError);
      expect(
        () => rules(caps: const [(questions: 10, levels: 4)]),
        throwsArgumentError,
      );
    });

    test('rules v1 are retired: no constants', () {
      expect(() => LevelRules.of(RulesVersion.v1), throwsArgumentError);
      expect(LevelRules.of(RulesVersion.v2), same(LevelRules.v2));
      expect(LevelRules.of(RulesVersion.v3), same(LevelRules.v3));
    });
  });

  test('cap_up by number of questions', () {
    final rules = LevelRules.v2;
    expect(
      [
        for (final n in [1, 4, 5, 9, 10, 19, 20, 40]) rules.capUpFor(n),
      ],
      [3, 3, 3, 3, 4, 4, 5, 5],
    );
  });
}
