import 'package:math_core/models/answer_result.dart';
import 'package:math_core/models/exercise.dart';

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
    this.correction,
  });

  factory SessionState.initial() =>
      const SessionState(status: SessionStatus.notStarted);

  final SessionStatus status;

  /// The question on screen — during a [correction], still the one that was
  /// just missed.
  final Exercise? currentExercise;
  final List<AnswerResult> outcomes;
  final int score;
  final int currentStreak;

  /// The wrong answer or timeout being corrected: its correct answer stays
  /// on screen for `SessionController.correctionDelay` before the next
  /// question (`doc/design.md`). Already counted in [outcomes]; no timer
  /// runs and input is ignored meanwhile.
  final AnswerResult? correction;

  bool get isCorrecting => correction != null;
}
