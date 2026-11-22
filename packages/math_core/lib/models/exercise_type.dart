import 'operation_type.dart';

/// Selection axis of a session: covers every exercise type of the game.
/// The four arithmetic values carry their [OperationType]; the others
/// carry `null`. `OperationType` stays internal to [ArithmeticExercise]
/// (see exercise.dart) — this enum never extends it.
///
/// The value names are stored discriminants (sessions, answers, server
/// levels): never rename one. A new type goes at the end, so the `.index`
/// order existing sequences were drawn with does not move.
enum ExerciseType {
  addition(OperationType.addition),
  subtraction(OperationType.subtraction),
  multiplication(OperationType.multiplication),
  division(OperationType.division),
  power(null),
  squareRoot(null),
  percentage(null),

  /// Area under a small polynomial (Redesign phase commit 4).
  integral(null);

  const ExerciseType(this.operationType);

  final OperationType? operationType;

  /// Basics are the four arithmetic operations; everything else is
  /// advanced (plan v2.9, Redesign phase).
  ExerciseFamily get family =>
      operationType == null ? ExerciseFamily.advanced : ExerciseFamily.basics;
}

/// The two rows of Home. Only [basics] make the main level (`mainLevel`);
/// each advanced operation keeps its own level and board.
enum ExerciseFamily {
  basics,
  advanced;

  /// This family's types in `.index` order.
  List<ExerciseType> get types => [
    for (final type in ExerciseType.values)
      if (type.family == this) type,
  ];
}
