import '../models/exercise.dart';
import 'exercise_source.dart';

/// Questions decided in advance, asked in order (Tables mode: the round is
/// drawn whole by `tablesQuestions`). Throws once they run out (rule 13):
/// the session asks exactly as many as it planned.
class ListExerciseSource extends ExerciseSource {
  ListExerciseSource(List<Exercise> questions)
    : _questions = List.unmodifiable(questions);

  final List<Exercise> _questions;
  int _next = 0;

  @override
  Exercise next() {
    if (_next >= _questions.length) {
      throw StateError('All ${_questions.length} questions were asked.');
    }
    return _questions[_next++];
  }
}
