import '../generation/question_plan.dart';
import '../leveling/level.dart';

/// Levelling: difficulty follows the player's levels, the game moves them
/// and counts for the boards. Training: a fixed difficulty, nothing moves,
/// nothing is ranked (plan v2.9). The names are stored (setup store).
enum GameMode { training, levelling }

/// Training's fixed difficulty: every operation played at one level, so at
/// one tier — Easy T1, Medium T4, Hard T7 (`doc/levels.md`, section 4;
/// levels 15 / 40 / 70 since plan v2.9, each inside its tier, so stored
/// Training games keep their difficulty). The names are stored (setup
/// store).
enum TrainingDifficulty {
  easy(15),
  medium(40),
  hard(70);

  const TrainingDifficulty(this.wholeLevel);

  final int wholeLevel;

  Level get level => Level.whole(wholeLevel);

  /// The difficulty a stored Training session was played at, from one of
  /// its frozen levels; `null` if it is none of them.
  static TrainingDifficulty? ofLevel(Level level) {
    for (final difficulty in values) {
      if (difficulty.level == level) return difficulty;
    }
    return null;
  }
}

/// What the setup page decides for a game of operations (plan v2.9), apart
/// from the operations themselves. Remembered between games
/// (`GameSetupStore`).
class GameSetup {
  GameSetup({
    this.questionsPerOperation = defaultQuestionsPerOperation,
    this.mode = GameMode.levelling,
    this.difficulty = TrainingDifficulty.medium,
  }) {
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

  final GameMode mode;

  /// Read only in [GameMode.training]; kept while Levelling is chosen, so
  /// switching back finds it.
  final TrainingDifficulty difficulty;

  GameSetup copyWith({
    int? questionsPerOperation,
    GameMode? mode,
    TrainingDifficulty? difficulty,
  }) => GameSetup(
    questionsPerOperation: questionsPerOperation ?? this.questionsPerOperation,
    mode: mode ?? this.mode,
    difficulty: difficulty ?? this.difficulty,
  );

  @override
  bool operator ==(Object other) =>
      other is GameSetup &&
      other.questionsPerOperation == questionsPerOperation &&
      other.mode == mode &&
      other.difficulty == difficulty;

  @override
  int get hashCode => Object.hash(questionsPerOperation, mode, difficulty);
}
