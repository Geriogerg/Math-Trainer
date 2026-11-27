import 'package:math_core/leaderboard/leaderboard.dart';

/// Ranks: the boards (review m17: "Leaderboard" here, "Ranks" on the tab —
/// one name now).
abstract interface class RanksStrings {
  String get title;
  String get notAvailable;
  String get aroundMe;
  String get top100;
  String get couldNotLoad;
  String get emptyBoard;
  String get mainBoard;
  String topPercent(int percent);
  String rankOf(int rank, int total, String standing);
  String levelStanding(int whole);
  String ratingStanding(String rating);
  String you(String name);
  String get reportName;
  String reportTitle(String name);
  String get reportDetail;
  String get report;
  String get reported;
  String get reportFailed;
  String get reportNeedsAccount;
  String get progressSaved;
  String get saveYourProgress;

  /// Why the player is not on [board] yet; [needed] games or duels to go,
  /// [boardName] the board's label.
  String notRanked(
    NotRankedReason reason, {
    required int needed,
    required bool mainBoard,
    required bool duelBoard,
    required String boardName,
  });
}

/// RanksStrings in English.
class EnglishRanksStrings implements RanksStrings {
  const EnglishRanksStrings();

  @override
  final title = 'Ranks';

  @override
  final notAvailable = 'Ranks are not available yet.';

  @override
  final aroundMe = 'Around me';

  @override
  final top100 = 'Top 100';

  @override
  final couldNotLoad = 'Could not load the boards.';

  @override
  final emptyBoard = 'Nobody on this board yet.';

  @override
  final mainBoard = 'Main';

  @override
  String topPercent(int percent) => 'Top $percent %';

  @override
  String rankOf(int rank, int total, String standing) =>
      'Rank $rank of $total · $standing';

  @override
  String levelStanding(int whole) => 'level $whole';

  @override
  String ratingStanding(String rating) => 'rating $rating';

  @override
  String you(String name) => '$name (You)';

  @override
  final reportName = 'Report name';

  @override
  String reportTitle(String name) => 'Report "$name"?';

  @override
  final reportDetail =
      'Report a name that is offensive or impersonates someone. A reported '
      'name is hidden until it is reviewed.';

  @override
  final report = 'Report';

  @override
  final reported = 'Reported — thank you.';

  @override
  final reportFailed = 'Could not send the report.';

  @override
  final reportNeedsAccount = 'Save your progress to report a name.';

  @override
  final progressSaved = 'Progress saved to your account.';

  @override
  final saveYourProgress = 'Save your progress';

  @override
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
