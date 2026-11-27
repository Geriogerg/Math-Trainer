import 'brand.dart';

/// Signing in, saving progress, the beta gate, a start that fails.
class AccountStrings {
  const AccountStrings();

  final appName = Brand.name;
  final email = 'Email';
  final password = 'Password';
  final showPassword = 'Show password';
  final hidePassword = 'Hide password';
  final playerName = 'Player name';
  final save = 'Save';
  final haveAccount = 'I already have an account';
  final privacyPolicy = 'Privacy policy';
  final legalNotice = 'Legal notice';

  // The minimum age (Phase 6c commit 2, plan v4.1; review B1).
  final ageBox = 'I am 15 or older';
  final ageMissing =
      'You must be 15 or older to save your progress: tick the box if you '
      'are.';

  // Sign in.
  final signIn = 'Sign in';
  final signInMissing = 'Enter your email and password.';
  final guestReplaced =
      'Your guest progress on this browser will be replaced by this account. '
      'It stays on this device but will no longer be shown, and the two '
      'histories are never merged. To keep it, go back and save your '
      'progress with a new email instead.';
  final signInReplacing = 'Sign in and replace guest progress';

  // Save your progress.
  final saveProgress = 'Save your progress';
  final saveProgressMissing = 'Enter an email, a password and a player name.';
  final saveProgressDetail =
      'Your levels and history stay as they are. With an email and a '
      'password you can play on another device, and your player name can '
      'appear on Ranks.';
  final signInInstead = 'Sign in to that account instead';

  // The beta gate.
  final gateDetail =
      'The beta is invite-only. Enter the code from your invitation.';
  final invitationCode = 'Invitation code';
  final checking = 'Checking…';
  final continueLabel = 'Continue';
  final codeEmpty = 'Enter the code from your invitation.';
  final codeInvalid =
      'This code is not valid. Check it against your invitation.';
  final codeFull = 'This code has already been used.';
  final codeDisabled = 'This code is no longer active.';
  final codeOffline = 'No connection. Check it and try again.';

  // The first start.
  final couldNotStart = "Couldn't start";
  final tryAgain = 'Try again';
  final startOffline =
      'No connection. ${Brand.name} needs the internet the first time it '
      'opens; after that it also plays offline.';
  final startRateLimited =
      'Too many new players from this network right now. Try again in a few '
      'minutes.';
  final startUnknown = 'The game could not start. Try again.';

  // Email confirmation (Phase 6c commit 3): the link waits in the inbox.
  final checkInbox = 'Check your inbox';
  String linkSent(String email) =>
      'A link was sent to $email. Open it to finish saving your progress. '
      'Until then you play as a guest: nothing is lost.';
  final sendAgain = 'Send the link again';
  final sentAgain = 'Sent again. It can take a minute to arrive.';
  final done = 'Done';

  /// Turnstile, before the first guest (Phase 6c commit 3).
  final startHumanCheck =
      'The check that you are not a robot did not finish. Try again.';

  // A start that failed before any screen (Phase 6b commit 5), and the
  // build errors meant for the developer.
  final startFailedTitle = 'The game could not start';
  final startFailedDetail =
      'Reload the page. If this happens again, try a little later.';
  String detail(Object error) => 'Detail: $error';
  final missingConfigTitle = 'Missing configuration';
  String missingConfig(List<String> keys) =>
      'This build was started without the Supabase configuration '
      '(${keys.join(', ')}).';
  final missingConfigFix =
      'Run it again with:\n'
      '--dart-define-from-file=dart_defines.json\n\n'
      'Template: dart_defines.example.json';
  final webStorageTitle = 'Web storage unavailable';
  final webStorageDetail =
      'The local database could not open in the browser: web/sqlite3.wasm or '
      'web/sqflite_sw.js is probably missing.';
  final webStorageFix =
      'Generate them once, from the project folder:\n'
      'dart run sqflite_common_ffi_web:setup';
}
