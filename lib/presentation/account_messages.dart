import '../core/domain/account/account_exception.dart';

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
