import 'package:math_core/duel/duel_mode.dart';
import 'package:math_core/friends/friends.dart';

/// Online: duels, friends, the tab bar.
class OnlineStrings {
  const OnlineStrings();

  // The tab bar.
  final tabPlay = 'Play';
  final tabOnline = 'Online';
  final tabProfile = 'Profile';
  final tabRanks = 'Ranks';
  final onlineAttention = 'Online, something waits for you';

  // The Online tab.
  final online = 'Online';

  /// Review m17: "not available in this build" was owner text.
  final notAvailable = 'Online play is not available yet.';
  final duels = 'Duels';
  final waitingForYou = 'Waiting for you';
  final play = 'Play';
  final recent = 'Recent';
  String challengeFrom(String name, String mode) => '$name · $mode';
  String practiceDuel(String mode) => 'Practice · $mode';
  String racedYourRun(String name) => '$name raced your run';
  String duelWith(String name, String mode) => '$name · $mode';
  final notCountedLower = 'not counted';
  final waitingLower = 'waiting';
  final needsAccount =
      'Duels need a saved account: save your progress — an email and a '
      'player name — to race other players.';
  final saveYourProgress = 'Save your progress';
  final couldNotLoad = 'Could not load your duels.';

  // Rules (Phase 6b commit 4).
  String modeRule(DuelMode mode) => switch (mode) {
    DuelMode.basics => '8 questions, 2 each of + − × ÷.',
    DuelMode.advanced => '8 questions, 2 each of x², √, % and ∫.',
    DuelMode.count => '3 rounds of 30 s: get closest to the target.',
  };
  String rulesTitle(String mode) => '$mode duel';
  List<String> rules(DuelMode mode) => [
    switch (mode) {
      DuelMode.basics =>
        '8 questions, 2 each of + − × ÷, 30 s each. More right answers wins; '
            'if tied, the faster.',
      DuelMode.advanced =>
        '8 questions, 2 each of x², √, % and ∫, 30 s each. More right answers '
            'wins; if tied, the faster.',
      DuelMode.count =>
        '3 rounds of 30 s, the same numbers for both. Closer to the targets '
            'wins; if tied, the faster.',
    },
    'Rated: both ratings move — unless no player is found and you race a '
        'practice opponent.',
    'Leaving counts as a loss.',
  ];

  // Before and during a duel.
  final saveToPlay = 'Save your progress to play online.';
  final challengeExists = 'A challenge is already open.';
  final cannotBeChallenged = 'This player cannot be challenged.';
  final duelNotAvailable = 'This duel is not available.';
  final quitDuelTitle = 'Quit the duel?';
  final stillCounts = 'It still counts.';
  final wakingServer = 'Waking the server…';
  final findingOpponent = 'Finding an opponent…';
  final wakeCaption = 'It can take up to a minute.';
  final you = 'You';

  // A duel's result.
  final notCounted = 'Not counted';
  final sent = 'Sent';
  final sendAgain = 'Send again';
  final rematch = 'Rematch';
  String practiceSubtitle(String mode) => '$mode · Practice';

  // Friends.
  final friends = 'Friends';
  String friendsPill(int requests) => requests == 0
      ? 'Friends'
      : 'Friends, $requests request${requests == 1 ? '' : 's'}';
  String requestOutcome(FriendRequestOutcome outcome) => switch (outcome) {
    FriendRequestOutcome.sent => 'Request sent.',
    FriendRequestOutcome.friends => 'You are now friends.',
    FriendRequestOutcome.already => 'Already friends.',
    FriendRequestOutcome.pending => 'Request already sent.',
    FriendRequestOutcome.unknown => 'No player has this code.',
    FriendRequestOutcome.self => 'That is your own code.',
    FriendRequestOutcome.tooMany => 'Too many requests today.',
    FriendRequestOutcome.other => 'Could not send the request.',
  };
  final linkCopied = 'Link copied';
  final newCodeTitle = 'Get a new code?';
  final newCodeDetail =
      'Your current code and the links you shared stop working. Your friends '
      'stay.';
  final newCode = 'New code';
  final newCodeFailed = 'Could not get a new code — try again.';
  final shareLink = 'Share link';
  final addCode = 'Add code';
  final add = 'Add';
  final yourCode = 'Your code';
  final requests = 'Requests';
  final decline = 'Decline';
  final accept = 'Accept';
  final noFriendsYet = "Share your link or add a friend's code.";
  String headToHead(String name, int wins, int losses) =>
      '$name, $wins wins, $losses losses';
  final challenge = 'Challenge';
  final thisPlayer = 'this player';
  String removeTitle(String name) => 'Remove $name?';
  final remove = 'Remove';
  final removeFriend = 'Remove friend';
  final noDuelYet = 'No duel yet.';
  String drawn(int draws) => ' · $draws drawn';

  // An invite link (Phase 6a).
  final inviteTitle = 'Send a friend request?';
  String inviteDetail(String code) =>
      'An invite link asks to add the player with code $code.';
  final notNow = 'Not now';
  final sendRequest = 'Send request';
}
