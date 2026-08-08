import 'operation_type.dart';

/// Axe de sélection d'une session : couvre tous les types d'exercice du jeu.
/// Les quatre valeurs arithmétiques portent leur [OperationType] ; les
/// autres portent `null`. `OperationType` reste interne à
/// [ArithmeticExercise] (voir exercise.dart) — cet enum ne l'étend jamais.
enum ExerciseType {
  addition(OperationType.addition),
  subtraction(OperationType.subtraction),
  multiplication(OperationType.multiplication),
  division(OperationType.division),
  power(null),
  squareRoot(null),
  percentage(null);

  const ExerciseType(this.operationType);

  final OperationType? operationType;
}
