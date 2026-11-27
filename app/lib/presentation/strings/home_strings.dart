import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/models/game_setup.dart';

/// Home, the setup pages (a game, Chain operations, Tables) and the rules
/// of the two challenges.
abstract interface class HomeStrings {
  String get play;
  String get mainLevelCaption;
  String get signInHint;
  String family(ExerciseFamily family);
  String familyCaption(ExerciseFamily family);

  /// A row's Play button, as a screen reader names it.
  String playFamily(ExerciseFamily family);
  String get practice;
  String get weakSpots;
  String get weakSpotsCaption;
  String weakSpotsDue(int n);
  String get challenges;
  String get getTheCount;
  String get getTheCountCaption;
  String get chainOperations;
  String get chainCaption;
  String get tables;
  String get tablesCaption;
  String get tips;
  String get tipsCaption;
  String get firstRunTitle;
  String get firstRunLevels;
  String get firstRunPractice;
  String get couldNotStart;
  // The game's setup page.
  String get questions;
  String questionsCaption(int perOperation, int operations);
  String get mode;
  String modeLabel(GameMode mode);
  String modeCaption(GameMode mode);
  String difficulty(TrainingDifficulty difficulty);
  String get difficultyCaption;
  // Chain operations.
  String get seconds;
  String get operations;
  List<String> get chainRules;
  // Get the count.
  List<String> get countRules;
  // Tables.
  String get from;
  String get to;
  String get multipliers;
  String stepDown(String label);
  String stepUp(String label);
  String stepValue(String label, int value);
}

/// HomeStrings in English.
class EnglishHomeStrings implements HomeStrings {
  const EnglishHomeStrings();

  @override
  final play = 'Play';

  @override
  final mainLevelCaption = 'Your level: the mean of + − × ÷.';

  @override
  final signInHint =
      'Played before, on this or another device? Sign in to get your levels '
      'back.';

  @override
  String family(ExerciseFamily family) => switch (family) {
    ExerciseFamily.basics => 'Basics',
    ExerciseFamily.advanced => 'Advanced',
  };

  @override
  String familyCaption(ExerciseFamily family) => switch (family) {
    ExerciseFamily.basics => 'Tap operations to play. Each has a level, 0–100.',
    ExerciseFamily.advanced => 'Each has its own level, like the basics.',
  };

  @override
  String playFamily(ExerciseFamily family) => 'Play ${this.family(family)}';

  @override
  final practice = 'Practice';

  @override
  final weakSpots = 'Weak spots';

  @override
  final weakSpotsCaption = 'What you missed, asked again.';

  @override
  String weakSpotsDue(int n) => n == 0 ? 'None due' : '$n due';

  @override
  final challenges = 'Challenges';

  @override
  final getTheCount = 'Get the count';

  @override
  final getTheCountCaption = 'Reach a target with the numbers given.';

  @override
  final chainOperations = 'Chain operations';

  @override
  final chainCaption = 'A running total, kept in your head.';

  @override
  final tables = 'Tables';

  @override
  final tablesCaption = 'Times tables, at your pace. Never ranked.';

  @override
  final tips = 'Tips';

  @override
  final tipsCaption = 'Shortcuts for every operation and level.';

  @override
  final firstRunTitle = 'How levels work';

  @override
  final firstRunLevels =
      'Each operation has a level, 0 to 100. A Levelling game moves it: '
      'right answers raise it, fast ones most; mistakes, timeouts and '
      'quitting lower it.';

  @override
  final firstRunPractice = 'Training games and Practice never move levels.';

  @override
  final couldNotStart = 'Could not start';

  // The game's setup page.
  @override
  final questions = 'Questions';

  @override
  String questionsCaption(int perOperation, int operations) => operations == 1
      ? '$perOperation questions.'
      : '$perOperation per operation: ${perOperation * operations} '
            'questions in all.';

  @override
  final mode = 'Mode';

  @override
  String modeLabel(GameMode mode) => switch (mode) {
    GameMode.training => 'Training',
    GameMode.levelling => 'Levelling',
  };

  @override
  String modeCaption(GameMode mode) => switch (mode) {
    GameMode.levelling =>
      'Moves your levels. Quitting counts the questions left as missed.',
    GameMode.training => 'A fixed difficulty. Your levels never move.',
  };

  @override
  String difficulty(TrainingDifficulty difficulty) => switch (difficulty) {
    TrainingDifficulty.easy => 'Easy',
    TrainingDifficulty.medium => 'Medium',
    TrainingDifficulty.hard => 'Hard',
  };

  @override
  final difficultyCaption = 'Easy: level 10 · Medium: 40 · Hard: 70.';

  // Chain operations.
  @override
  final seconds = 'Seconds';

  @override
  final operations = 'Operations';

  @override
  final chainRules = const [
    'A number, then one operation a screen. Keep the result in your head; '
        'type it at the end.',
    'Practice: it never moves your levels.',
  ];

  // Get the count.
  @override
  final countRules = const [
    'Reach the target with the numbers given and + − × ÷, each number once '
        'at most.',
    'The closer, the better; reaching it ends the round.',
    'Practice: it never moves your levels.',
  ];

  // Tables.
  @override
  final from = 'From';

  @override
  final to = 'To';

  @override
  final multipliers = 'Multipliers';

  @override
  String stepDown(String label) => '$label −1';

  @override
  String stepUp(String label) => '$label +1';

  @override
  String stepValue(String label, int value) => '$label $value';
}
