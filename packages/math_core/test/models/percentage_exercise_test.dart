import 'package:math_core/models/exercise.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:test/test.dart';

void main() {
  group('PercentageExercise', () {
    test('computes an exact percentage', () {
      expect(PercentageExercise(percent: 10, base: 50).correctAnswer, 5);
      expect(PercentageExercise(percent: 25, base: 80).correctAnswer, 20);
      expect(PercentageExercise(percent: 50, base: 12).correctAnswer, 6);
    });

    test('type is ExerciseType.percentage', () {
      expect(
        PercentageExercise(percent: 10, base: 50).type,
        ExerciseType.percentage,
      );
    });

    test('isCorrectAnswer rejects a wrong answer', () {
      expect(
        PercentageExercise(percent: 10, base: 50).isCorrectAnswer(4),
        isFalse,
      );
    });
  });
}
