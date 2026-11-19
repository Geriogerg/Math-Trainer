import '../models/answer_result.dart';
import '../models/exercise.dart';

/// Provides a session's exercise sequence. Keeping it apart from
/// `ExerciseGenerator` is the extension point for duels: a future network
/// implementation can replace `LocalExerciseSource` without changing
/// `SessionController` or the UI.
abstract class ExerciseSource {
  Exercise next();

  /// Told every answer, before the next [next] call — an adaptive source
  /// (the placement test) picks the next question from it. A fixed sequence
  /// ignores it.
  void onAnswered(AnswerResult outcome) {}
}
