import '../models/exercise.dart';

/// Provides a session's exercise sequence. Keeping it apart from
/// `ExerciseGenerator` is the extension point for duels: a future network
/// implementation can replace `LocalExerciseSource` without changing
/// `SessionController` or the UI.
abstract class ExerciseSource {
  Exercise next();
}
