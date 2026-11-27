import 'brand.dart';

/// Signing in, saving progress, the beta gate, a start that fails.
abstract interface class AccountStrings {
  String get appName;
  String get email;
  String get password;
  String get showPassword;
  String get hidePassword;
  String get playerName;
  String get save;
  String get haveAccount;
  String get privacyPolicy;
  String get legalNotice;
  // The minimum age (Phase 6c commit 2, plan v4.1; review B1).
  String get ageBox;
  String get ageMissing;
  // Sign in.
  String get signIn;
  String get signInMissing;
  String get guestReplaced;
  String get signInReplacing;
  // Save your progress.
  String get saveProgress;
  String get saveProgressMissing;
  String get saveProgressDetail;
  String get signInInstead;
  // The beta gate.
  String get gateDetail;
  String get invitationCode;
  String get checking;
  String get continueLabel;
  String get codeEmpty;
  String get codeInvalid;
  String get codeFull;
  String get codeDisabled;
  String get codeOffline;
  // The first start.
  String get couldNotStart;
  String get tryAgain;
  String get startOffline;
  String get startRateLimited;
  String get startUnknown;
  // Forgot password (Phase 6c commit 4, review B3).
  String get forgotPassword;
  String get resetTitle;
  String get resetDetail;
  String get sendLink;
  String resetSent(String email);
  String get resetMissing;
  String get newPasswordTitle;
  String get newPasswordDetail;
  String get newPassword;
  String get newPasswordMissing;
  String get passwordChanged;
  String get emailConfirmed;
  String get linkFailed;
  // Email confirmation (Phase 6c commit 3): the link waits in the inbox.
  String get checkInbox;
  String linkSent(String email);
  String get sendAgain;
  String get sentAgain;
  String get done;

  /// Turnstile, before the first guest (Phase 6c commit 3).
  String get startHumanCheck;
  // A start that failed before any screen (Phase 6b commit 5), and the
  // build errors meant for the developer.
  String get startFailedTitle;
  String get startFailedDetail;
  String detail(Object error);
  String get missingConfigTitle;
  String missingConfig(List<String> keys);
  String get missingConfigFix;
  String get webStorageTitle;
  String get webStorageDetail;
  String get webStorageFix;
}

/// AccountStrings in English.
class EnglishAccountStrings implements AccountStrings {
  const EnglishAccountStrings();

  @override
  final appName = Brand.name;

  @override
  final email = 'Email';

  @override
  final password = 'Password';

  @override
  final showPassword = 'Show password';

  @override
  final hidePassword = 'Hide password';

  @override
  final playerName = 'Player name';

  @override
  final save = 'Save';

  @override
  final haveAccount = 'I already have an account';

  @override
  final privacyPolicy = 'Privacy policy';

  @override
  final legalNotice = 'Legal notice';

  // The minimum age (Phase 6c commit 2, plan v4.1; review B1).
  @override
  final ageBox = 'I am 15 or older';

  @override
  final ageMissing =
      'You must be 15 or older to save your progress: tick the box if you '
      'are.';

  // Sign in.
  @override
  final signIn = 'Sign in';

  @override
  final signInMissing = 'Enter your email and password.';

  @override
  final guestReplaced =
      'Your guest progress on this browser will be replaced by this account. '
      'It stays on this device but will no longer be shown, and the two '
      'histories are never merged. To keep it, go back and save your '
      'progress with a new email instead.';

  @override
  final signInReplacing = 'Sign in and replace guest progress';

  // Save your progress.
  @override
  final saveProgress = 'Save your progress';

  @override
  final saveProgressMissing = 'Enter an email, a password and a player name.';

  @override
  final saveProgressDetail =
      'Your levels and history stay as they are. With an email and a '
      'password you can play on another device, and your player name can '
      'appear on Ranks.';

  @override
  final signInInstead = 'Sign in to that account instead';

  // The beta gate.
  @override
  final gateDetail =
      'The beta is invite-only. Enter the code from your invitation.';

  @override
  final invitationCode = 'Invitation code';

  @override
  final checking = 'Checking…';

  @override
  final continueLabel = 'Continue';

  @override
  final codeEmpty = 'Enter the code from your invitation.';

  @override
  final codeInvalid =
      'This code is not valid. Check it against your invitation.';

  @override
  final codeFull = 'This code has already been used.';

  @override
  final codeDisabled = 'This code is no longer active.';

  @override
  final codeOffline = 'No connection. Check it and try again.';

  // The first start.
  @override
  final couldNotStart = "Couldn't start";

  @override
  final tryAgain = 'Try again';

  @override
  final startOffline =
      'No connection. ${Brand.name} needs the internet the first time it '
      'opens; after that it also plays offline.';

  @override
  final startRateLimited =
      'Too many new players from this network right now. Try again in a few '
      'minutes.';

  @override
  final startUnknown = 'The game could not start. Try again.';

  // Forgot password (Phase 6c commit 4, review B3).
  @override
  final forgotPassword = 'Forgot password?';

  @override
  final resetTitle = 'Reset your password';

  @override
  final resetDetail =
      'Enter the email of your account: a link to set a new password will be '
      'sent to it.';

  @override
  final sendLink = 'Send the link';

  @override
  String resetSent(String email) =>
      'If an account uses $email, a link is on its way. Open it on this '
      'device or another: it brings you back here to set a new password.';

  @override
  final resetMissing = 'Enter your email.';

  @override
  final newPasswordTitle = 'Set a new password';

  @override
  final newPasswordDetail =
      'You opened a password link: choose a new password for this account.';

  @override
  final newPassword = 'New password';

  @override
  final newPasswordMissing = 'Enter a new password.';

  @override
  final passwordChanged = 'Password changed.';

  @override
  final emailConfirmed = 'Email confirmed: your progress is saved.';

  @override
  final linkFailed =
      'That link has expired or was used already. Ask for a new one.';

  // Email confirmation (Phase 6c commit 3): the link waits in the inbox.
  @override
  final checkInbox = 'Check your inbox';

  @override
  String linkSent(String email) =>
      'A link was sent to $email. Open it to finish saving your progress. '
      'Until then you play as a guest: nothing is lost.';

  @override
  final sendAgain = 'Send the link again';

  @override
  final sentAgain = 'Sent again. It can take a minute to arrive.';

  @override
  final done = 'Done';

  @override
  final startHumanCheck =
      'The check that you are not a robot did not finish. Try again.';

  // A start that failed before any screen (Phase 6b commit 5), and the
  // build errors meant for the developer.
  @override
  final startFailedTitle = 'The game could not start';

  @override
  final startFailedDetail =
      'Reload the page. If this happens again, try a little later.';

  @override
  String detail(Object error) => 'Detail: $error';

  @override
  final missingConfigTitle = 'Missing configuration';

  @override
  String missingConfig(List<String> keys) =>
      'This build was started without the Supabase configuration '
      '(${keys.join(', ')}).';

  @override
  final missingConfigFix =
      'Run it again with:\n'
      '--dart-define-from-file=dart_defines.json\n\n'
      'Template: dart_defines.example.json';

  @override
  final webStorageTitle = 'Web storage unavailable';

  @override
  final webStorageDetail =
      'The local database could not open in the browser: web/sqlite3.wasm or '
      'web/sqflite_sw.js is probably missing.';

  @override
  final webStorageFix =
      'Generate them once, from the project folder:\n'
      'dart run sqflite_common_ffi_web:setup';
}
