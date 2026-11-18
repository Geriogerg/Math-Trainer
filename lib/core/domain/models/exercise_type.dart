import 'operation_type.dart';

/// Selection axis of a session: covers every exercise type of the game.
/// The four arithmetic values carry their [OperationType]; the others
/// carry `null`. `OperationType` stays internal to [ArithmeticExercise]
/// (see exercise.dart) — this enum never extends it.
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
