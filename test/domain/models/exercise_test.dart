import 'package:math_trainer/core/domain/models/exercise.dart';
import 'package:math_trainer/core/domain/models/operation_type.dart';
import 'package:test/test.dart';

void main() {
  group('ArithmeticExercise', () {
    test('calcule la bonne réponse pour chaque opération', () {
      expect(
        const ArithmeticExercise(
          operandA: 4,
          operandB: 3,
          operationType: OperationType.addition,
        ).correctAnswer,
        7,
      );
      expect(
        const ArithmeticExercise(
          operandA: 4,
          operandB: 3,
          operationType: OperationType.subtraction,
        ).correctAnswer,
        1,
      );
      expect(
        const ArithmeticExercise(
          operandA: 4,
          operandB: 3,
          operationType: OperationType.multiplication,
        ).correctAnswer,
        12,
      );
      expect(
        const ArithmeticExercise(
          operandA: 12,
          operandB: 3,
          operationType: OperationType.division,
        ).correctAnswer,
        4,
      );
    });

    test('isCorrectAnswer accepte int ou double équivalents', () {
      const exercise = ArithmeticExercise(
        operandA: 12,
        operandB: 3,
        operationType: OperationType.division,
      );

      expect(exercise.isCorrectAnswer(4), isTrue);
      expect(exercise.isCorrectAnswer(4.0), isTrue);
      expect(exercise.isCorrectAnswer(5), isFalse);
    });

    test('prompt affiche le bon symbole', () {
      expect(
        const ArithmeticExercise(
          operandA: 4,
          operandB: 3,
          operationType: OperationType.multiplication,
        ).prompt,
        '4 × 3',
      );
    });

    test('deux exercices avec les mêmes valeurs sont égaux', () {
      const a = ArithmeticExercise(
        operandA: 4,
        operandB: 3,
        operationType: OperationType.addition,
      );
      const b = ArithmeticExercise(
        operandA: 4,
        operandB: 3,
        operationType: OperationType.addition,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('rejette une réponse fausse pour chaque opération', () {
      expect(
        const ArithmeticExercise(
          operandA: 4,
          operandB: 3,
          operationType: OperationType.addition,
        ).isCorrectAnswer(6),
        isFalse,
      );
      expect(
        const ArithmeticExercise(
          operandA: 4,
          operandB: 3,
          operationType: OperationType.subtraction,
        ).isCorrectAnswer(2),
        isFalse,
      );
      expect(
        const ArithmeticExercise(
          operandA: 4,
          operandB: 3,
          operationType: OperationType.multiplication,
        ).isCorrectAnswer(11),
        isFalse,
      );
    });

    test('soustraction à opérandes égaux a une réponse correcte de zéro', () {
      const exercise = ArithmeticExercise(
        operandA: 5,
        operandB: 5,
        operationType: OperationType.subtraction,
      );

      expect(exercise.correctAnswer, 0);
      expect(exercise.isCorrectAnswer(0), isTrue);
    });

    test('isCorrectAnswer n\'applique aucune tolérance numérique', () {
      const exercise = ArithmeticExercise(
        operandA: 4,
        operandB: 3,
        operationType: OperationType.addition,
      );

      expect(exercise.isCorrectAnswer(7.5), isFalse);
    });
  });
}
