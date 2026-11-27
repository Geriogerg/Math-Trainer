import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/models/game_setup.dart';

/// Home, the setup pages (a game, Chain operations, Tables) and the rules
/// of the two challenges.
class HomeStrings {
  const HomeStrings();

  final play = 'Play';
  final mainLevelCaption = 'Your level: the mean of + − × ÷.';
  final signInHint =
      'Played before, on this or another device? Sign in to get your levels '
      'back.';

  String family(ExerciseFamily family) => switch (family) {
    ExerciseFamily.basics => 'Basics',
    ExerciseFamily.advanced => 'Advanced',
  };

  String familyCaption(ExerciseFamily family) => switch (family) {
    ExerciseFamily.basics => 'Tap operations to play. Each has a level, 0–100.',
    ExerciseFamily.advanced => 'Each has its own level, like the basics.',
  };

  /// A row's Play button, as a screen reader names it.
  String playFamily(ExerciseFamily family) => 'Play ${this.family(family)}';

  final practice = 'Practice';
  final weakSpots = 'Weak spots';
  final weakSpotsCaption = 'What you missed, asked again.';
  String weakSpotsDue(int n) => n == 0 ? 'None due' : '$n due';
  final challenges = 'Challenges';
  final getTheCount = 'Get the count';
  final getTheCountCaption = 'Reach a target with the numbers given.';
  final chainOperations = 'Chain operations';
  final chainCaption = 'A running total, kept in your head.';
  final tables = 'Tables';
  final tablesCaption = 'Times tables, at your pace. Never ranked.';
  final tips = 'Tips';
  final tipsCaption = 'Shortcuts for every operation and level.';

  final firstRunTitle = 'How levels work';
  final firstRunLevels =
      'Each operation has a level, 0 to 100. A Levelling game moves it: '
      'right answers raise it, fast ones most; mistakes, timeouts and '
      'quitting lower it.';
  final firstRunPractice = 'Training games and Practice never move levels.';

  final couldNotStart = 'Could not start';

  // The game's setup page.
  final questions = 'Questions';
  String questionsCaption(int perOperation, int operations) => operations == 1
      ? '$perOperation questions.'
      : '$perOperation per operation: ${perOperation * operations} '
            'questions in all.';
  final mode = 'Mode';
  String modeLabel(GameMode mode) => switch (mode) {
    GameMode.training => 'Training',
    GameMode.levelling => 'Levelling',
  };
  String modeCaption(GameMode mode) => switch (mode) {
    GameMode.levelling =>
      'Moves your levels. Quitting counts the questions left as missed.',
    GameMode.training => 'A fixed difficulty. Your levels never move.',
  };
  String difficulty(TrainingDifficulty difficulty) => switch (difficulty) {
    TrainingDifficulty.easy => 'Easy',
    TrainingDifficulty.medium => 'Medium',
    TrainingDifficulty.hard => 'Hard',
  };
  final difficultyCaption = 'Easy: level 10 · Medium: 40 · Hard: 70.';

  // Chain operations.
  final seconds = 'Seconds';
  final operations = 'Operations';
  final chainRules = const [
    'A number, then one operation a screen. Keep the result in your head; '
        'type it at the end.',
    'Practice: it never moves your levels.',
  ];

  // Get the count.
  final countRules = const [
    'Reach the target with the numbers given and + − × ÷, each number once '
        'at most.',
    'The closer, the better; reaching it ends the round.',
    'Practice: it never moves your levels.',
  ];

  // Tables.
  final from = 'From';
  final to = 'To';
  final multipliers = 'Multipliers';
  String stepDown(String label) => '$label −1';
  String stepUp(String label) => '$label +1';
  String stepValue(String label, int value) => '$label $value';
}
