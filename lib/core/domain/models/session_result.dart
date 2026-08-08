import 'answer_result.dart';

class SessionResult {
  const SessionResult({required this.outcomes, required this.totalScore});

  final List<AnswerResult> outcomes;
  final int totalScore;

  int get correctCount => outcomes.where((outcome) => outcome.isCorrect).length;

  double get accuracy =>
      outcomes.isEmpty ? 0 : correctCount / outcomes.length;

  double get averageElapsedMs => outcomes.isEmpty
      ? 0
      : outcomes.map((outcome) => outcome.elapsedMs).reduce((a, b) => a + b) /
            outcomes.length;
}
