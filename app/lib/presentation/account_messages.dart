import 'package:math_core/account/account_exception.dart';
import 'package:math_core/account/display_name.dart';

/// What the player reads for an account failure — never the raw server
/// text (written for a developer), except for an unlisted failure, where it
/// is the only clue available.
String describeAccountFailure(AccountFailure failure, {String? detail}) =>
    switch (failure) {
      AccountFailure.invalidCredentials => 'Incorrect email or password.',
      AccountFailure.emailNotConfirmed =>
        'Email not confirmed yet — open the link in the email, then try '
            'again.',
      AccountFailure.emailAlreadyUsed =>
        'An account already exists with this email.',
      AccountFailure.weakPassword =>
        // No length quoted: the minimum is set per Supabase project.
        'Password too weak — choose a longer one.',
      AccountFailure.invalidInput => 'Invalid email address.',
      AccountFailure.rateLimited =>
        'Too many attempts. Wait a few minutes before trying again.',
      AccountFailure.network =>
        'Server unreachable. Check your connection, then try again.',
      AccountFailure.unknown => 'Unexpected error: ${detail ?? '-'}',
    };

/// Why a player name cannot be saved, in the player's words (Phase 2
/// commit 9: names are public content).
String describeNameProblem(DisplayNameProblem problem) => switch (problem) {
  DisplayNameProblem.empty => 'Choose a player name.',
  DisplayNameProblem.tooLong =>
    'Player name: $maxDisplayNameLength characters at most.',
  DisplayNameProblem.spaces =>
    'No space at the start or the end, and one space between words.',
  DisplayNameProblem.charset =>
    "Use letters (Latin, Greek or Cyrillic), digits, spaces and . _ ' - only.",
  DisplayNameProblem.noLetter => 'Use at least one letter or digit.',
  DisplayNameProblem.blocked => 'Choose another name.',
};
