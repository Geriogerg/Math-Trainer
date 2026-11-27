import 'package:math_core/challenges/challenge_stats.dart';

/// Profile, feedback, settings.
class ProfileStrings {
  const ProfileStrings();

  final title = 'Profile';
  final couldNotLoad = 'Could not load the profile.';
  final underReview = 'Account under review';
  final underReviewDetail =
      'Your results are not shown on the boards until the review is done.';
  final mainLevel = 'Main level';
  String change30Days(String? delta) =>
      delta == null ? '30-day change: —' : '30-day change: $delta';
  final last30Days = 'Last 30 days';
  final notEnoughData = 'Not enough data for the last 30 days.';
  final byOperation = 'By operation';
  final recentGames = 'Recent games';
  final otherDevices = 'Games played on other devices are not shown here.';
  String notSentYet(int games) => games == 1
      ? '1 game not sent yet: it goes when the server answers.'
      : '$games games not sent yet: they go when the server answers.';
  final noGameYet = 'No game played yet.';
  final placement = 'Placement';
  String score(int points) => 'Score $points';
  final notPlayed = 'Not played';

  // The account block.
  final playerName = 'Player name';
  final playerNameUnavailable = 'Player name unavailable';
  final choosePlayerName = 'Choose a player name';
  final reloadPlayerName = 'Reload player name';
  final editPlayerName = 'Edit player name';
  final guestLine = 'Guest — progress saved on this device only';
  final saveYourProgress = 'Save your progress';
  final haveAccount = 'I already have an account';
  final signOut = 'Sign out';
  final save = 'Save';
  final nameNotAllowed = 'This name is not allowed.';
  final nameTaken = 'This name is taken — try another.';
  final nameNotSaved = 'Name not saved — check your connection and try again.';
  final progressSaved = 'Progress saved to your account.';
  final progressSavedNameNot =
      'Progress saved — the player name was not; set it again here.';
  final confirmEmail =
      'Almost there — open the link sent to your email to confirm.';

  // Signing out (Phase 6b commit 4).
  final signOutTitle = 'Sign out?';
  final signOutLines = const [
    'Your games and levels stay with your account: sign in again to find '
        'them.',
    'This device starts again as a new guest.',
  ];

  // Deleting.
  String deleteTitle({required bool guest}) =>
      guest ? 'Delete your data?' : 'Delete your account?';
  String deleteDetail({required bool guest}) => guest
      ? 'Your levels, your history and your guest account are deleted from '
            'this device and from the server. You start again as a new '
            'player. This cannot be undone.'
      : 'Your account, levels, history and player name are deleted from this '
            'device and from the server. This cannot be undone.';
  final delete = 'Delete';
  String deleted({required bool guest}) =>
      guest ? 'Your data was deleted.' : 'Your account was deleted.';
  final deletedLocalKept =
      'Deleted from the server; some data could not be removed from this '
      'device.';
  String nothingDeleted(String reason) => 'Nothing was deleted. $reason';
  String deleteButton({required bool guest}) =>
      guest ? 'Delete my data' : 'Delete my account';
  final sendFeedback = 'Send feedback';
  final privacy = 'Privacy';

  // Challenges, Tables, weak spots.
  final challenges = 'Challenges';
  String challenge(Challenge challenge) => switch (challenge) {
    Challenge.getTheCount => 'Get the count',
    Challenge.chainOperations => 'Chain operations',
  };
  final games = 'Games';
  final solved = 'Solved';
  final best = 'Best';
  final tables = 'Tables';
  final right = 'Right';
  final slowest = 'Slowest';
  final weakSpots = 'Weak spots';
  final noneYet = 'None yet';
  String missedOf(int misses, int answers) => '$misses of $answers missed';
  final practice = 'Practice';

  // Settings.
  final settings = 'Settings';
  final darkMode = 'Dark mode';
  final sound = 'Sound';
  final vibration = 'Vibration';

  // Feedback.
  final feedbackTitle = 'Send feedback';
  final feedbackSent = 'Thank you — it was sent.';
  final yourMessage = 'Your message';
  final send = 'Send';
  final sending = 'Sending…';
  final feedbackOffline = 'Not sent: no connection. Try again.';
  final feedbackTooMany =
      'Not sent: that is a lot of messages for one day. Try again tomorrow.';
  final feedbackEmpty = 'Write something first.';
  String feedbackTooLong(int max) => 'Too long: $max characters at most.';
}
