import '../models/exercise.dart';

/// Représentation générique d'un [Exercise] pour le stockage : le schéma
/// n'a besoin d'aucune migration quand une nouvelle famille (fraction,
/// puissance, racine...) apparaît, seul ce mapping change.
typedef ExerciseStorageDescription = ({
  String exerciseType,
  String operationType,
  Map<String, Object?> operands,
});

/// `switch` exhaustif sur la sealed class [Exercise] : le compilateur
/// signalera cet endroit dès qu'une nouvelle sous-classe sera ajoutée.
ExerciseStorageDescription describeExerciseForStorage(Exercise exercise) {
  return switch (exercise) {
    ArithmeticExercise() => (
      exerciseType: 'arithmetic',
      operationType: exercise.operationType.name,
      operands: {'operandA': exercise.operandA, 'operandB': exercise.operandB},
    ),
  };
}
