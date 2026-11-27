import 'package:math_core/leveling/level_updates.dart';

import 'package:math_core/tiers/tip_band.dart';

/// A game, its result, Get the count and Chain operations, the keypad,
/// the tips page.
abstract interface class GameStrings {
  // The game screen, and what a screen reader hears (Phase 6b commit 6).
  String get right;
  String wrongWithAnswer(String spoken, int answer);
  String timesUpWithAnswer(String spoken, int answer);
  String get timesUp;
  String secondsLeft(int seconds);
  String question(int index, int total, String spoken);
  String yourAnswer(int value);
  String get timeLeft;
  String seconds(int n);
  String get noQuestion;

  /// A percentage prompt's word: "25% of 80" (the digit face draws it).
  String get percentOf;

  /// A percentage as the language writes it: "37.5%" (Phase 6d: the
  /// decimal separator and the space before % follow the language).
  String percent(int whole, int tenths);

  /// An operation's button, as a screen reader names it.
  String operationLevel(String operation, int level);
  String get backspace;
  String get submit;
  // Leaving a game.
  String get quitTitle;
  String get quitCounts;
  String get couldNotRestart;
  String get notStarted;
  // The result.
  String title({required bool interrupted});
  String get score;
  String base(int points);
  String speedBonus(int points);
  String streakBonus(int points);
  String difficultyBonus(int points);
  String get rightCount;
  String get wrongCount;
  String get timedOut;
  String get averageTime;

  /// A time in seconds, one decimal: "2.4 s" (review m17: "ms" here,
  /// seconds elsewhere).
  String secondsValue(num milliseconds);
  String get bestStreak;
  String get mistakes;
  String get notSaved;
  String get retrySaving;
  String get home;
  String get playAgain;
  String get method;
  String get hideMethod;
  String get moreTips;
  String get progressInLevel;
  String get levelUp;

  /// An operation's level when the game did not move it.
  String level(String operation, int whole);
  String levelTooFewAnswers(String operation, int whole);

  /// "Addition: 12 → 13 (+0.56)" (Phase 6b commit 4).
  String levelChange(String operation, int before, int after, int change);

  /// A level change in levels, two decimals, signed: "+0.56", "−3.00"; "no
  /// change".
  String levelChangeText(int hundredths);

  /// Why an operation's level moved, in one line: what the game counted
  /// and where that put it against the band (`doc/levels.md` section 3),
  /// the questions left of a quit. Counts, never a percentage (plan v4.1,
  /// "Phase 6b outcome"): "8 right, 6 fast, of 10: up".
  String qualityReason(OperationQuality q, {required int change});
  // Get the count and Chain operations.
  String get undo;
  String get reset;
  String get solved;
  String get missed;
  String get time;
  String get closest;
  // A level badge.
  String levelBadge(int level);
  String get notPlayed;
  // Tips.
  String tipBand(TipBand band);
  String get yourLevel;
  String get drill;
  String drillLabel(String tip);
}

/// GameStrings in English.
class EnglishGameStrings implements GameStrings {
  const EnglishGameStrings();

  // The game screen, and what a screen reader hears (Phase 6b commit 6).
  @override
  final right = 'Right';

  @override
  String wrongWithAnswer(String spoken, int answer) =>
      'Wrong. $spoken is $answer.';

  @override
  String timesUpWithAnswer(String spoken, int answer) =>
      "Time's up. $spoken is $answer.";

  @override
  final timesUp = "Time's up";

  @override
  String secondsLeft(int seconds) => '$seconds seconds left';

  @override
  String question(int index, int total, String spoken) =>
      'Question $index of $total: $spoken';

  @override
  String yourAnswer(int value) => 'Your answer $value';

  @override
  final timeLeft = 'Time left';

  @override
  String seconds(int n) => n == 1 ? '1 second' : '$n seconds';

  @override
  final noQuestion = 'No question to show.';

  @override
  final percentOf = 'of';

  @override
  String percent(int whole, int tenths) =>
      '$whole${tenths == 0 ? '' : '.$tenths'}%';

  @override
  String operationLevel(String operation, int level) =>
      '$operation, level $level';

  @override
  final backspace = 'Backspace';

  @override
  final submit = 'Submit';

  // Leaving a game.
  @override
  final quitTitle = 'Quit the game?';

  @override
  final quitCounts =
      'The questions left count as missed: your levels can go '
      'down.';

  @override
  final couldNotRestart = 'Could not start a new game.';

  @override
  final notStarted = 'Game not started.';

  // The result.
  @override
  String title({required bool interrupted}) =>
      interrupted ? 'Game interrupted' : 'Game complete';

  @override
  final score = 'Score';

  @override
  String base(int points) => 'Base: $points';

  @override
  String speedBonus(int points) => 'Speed bonus: $points';

  @override
  String streakBonus(int points) => 'Streak bonus: $points';

  @override
  String difficultyBonus(int points) => 'Difficulty bonus: $points';

  @override
  final rightCount = 'Right';

  @override
  final wrongCount = 'Wrong';

  @override
  final timedOut = 'Timed out';

  @override
  final averageTime = 'Average time';

  @override
  String secondsValue(num milliseconds) =>
      '${(milliseconds / 1000).toStringAsFixed(1)} s';

  @override
  final bestStreak = 'Best streak';

  @override
  final mistakes = 'Mistakes';

  @override
  final notSaved = 'Not saved';

  @override
  final retrySaving = 'Retry saving';

  @override
  final home = 'Home';

  @override
  final playAgain = 'Play again';

  @override
  final method = 'Method';

  @override
  final hideMethod = 'Hide method';

  @override
  final moreTips = 'More tips';

  @override
  final progressInLevel = 'Progress toward the next level';

  @override
  final levelUp = '▲ Level up';

  @override
  String level(String operation, int whole) => '$operation — level $whole';

  @override
  String levelTooFewAnswers(String operation, int whole) =>
      '$operation — level $whole (not enough answers to count)';

  @override
  String levelChange(String operation, int before, int after, int change) =>
      '$operation: $before → $after (${levelChangeText(change)})';

  @override
  String levelChangeText(int hundredths) {
    if (hundredths == 0) return 'no change';
    final sign = hundredths > 0 ? '+' : '−';
    final a = hundredths.abs();
    return '$sign${a ~/ 100}.${(a % 100).toString().padLeft(2, '0')}';
  }

  @override
  String qualityReason(OperationQuality q, {required int change}) {
    final zone = switch (q.zone) {
      QualityZone.up => 'up',
      QualityZone.kept => 'kept',
      QualityZone.down => 'down',
    };
    final bound = change == 0 && q.zone == QualityZone.down
        ? ' (already at 0)'
        : change == 0 && q.zone == QualityZone.up
        ? ' (already at 100)'
        : '';
    final left = q.unanswered == 0
        ? ''
        : ' · ${q.unanswered} left, counted as missed';
    return '${q.right} right, ${q.fast} fast, of ${q.questions}: '
        '$zone$bound$left';
  }

  // Get the count and Chain operations.
  @override
  final undo = 'Undo';

  @override
  final reset = 'Reset';

  @override
  final solved = 'Solved';

  @override
  final missed = 'Missed';

  @override
  final time = 'Time';

  @override
  final closest = 'Closest';

  // A level badge.
  @override
  String levelBadge(int level) => 'Level $level';

  @override
  final notPlayed = 'Not played';

  // Tips.
  @override
  String tipBand(TipBand band) => switch (band) {
    TipBand.beginner => 'Beginner',
    TipBand.intermediate => 'Intermediate',
    TipBand.advanced => 'Advanced',
  };

  @override
  final yourLevel = 'Your level';

  @override
  final drill = 'Drill';

  @override
  String drillLabel(String tip) => 'Drill: $tip';
}
