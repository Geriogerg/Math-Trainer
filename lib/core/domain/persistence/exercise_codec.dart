import '../models/exercise.dart';
import '../models/exercise_type.dart';

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
///
/// Le cas [ArithmeticExercise] est inchangé depuis l'étape 2 (déjà des
/// lignes réelles en base) : `exerciseType` reste `'arithmetic'` et
/// `operationType` porte le nom de l'opération. Les trois nouvelles
/// variantes n'ont pas de sous-opération : `exerciseType` et
/// `operationType` portent tous deux le nom de leur [ExerciseType].
ExerciseStorageDescription describeExerciseForStorage(Exercise exercise) {
  return switch (exercise) {
    ArithmeticExercise() => (
      exerciseType: 'arithmetic',
      operationType: exercise.operationType.name,
      operands: {'operandA': exercise.operandA, 'operandB': exercise.operandB},
    ),
    PowerExercise() => (
      exerciseType: ExerciseType.power.name,
      operationType: ExerciseType.power.name,
      operands: {'base': exercise.base, 'exponent': exercise.exponent},
    ),
    SquareRootExercise() => (
      exerciseType: ExerciseType.squareRoot.name,
      operationType: ExerciseType.squareRoot.name,
      operands: {'radicand': exercise.radicand},
    ),
    PercentageExercise() => (
      exerciseType: ExerciseType.percentage.name,
      operationType: ExerciseType.percentage.name,
      operands: {'percent': exercise.percent, 'base': exercise.base},
    ),
  };
}
