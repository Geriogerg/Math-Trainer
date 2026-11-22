import '../generation/question_plan.dart';

/// What the setup page decides for a game of operations (plan v2.9), apart
/// from the operations themselves. Remembered between games
/// (`GameSetupStore`).
class GameSetup {
  GameSetup({this.questionsPerOperation = defaultQuestionsPerOperation}) {
    if (!questionsPerOperationChoices.contains(questionsPerOperation)) {
      throw ArgumentError.value(
        questionsPerOperation,
        'questionsPerOperation',
        'must be one of $questionsPerOperationChoices.',
      );
    }
  }

  /// Every selected operation gets exactly this many questions.
  final int questionsPerOperation;

  GameSetup copyWith({int? questionsPerOperation}) => GameSetup(
    questionsPerOperation: questionsPerOperation ?? this.questionsPerOperation,
  );

  @override
  bool operator ==(Object other) =>
      other is GameSetup &&
      other.questionsPerOperation == questionsPerOperation;

  @override
  int get hashCode => questionsPerOperation.hashCode;
}
