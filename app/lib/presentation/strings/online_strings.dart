import 'package:math_core/duel/duel_mode.dart';
import 'package:math_core/friends/friends.dart';
import 'duel_texts.dart';

/// Online: duels, friends, the tab bar.
abstract interface class OnlineStrings {
  // The tab bar.
  String get tabPlay;
  String get tabOnline;
  String get tabProfile;
  String get tabRanks;
  String get onlineAttention;
  // The Online tab.
  String get online;

  /// Review m17: "not available in this build" was owner text.
  String get notAvailable;
  String get duels;
  String get waitingForYou;
  String get play;
  String get recent;
  String challengeFrom(String name, String mode);
  String practiceDuel(String mode);
  String racedYourRun(String name);
  String duelWith(String name, String mode);
  String get notCountedLower;
  String get waitingLower;
  String get needsAccount;
  String get saveYourProgress;
  String get couldNotLoad;
  // Rules (Phase 6b commit 4).
  String modeRule(DuelMode mode);
  String rulesTitle(String mode);
  List<String> rules(DuelMode mode);
  String get rated;
  String get leaving;
  // After a mode's first rated duel, a reminder instead (plan v4.1).
  String get ratedReminder;
  String get rulesLink;
  String get rulesLinkSpoken;
  String get allRulesTitle;
  List<String> get allRules;
  // Before and during a duel.
  String get saveToPlay;
  String get challengeExists;
  String get cannotBeChallenged;
  String get duelNotAvailable;
  String get appOutdated;
  String get quitDuelTitle;
  String get stillCounts;
  String get wakingServer;
  String get findingOpponent;
  String get wakeCaption;
  String get you;
  // A duel's result.
  String get notCounted;
  String get sent;
  String get sendAgain;
  String get rematch;
  String practiceSubtitle(String mode);
  // Friends.
  String get friends;
  String friendsPill(int requests);
  String requestOutcome(FriendRequestOutcome outcome);
  String get linkCopied;
  String get newCodeTitle;
  String get newCodeDetail;
  String get newCode;
  String get newCodeFailed;
  String get shareLink;
  String get addCode;
  String get add;
  String get yourCode;
  String get requests;
  String get decline;
  String get accept;
  String get noFriendsYet;
  String headToHead(String name, int wins, int losses);
  String get challenge;
  String get thisPlayer;
  String removeTitle(String name);
  String get remove;
  String get removeFriend;
  String get noDuelYet;
  String drawn(int draws);
  // An invite link (Phase 6a).
  String get inviteTitle;
  String inviteDetail(String code);
  String get notNow;
  String get sendRequest;
}

/// OnlineStrings in English.
class EnglishOnlineStrings implements OnlineStrings {
  const EnglishOnlineStrings();

  // The tab bar.
  @override
  final tabPlay = 'Play';

  @override
  final tabOnline = 'Online';

  @override
  final tabProfile = 'Profile';

  @override
  final tabRanks = 'Ranks';

  @override
  final onlineAttention = 'Online, something waits for you';

  // The Online tab.
  @override
  final online = 'Online';

  @override
  final notAvailable = 'Online play is not available yet.';

  @override
  final duels = 'Duels';

  @override
  final waitingForYou = 'Waiting for you';

  @override
  final play = 'Play';

  @override
  final recent = 'Recent';

  @override
  String challengeFrom(String name, String mode) => '$name · $mode';

  @override
  String practiceDuel(String mode) => 'Practice · $mode';

  @override
  String racedYourRun(String name) => '$name raced your run';

  @override
  String duelWith(String name, String mode) => '$name · $mode';

  @override
  final notCountedLower = 'not counted';

  @override
  final waitingLower = 'waiting';

  @override
  final needsAccount =
      'Duels need a saved account: save your progress — an email and a '
      'player name — to race other players.';

  @override
  final saveYourProgress = 'Save your progress';

  @override
  final couldNotLoad = 'Could not load your duels.';

  // Rules (Phase 6b commit 4).
  @override
  String modeRule(DuelMode mode) => switch (mode) {
    DuelMode.basics => '8 questions, 2 each of + − × ÷.',
    DuelMode.advanced => '8 questions, 2 each of x², √, % and ∫.',
    DuelMode.count => '3 rounds of 30 s: get closest to the target.',
  };

  @override
  String rulesTitle(String mode) => '$mode duel';

  @override
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
    rated,
    leaving,
  ];

  @override
  final rated =
      'Rated: both ratings move — unless no player is found and you race a '
      'practice opponent.';

  @override
  final leaving = 'Leaving counts as a loss.';

  // After a mode's first rated duel, a reminder instead (plan v4.1).
  @override
  final ratedReminder = 'Rated · leaving counts as a loss';

  @override
  final rulesLink = 'Rules';

  @override
  final rulesLinkSpoken = 'Duel rules';

  @override
  final allRulesTitle = 'Duel rules';

  @override
  List<String> get allRules => [
    for (final mode in DuelMode.values)
      '${duelModeLabel(mode)}: ${modeRule(mode)}',
    '30 s per question. More right answers wins; if tied, the faster. '
        'Get the count: closer to the targets wins.',
    rated,
    leaving,
  ];

  // Before and during a duel.
  @override
  final saveToPlay = 'Save your progress to play online.';

  @override
  final challengeExists = 'A challenge is already open.';

  @override
  final cannotBeChallenged = 'This player cannot be challenged.';

  @override
  final duelNotAvailable = 'This duel is not available.';

  @override
  final appOutdated =
      'A new version of the game is out. Reload the page to play duels — '
      'nothing was started.';

  @override
  final quitDuelTitle = 'Quit the duel?';

  @override
  final stillCounts = 'It still counts.';

  @override
  final wakingServer = 'Waking the server…';

  @override
  final findingOpponent = 'Finding an opponent…';

  @override
  final wakeCaption = 'It can take up to a minute.';

  @override
  final you = 'You';

  // A duel's result.
  @override
  final notCounted = 'Not counted';

  @override
  final sent = 'Sent';

  @override
  final sendAgain = 'Send again';

  @override
  final rematch = 'Rematch';

  @override
  String practiceSubtitle(String mode) => '$mode · Practice';

  // Friends.
  @override
  final friends = 'Friends';

  @override
  String friendsPill(int requests) => requests == 0
      ? 'Friends'
      : 'Friends, $requests request${requests == 1 ? '' : 's'}';

  @override
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

  @override
  final linkCopied = 'Link copied';

  @override
  final newCodeTitle = 'Get a new code?';

  @override
  final newCodeDetail =
      'Your current code and the links you shared stop working. Your friends '
      'stay.';

  @override
  final newCode = 'New code';

  @override
  final newCodeFailed = 'Could not get a new code — try again.';

  @override
  final shareLink = 'Share link';

  @override
  final addCode = 'Add code';

  @override
  final add = 'Add';

  @override
  final yourCode = 'Your code';

  @override
  final requests = 'Requests';

  @override
  final decline = 'Decline';

  @override
  final accept = 'Accept';

  @override
  final noFriendsYet = "Share your link or add a friend's code.";

  @override
  String headToHead(String name, int wins, int losses) =>
      '$name, $wins wins, $losses losses';

  @override
  final challenge = 'Challenge';

  @override
  final thisPlayer = 'this player';

  @override
  String removeTitle(String name) => 'Remove $name?';

  @override
  final remove = 'Remove';

  @override
  final removeFriend = 'Remove friend';

  @override
  final noDuelYet = 'No duel yet.';

  @override
  String drawn(int draws) => ' · $draws drawn';

  // An invite link (Phase 6a).
  @override
  final inviteTitle = 'Send a friend request?';

  @override
  String inviteDetail(String code) =>
      'An invite link asks to add the player with code $code.';

  @override
  final notNow = 'Not now';

  @override
  final sendRequest = 'Send request';
}
