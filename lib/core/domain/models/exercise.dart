import 'exercise_type.dart';
import 'operation_type.dart';

/// Racine des types d'exercice. `sealed` force le compilateur à signaler
/// tout endroit du code qui ne gère pas une nouvelle sous-classe via un
/// `switch` non exhaustif (règle 11 : jamais de `default` pour masquer le
/// trou). Toutes les sous-classes vivent dans ce fichier : Dart restreint
/// les sous-types d'une `sealed class` à la même librairie.
sealed class Exercise {
  const Exercise();

  String get prompt;
  int get correctAnswer;
  ExerciseType get type;

  bool isCorrectAnswer(int submittedValue) => submittedValue == correctAnswer;
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
  ExerciseType get type => switch (operationType) {
    OperationType.addition => ExerciseType.addition,
    OperationType.subtraction => ExerciseType.subtraction,
    OperationType.multiplication => ExerciseType.multiplication,
    OperationType.division => ExerciseType.division,
  };

  @override
  int get correctAnswer => switch (operationType) {
    OperationType.addition => operandA + operandB,
    OperationType.subtraction => operandA - operandB,
    OperationType.multiplication => operandA * operandB,
    OperationType.division => operandA ~/ operandB,
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

final class PowerExercise extends Exercise {
  const PowerExercise({required this.base, required this.exponent});

  final int base;
  final int exponent;

  @override
  ExerciseType get type => ExerciseType.power;

  @override
  int get correctAnswer {
    var result = 1;
    for (var i = 0; i < exponent; i++) {
      result *= base;
    }
    return result;
  }

  @override
  String get prompt => '$base^$exponent';

  @override
  bool operator ==(Object other) =>
      other is PowerExercise && other.base == base && other.exponent == exponent;

  @override
  int get hashCode => Object.hash(base, exponent);
}

final class SquareRootExercise extends Exercise {
  const SquareRootExercise({required this.radicand});

  /// Toujours un carré parfait : garanti par le générateur (règle 10), non
  /// revérifié ici.
  final int radicand;

  @override
  ExerciseType get type => ExerciseType.squareRoot;

  @override
  int get correctAnswer {
    // Recherche entière incrémentale : jamais de sqrt() flottant (piège
    // documenté — erreurs d'arrondi sur les grandes valeurs).
    var root = 0;
    while ((root + 1) * (root + 1) <= radicand) {
      root++;
    }
    return root;
  }

  @override
  String get prompt => '√$radicand';

  @override
  bool operator ==(Object other) => other is SquareRootExercise && other.radicand == radicand;

  @override
  int get hashCode => radicand.hashCode;
}

final class PercentageExercise extends Exercise {
  const PercentageExercise({required this.percent, required this.base});

  final int percent;
  final int base;

  @override
  ExerciseType get type => ExerciseType.percentage;

  @override
  int get correctAnswer => percent * base ~/ 100;

  @override
  String get prompt => '$percent% de $base';

  @override
  bool operator ==(Object other) =>
      other is PercentageExercise && other.percent == percent && other.base == base;

  @override
  int get hashCode => Object.hash(percent, base);
}
