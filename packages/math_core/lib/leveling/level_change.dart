import 'answer_outcome.dart';
import 'level.dart';
import 'level_rules.dart';

/// One answer's credit in percent (`doc/levels.md`, section 3): 100 when
/// correct within [fluentMs], `rules.slowCreditPercent` when correct but
/// slower — still within the 30 s, or it would be a timeout — and 0 when
/// wrong or timed out. A correct answer always counts in the player's
/// favour; speed only decides how much (the spec's principle 2).
int answerCreditPercent({
  required AnswerOutcome answer,
  required int fluentMs,
  required LevelRules rules,
}) {
  if (!answer.isCorrect) return 0;
  return answer.elapsedMs <= fluentMs
      ? LevelRules.fluentCreditPercent
      : rules.slowCreditPercent;
}

/// The change of one operation's level after a Levelling game, in
/// hundredths: [questions] answers on it earned [creditPercent] in all.
/// With q the mean credit (`creditPercent / (100 × questions)`) and the
/// dead band [low, high]:
///
/// - q in the dead band: 0;
/// - above: `cap_up(n) × min(1, (q − high) / upSpan)`;
/// - below: `−cap_down × min(1, (low − q) / downSpan)`.
///
/// Integers only (rule 18): [creditPercent] is q in percent times n, so
/// every comparison and ratio stays exact; the one rounding is to the
/// nearest hundredth, halves away from zero.
int levelChangeHundredths({
  required int questions,
  required int creditPercent,
  required LevelRules rules,
}) {
  if (questions < 1) {
    throw ArgumentError.value(questions, 'questions', 'must be positive.');
  }
  const fluent = LevelRules.fluentCreditPercent;
  if (creditPercent < 0 || creditPercent > fluent * questions) {
    throw ArgumentError.value(
      creditPercent,
      'creditPercent',
      'must be between 0 and ${fluent * questions}.',
    );
  }
  final r = rules;
  final qTimesN = creditPercent; // q% × n
  final high = r.deadBandHighPercent * questions;
  final low = r.deadBandLowPercent * questions;
  if (qTimesN > high) {
    final cap = r.capUpFor(questions) * 100;
    final change = _roundedDivision(
      cap * (qTimesN - high),
      r.upSpanPercent * questions,
    );
    return change < cap ? change : cap;
  }
  if (qTimesN < low) {
    final cap = r.capDownLevels * 100;
    final change = _roundedDivision(
      cap * (low - qTimesN),
      r.downSpanPercent * questions,
    );
    return -(change < cap ? change : cap);
  }
  return 0;
}

/// One operation's level after a Levelling game on it ([answers], all of
/// them that operation's) under [rules]: [current] (frozen at the start)
/// plus [levelChangeHundredths], kept in [0, 100].
Level levelAfterGame({
  required Level current,
  required List<AnswerOutcome> answers,
  required int fluentMs,
  required LevelRules rules,
}) {
  var credit = 0;
  for (final answer in answers) {
    credit += answerCreditPercent(
      answer: answer,
      fluentMs: fluentMs,
      rules: rules,
    );
  }
  return Level.clamped(
    current.hundredths +
        levelChangeHundredths(
          questions: answers.length,
          creditPercent: credit,
          rules: rules,
        ),
  );
}

/// a / b to the nearest integer, halves up; a ≥ 0, b > 0.
int _roundedDivision(int a, int b) => (2 * a + b) ~/ (2 * b);
