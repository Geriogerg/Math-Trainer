import 'exercise.dart';

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
