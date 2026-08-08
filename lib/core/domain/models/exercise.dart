import 'operation_type.dart';

/// Racine des types d'exercice. `sealed` force le compilateur à signaler
/// tout endroit du code qui ne gère pas une nouvelle sous-classe (ex. une
/// future famille fraction/puissance/racine) via un `switch` non exhaustif.
sealed class Exercise {
  const Exercise();

  String get prompt;
  num get correctAnswer;

  bool isCorrectAnswer(num submittedValue) => submittedValue == correctAnswer;
}

final class ArithmeticExercise extends Exercise {
  const ArithmeticExercise({
    required this.operandA,
    required this.operandB,
    required this.operationType,
  });

  final int operandA;
  final int operandB;
  final OperationType operationType;

  @override
  num get correctAnswer => switch (operationType) {
    OperationType.addition => operandA + operandB,
    OperationType.subtraction => operandA - operandB,
    OperationType.multiplication => operandA * operandB,
    OperationType.division => operandA / operandB,
  };

  @override
  String get prompt {
    final symbol = switch (operationType) {
      OperationType.addition => '+',
      OperationType.subtraction => '-',
      OperationType.multiplication => '×',
      OperationType.division => '÷',
    };
    return '$operandA $symbol $operandB';
  }

  @override
  bool operator ==(Object other) =>
      other is ArithmeticExercise &&
      other.operandA == operandA &&
      other.operandB == operandB &&
      other.operationType == operationType;

  @override
  int get hashCode => Object.hash(operandA, operandB, operationType);
}
