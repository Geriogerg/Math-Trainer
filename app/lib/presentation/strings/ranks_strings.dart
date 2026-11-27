import 'package:math_core/leaderboard/leaderboard.dart';

/// Ranks: the boards (review m17: "Leaderboard" here, "Ranks" on the tab —
/// one name now).
class RanksStrings {
  const RanksStrings();

  final title = 'Ranks';
  final notAvailable = 'Ranks are not available yet.';
  final aroundMe = 'Around me';
  final top100 = 'Top 100';
  final couldNotLoad = 'Could not load the boards.';
  final emptyBoard = 'Nobody on this board yet.';
  final mainBoard = 'Main';
  String topPercent(int percent) => 'Top $percent %';
  String rankOf(int rank, int total, String standing) =>
      'Rank $rank of $total · $standing';
  String levelStanding(int whole) => 'level $whole';
  String ratingStanding(String rating) => 'rating $rating';
  String you(String name) => '$name (You)';
  final reportName = 'Report name';
  String reportTitle(String name) => 'Report "$name"?';
  final reportDetail =
      'Report a name that is offensive or impersonates someone. A reported '
      'name is hidden until it is reviewed.';
  final report = 'Report';
  final reported = 'Reported — thank you.';
  final reportFailed = 'Could not send the report.';
  final reportNeedsAccount = 'Save your progress to report a name.';
  final progressSaved = 'Progress saved to your account.';
  final saveYourProgress = 'Save your progress';

  /// Why the player is not on [board] yet; [needed] games or duels to go,
  /// [boardName] the board's label.
  String notRanked(
    NotRankedReason reason, {
    required int needed,
    required bool mainBoard,
    required bool duelBoard,
    required String boardName,
  }) {
    final games = needed == 1 ? '1 more game' : '$needed more games';
    return switch (reason) {
      NotRankedReason.noSessions =>
        'Play a game to join the boards. Your games count once they reach '
            'the server.',
      NotRankedReason.notEnoughSessions =>
        mainBoard
            ? 'Finish $games to join the main board.'
            : '$games with ${boardName.toLowerCase()} to join this board.',
      NotRankedReason.inactive when duelBoard =>
        'Play a rated duel to appear again: the board shows players active '
            'in the last 30 days.',
      NotRankedReason.inactive =>
        'Play a game to appear again: the board shows players active in the '
            'last 30 days. Your level never drops while you are away.',
      NotRankedReason.noDuels => 'Play a duel in this mode to join its board.',
      NotRankedReason.provisional =>
        needed == 1
            ? '1 more rated duel to join this board.'
            : '$needed more rated duels to join this board.',
      NotRankedReason.notLinked =>
        'The boards show players who saved their progress. Save yours — an '
            'email and a player name — to take your place.',
      NotRankedReason.signedOut ||
      NotRankedReason.other => 'You are not on this board yet.',
    };
  }
}
