import 'package:math_trainer/core/domain/models/exercise.dart';
import 'package:math_trainer/core/domain/models/exercise_type.dart';
import 'package:test/test.dart';

void main() {
  group('SquareRootExercise', () {
    test('computes the integer root of a perfect square', () {
      expect(const SquareRootExercise(radicand: 16).correctAnswer, 4);
      expect(const SquareRootExercise(radicand: 144).correctAnswer, 12);
      expect(const SquareRootExercise(radicand: 4).correctAnswer, 2);
    });

    test('type is ExerciseType.squareRoot', () {
      expect(const SquareRootExercise(radicand: 16).type, ExerciseType.squareRoot);
    });

    test('isCorrectAnswer rejects a wrong answer', () {
      expect(const SquareRootExercise(radicand: 16).isCorrectAnswer(5), isFalse);
    });
  });
}
