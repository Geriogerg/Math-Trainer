import 'package:math_trainer/core/domain/models/exercise.dart';
import 'package:math_trainer/core/domain/models/exercise_type.dart';
import 'package:test/test.dart';

void main() {
  group('PowerExercise', () {
    test('calcule la puissance en arithmétique entière', () {
      expect(const PowerExercise(base: 3, exponent: 2).correctAnswer, 9);
      expect(const PowerExercise(base: 2, exponent: 3).correctAnswer, 8);
      expect(const PowerExercise(base: 5, exponent: 1).correctAnswer, 5);
    });

    test('type est ExerciseType.power', () {
      expect(const PowerExercise(base: 3, exponent: 2).type, ExerciseType.power);
    });

    test('isCorrectAnswer rejette une réponse fausse', () {
      expect(const PowerExercise(base: 3, exponent: 2).isCorrectAnswer(8), isFalse);
    });
  });
}
