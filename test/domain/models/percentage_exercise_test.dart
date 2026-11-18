import 'package:math_trainer/core/domain/models/exercise.dart';
import 'package:math_trainer/core/domain/models/exercise_type.dart';
import 'package:test/test.dart';

void main() {
  group('PercentageExercise', () {
    test('computes an exact percentage', () {
      expect(const PercentageExercise(percent: 10, base: 50).correctAnswer, 5);
      expect(const PercentageExercise(percent: 25, base: 80).correctAnswer, 20);
      expect(const PercentageExercise(percent: 50, base: 12).correctAnswer, 6);
    });

    test('type is ExerciseType.percentage', () {
      expect(const PercentageExercise(percent: 10, base: 50).type, ExerciseType.percentage);
    });

    test('isCorrectAnswer rejects a wrong answer', () {
      expect(const PercentageExercise(percent: 10, base: 50).isCorrectAnswer(4), isFalse);
    });
  });
}
