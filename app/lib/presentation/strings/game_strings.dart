import 'package:math_core/leveling/level_updates.dart';

import 'package:math_core/tiers/tip_band.dart';

/// A game, its result, Get the count and Chain operations, the keypad,
/// the tips page.
class GameStrings {
  const GameStrings();

  // The game screen, and what a screen reader hears (Phase 6b commit 6).
  final right = 'Right';
  String wrongWithAnswer(String spoken, int answer) =>
      'Wrong. $spoken is $answer.';
  String timesUpWithAnswer(String spoken, int answer) =>
      "Time's up. $spoken is $answer.";
  final timesUp = "Time's up";
  String secondsLeft(int seconds) => '$seconds seconds left';
  String question(int index, int total, String spoken) =>
      'Question $index of $total: $spoken';
  String yourAnswer(int value) => 'Your answer $value';
  final timeLeft = 'Time left';
  String seconds(int n) => n == 1 ? '1 second' : '$n seconds';
  final noQuestion = 'No question to show.';

  /// A percentage prompt's word: "25% of 80" (the digit face draws it).
  final percentOf = 'of';

  /// An operation's button, as a screen reader names it.
  String operationLevel(String operation, int level) =>
      '$operation, level $level';
  final backspace = 'Backspace';
  final submit = 'Submit';

  // Leaving a game.
  final quitTitle = 'Quit the game?';
  final quitCounts =
      'The questions left count as missed: your levels can go '
      'down.';
  final couldNotRestart = 'Could not start a new game.';
  final notStarted = 'Game not started.';

  // The result.
  String title({required bool interrupted}) =>
      interrupted ? 'Game interrupted' : 'Game complete';
  final score = 'Score';
  String base(int points) => 'Base: $points';
  String speedBonus(int points) => 'Speed bonus: $points';
  String streakBonus(int points) => 'Streak bonus: $points';
  String difficultyBonus(int points) => 'Difficulty bonus: $points';
  final rightCount = 'Right';
  final wrongCount = 'Wrong';
  final timedOut = 'Timed out';
  final averageTime = 'Average time';

  /// A time in seconds, one decimal: "2.4 s" (review m17: "ms" here,
  /// seconds elsewhere).
  String secondsValue(num milliseconds) =>
      '${(milliseconds / 1000).toStringAsFixed(1)} s';
  final bestStreak = 'Best streak';
  final mistakes = 'Mistakes';
  final notSaved = 'Not saved';
  final retrySaving = 'Retry saving';
  final home = 'Home';
  final playAgain = 'Play again';
  final method = 'Method';
  final hideMethod = 'Hide method';
  final moreTips = 'More tips';
  final progressInLevel = 'Progress toward the next level';
  final levelUp = '▲ Level up';

  /// An operation's level when the game did not move it.
  String level(String operation, int whole) => '$operation — level $whole';
  String levelTooFewAnswers(String operation, int whole) =>
      '$operation — level $whole (not enough answers to count)';

  /// "Addition: 12 → 13 (+0.56)" (Phase 6b commit 4).
  String levelChange(String operation, int before, int after, int change) =>
      '$operation: $before → $after (${levelChangeText(change)})';

  /// A level change in levels, two decimals, signed: "+0.56", "−3.00"; "no
  /// change".
  String levelChangeText(int hundredths) {
    if (hundredths == 0) return 'no change';
    final sign = hundredths > 0 ? '+' : '−';
    final a = hundredths.abs();
    return '$sign${a ~/ 100}.${(a % 100).toString().padLeft(2, '0')}';
  }

  /// Why an operation's level moved, in one line: the game's quality
  /// against the band (`doc/levels.md` section 3), the questions left of a
  /// quit.
  String qualityReason(OperationQuality q, {required int change}) {
    final band = switch (q.zone) {
      QualityZone.up => 'above ${q.bandHighPercent} %, up',
      QualityZone.kept => '${q.bandLowPercent}–${q.bandHighPercent} %, kept',
      QualityZone.down => 'below ${q.bandLowPercent} %, down',
    };
    final bound = change == 0 && q.zone == QualityZone.down
        ? ' (already at 0)'
        : change == 0 && q.zone == QualityZone.up
        ? ' (already at 100)'
        : '';
    final left = q.unanswered == 0
        ? ''
        : ' · ${q.unanswered} left, counted as missed';
    return 'Quality ${q.qualityPercent} %: $band$bound$left';
  }

  // Get the count and Chain operations.
  final undo = 'Undo';
  final reset = 'Reset';
  final solved = 'Solved';
  final missed = 'Missed';
  final time = 'Time';
  final closest = 'Closest';

  // A level badge.
  String levelBadge(int level) => 'Level $level';
  final notPlayed = 'Not played';

  // Tips.
  String tipBand(TipBand band) => switch (band) {
    TipBand.beginner => 'Beginner',
    TipBand.intermediate => 'Intermediate',
    TipBand.advanced => 'Advanced',
  };
  final yourLevel = 'Your level';
  final drill = 'Drill';
  String drillLabel(String tip) => 'Drill: $tip';
}
