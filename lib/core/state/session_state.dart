import '../domain/models/answer_result.dart';
import '../domain/models/exercise.dart';

enum SessionStatus { notStarted, inProgress, finished }

class SessionState {
  const SessionState({
    required this.status,
    this.currentExercise,
    this.outcomes = const [],
    this.score = 0,
    this.currentStreak = 0,
  });

  factory SessionState.initial() => const SessionState(status: SessionStatus.notStarted);

  final SessionStatus status;
  final Exercise? currentExercise;
  final List<AnswerResult> outcomes;
  final int score;
  final int currentStreak;
}
