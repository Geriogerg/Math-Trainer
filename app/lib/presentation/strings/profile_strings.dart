import 'package:math_core/challenges/challenge_stats.dart';

/// Profile, feedback, settings.
abstract interface class ProfileStrings {
  String get title;
  String get couldNotLoad;
  String get underReview;
  String get underReviewDetail;
  String get mainLevel;
  String change30Days(String? delta);
  String get last30Days;
  String get notEnoughData;
  String get byOperation;
  String get recentGames;
  String get otherDevices;
  String notSentYet(int games);
  String get noGameYet;
  String get placement;
  String score(int points);
  String get notPlayed;
  // The account block.
  String get playerName;
  String get playerNameUnavailable;
  String get choosePlayerName;
  String get reloadPlayerName;
  String get editPlayerName;
  String get guestLine;
  String get saveYourProgress;
  String get haveAccount;
  String get signOut;
  String get save;
  String get nameNotAllowed;
  String get nameTaken;
  String get nameNotSaved;
  String get progressSaved;
  String get progressSavedNameNot;
  String get confirmEmail;
  // Signing out (Phase 6b commit 4).
  String get signOutTitle;
  List<String> get signOutLines;
  // Deleting.
  String deleteTitle({required bool guest});
  String deleteDetail({required bool guest});
  String get delete;
  String deleted({required bool guest});
  String get deletedLocalKept;
  String nothingDeleted(String reason);
  String deleteButton({required bool guest});
  String get sendFeedback;
  String get privacyPolicy;
  String get legalNotice;
  // Challenges, Tables, weak spots.
  String get challenges;
  String challenge(Challenge challenge);
  String get games;
  String get solved;
  String get best;
  String get tables;
  String get right;
  String get slowest;
  String get weakSpots;
  String get noneYet;
  String missedOf(int misses, int answers);
  String get practice;
  // Settings.
  String get settings;
  String get darkMode;
  String get sound;
  String get vibration;
  // Feedback.
  String get feedbackTitle;
  String get feedbackSent;
  String get yourMessage;
  String get send;
  String get sending;
  String get feedbackOffline;
  String get feedbackTooMany;
  String get feedbackEmpty;
  String feedbackTooLong(int max);
}

/// ProfileStrings in English.
class EnglishProfileStrings implements ProfileStrings {
  const EnglishProfileStrings();

  @override
  final title = 'Profile';

  @override
  final couldNotLoad = 'Could not load the profile.';

  @override
  final underReview = 'Account under review';

  @override
  final underReviewDetail =
      'Your results are not shown on the boards until the review is done.';

  @override
  final mainLevel = 'Main level';

  @override
  String change30Days(String? delta) =>
      delta == null ? '30-day change: —' : '30-day change: $delta';

  @override
  final last30Days = 'Last 30 days';

  @override
  final notEnoughData = 'Not enough data for the last 30 days.';

  @override
  final byOperation = 'By operation';

  @override
  final recentGames = 'Recent games';

  @override
  final otherDevices = 'Games played on other devices are not shown here.';

  @override
  String notSentYet(int games) => games == 1
      ? '1 game not sent yet: it goes when the server answers.'
      : '$games games not sent yet: they go when the server answers.';

  @override
  final noGameYet = 'No game played yet.';

  @override
  final placement = 'Placement';

  @override
  String score(int points) => 'Score $points';

  @override
  final notPlayed = 'Not played';

  // The account block.
  @override
  final playerName = 'Player name';

  @override
  final playerNameUnavailable = 'Player name unavailable';

  @override
  final choosePlayerName = 'Choose a player name';

  @override
  final reloadPlayerName = 'Reload player name';

  @override
  final editPlayerName = 'Edit player name';

  @override
  final guestLine = 'Guest — progress saved on this device only';

  @override
  final saveYourProgress = 'Save your progress';

  @override
  final haveAccount = 'I already have an account';

  @override
  final signOut = 'Sign out';

  @override
  final save = 'Save';

  @override
  final nameNotAllowed = 'This name is not allowed.';

  @override
  final nameTaken = 'This name is taken — try another.';

  @override
  final nameNotSaved = 'Name not saved — check your connection and try again.';

  @override
  final progressSaved = 'Progress saved to your account.';

  @override
  final progressSavedNameNot =
      'Progress saved — the player name was not; set it again here.';

  @override
  final confirmEmail =
      'Almost there — open the link sent to your email to confirm.';

  // Signing out (Phase 6b commit 4).
  @override
  final signOutTitle = 'Sign out?';

  @override
  final signOutLines = const [
    'Your games and levels stay with your account: sign in again to find '
        'them.',
    'This device starts again as a new guest.',
  ];

  // Deleting.
  @override
  String deleteTitle({required bool guest}) =>
      guest ? 'Delete your data?' : 'Delete your account?';

  @override
  String deleteDetail({required bool guest}) => guest
      ? 'Your levels, your history and your guest account are deleted from '
            'this device and from the server. You start again as a new '
            'player. This cannot be undone.'
      : 'Your account, levels, history and player name are deleted from this '
            'device and from the server. This cannot be undone.';

  @override
  final delete = 'Delete';

  @override
  String deleted({required bool guest}) =>
      guest ? 'Your data was deleted.' : 'Your account was deleted.';

  @override
  final deletedLocalKept =
      'Deleted from the server; some data could not be removed from this '
      'device.';

  @override
  String nothingDeleted(String reason) => 'Nothing was deleted. $reason';

  @override
  String deleteButton({required bool guest}) =>
      guest ? 'Delete my data' : 'Delete my account';

  @override
  final sendFeedback = 'Send feedback';

  @override
  final privacyPolicy = 'Privacy policy';

  @override
  final legalNotice = 'Legal notice';

  // Challenges, Tables, weak spots.
  @override
  final challenges = 'Challenges';

  @override
  String challenge(Challenge challenge) => switch (challenge) {
    Challenge.getTheCount => 'Get the count',
    Challenge.chainOperations => 'Chain operations',
  };

  @override
  final games = 'Games';

  @override
  final solved = 'Solved';

  @override
  final best = 'Best';

  @override
  final tables = 'Tables';

  @override
  final right = 'Right';

  @override
  final slowest = 'Slowest';

  @override
  final weakSpots = 'Weak spots';

  @override
  final noneYet = 'None yet';

  @override
  String missedOf(int misses, int answers) => '$misses of $answers missed';

  @override
  final practice = 'Practice';

  // Settings.
  @override
  final settings = 'Settings';

  @override
  final darkMode = 'Dark mode';

  @override
  final sound = 'Sound';

  @override
  final vibration = 'Vibration';

  // Feedback.
  @override
  final feedbackTitle = 'Send feedback';

  @override
  final feedbackSent = 'Thank you — it was sent.';

  @override
  final yourMessage = 'Your message';

  @override
  final send = 'Send';

  @override
  final sending = 'Sending…';

  @override
  final feedbackOffline = 'Not sent: no connection. Try again.';

  @override
  final feedbackTooMany =
      'Not sent: that is a lot of messages for one day. Try again tomorrow.';

  @override
  final feedbackEmpty = 'Write something first.';

  @override
  String feedbackTooLong(int max) => 'Too long: $max characters at most.';
}
