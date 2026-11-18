import 'exercise.dart';

/// Sentinel for "no value typed, the question timed out". Never a real
/// answer: the keypad has no `−` key and no operation produces a negative
/// correct answer (subtraction guarantees `operandA ≥ operandB`, all the
/// others use positive operands) — see `doc/decisions.md`. Avoids making
/// `submittedValue` nullable, which would have needed a schema migration
/// (`answers.submitted_value` is `REAL NOT NULL`).
const timeoutSubmittedValue = -1;

class AnswerResult {
  const AnswerResult({
    required this.exercise,
    required this.submittedValue,
    required this.isCorrect,
    required this.elapsedMs,
  });

  final Exercise exercise;
  final int submittedValue;
  final bool isCorrect;
  final int elapsedMs;

  bool get isTimeout => submittedValue == timeoutSubmittedValue;

  @override
  bool operator ==(Object other) =>
      other is AnswerResult &&
      other.exercise == exercise &&
      other.submittedValue == submittedValue &&
      other.isCorrect == isCorrect &&
      other.elapsedMs == elapsedMs;

  @override
  int get hashCode =>
      Object.hash(exercise, submittedValue, isCorrect, elapsedMs);
}
