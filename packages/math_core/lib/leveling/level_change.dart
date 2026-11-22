import 'answer_outcome.dart';
import 'level.dart';
import 'level_rules.dart';

/// A fluent answer's credit, in quarters (1.0).
const fluentCreditQuarters = 4;

/// One answer's credit in quarters (`doc/levels.md`, section 3): 4 when
/// correct within [fluentMs], `rules.slowCreditQuarters` (3: 0.75) when
/// correct but slower — still within the 30 s, or it would be a timeout —
/// and 0 when wrong or timed out. A correct answer always counts in the
/// player's favour; speed only decides how much (the spec's principle 2).
int answerCreditQuarters({
  required AnswerOutcome answer,
  required int fluentMs,
  LevelRules? rules,
}) {
  if (!answer.isCorrect) return 0;
  return answer.elapsedMs <= fluentMs
      ? fluentCreditQuarters
      : (rules ?? LevelRules.standard).slowCreditQuarters;
}

/// The change of one operation's level after a Levelling game, in
/// hundredths: [questions] answers on it earned [creditQuarters] in all.
/// With q the mean credit (`creditQuarters / (4 × questions)`):
///
/// - q in the dead band [0.55, 0.65]: 0;
/// - above: `cap_up(n) × min(1, (q − 0.65) / 0.25)`;
/// - below: `−cap_down × min(1, (0.55 − q) / 0.35)`.
///
/// Integers only (rule 18): `25 × creditQuarters` is q in percent times n,
/// so every comparison and ratio stays exact; the one rounding is to the
/// nearest hundredth, halves away from zero.
int levelChangeHundredths({
  required int questions,
  required int creditQuarters,
  LevelRules? rules,
}) {
  if (questions < 1) {
    throw ArgumentError.value(questions, 'questions', 'must be positive.');
  }
  if (creditQuarters < 0 || creditQuarters > fluentCreditQuarters * questions) {
    throw ArgumentError.value(
      creditQuarters,
      'creditQuarters',
      'must be between 0 and ${fluentCreditQuarters * questions}.',
    );
  }
  final r = rules ?? LevelRules.standard;
  final qTimesN = 100 ~/ fluentCreditQuarters * creditQuarters; // q% × n
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
/// them that operation's): [current] (frozen at the start) plus
/// [levelChangeHundredths], kept in [0, 100].
Level levelAfterGame({
  required Level current,
  required List<AnswerOutcome> answers,
  required int fluentMs,
  LevelRules? rules,
}) {
  var credit = 0;
  for (final answer in answers) {
    credit += answerCreditQuarters(
      answer: answer,
      fluentMs: fluentMs,
      rules: rules,
    );
  }
  return Level.clamped(
    current.hundredths +
        levelChangeHundredths(
          questions: answers.length,
          creditQuarters: credit,
          rules: rules,
        ),
  );
}

/// a / b to the nearest integer, halves up; a ≥ 0, b > 0.
int _roundedDivision(int a, int b) => (2 * a + b) ~/ (2 * b);
