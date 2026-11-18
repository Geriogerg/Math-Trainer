import '../domain/models/answer_result.dart';
import '../domain/models/exercise.dart';

/// `interrupted`: three consecutive timeouts without any key pressed (step
/// 4.2, commit B — see `doc/decisions.md`). Distinct from `finished`: the
/// session does not count for levels, though the answers already given
/// stay stored.
enum SessionStatus { notStarted, inProgress, finished, interrupted }

class SessionState {
  const SessionState({
    required this.status,
    this.currentExercise,
    this.outcomes = const [],
    this.score = 0,
    this.currentStreak = 0,
  });

  factory SessionState.initial() =>
      const SessionState(status: SessionStatus.notStarted);

  final SessionStatus status;
  final Exercise? currentExercise;
  final List<AnswerResult> outcomes;
  final int score;
  final int currentStreak;
}
