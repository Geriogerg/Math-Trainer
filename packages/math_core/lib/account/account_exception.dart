/// Why a sign-in/sign-up failed, independent of the backend: the
/// infrastructure maps its own error codes to these cases, and the
/// presentation picks the message shown — never the raw server text, written
/// for a developer.
enum AccountFailure {
  /// Unknown email or wrong password — deliberately indistinguishable on the
  /// server (do not reveal which emails have an account).
  invalidCredentials,

  /// Account created, but the email was never confirmed.
  emailNotConfirmed,

  emailAlreadyUsed,

  /// Password rejected by the project's policy (too short, too simple).
  weakPassword,

  /// Malformed email or missing required field.
  invalidInput,

  /// Too many attempts (or emails sent) in a short time.
  rateLimited,

  /// Server unreachable: no network, or server error (5xx).
  network,

  /// The check that a person, not a script, is there (Turnstile, Phase 6c
  /// commit 3) did not complete: closed, failed or timed out.
  humanCheck,

  /// Everything else — [AccountException.detail] then carries the raw
  /// message, the only clue available for diagnosis.
  unknown,
}

class AccountException implements Exception {
  const AccountException(this.failure, {this.detail});

  final AccountFailure failure;

  /// Original technical message, for diagnosis — not for regular
  /// display.
  final String? detail;

  @override
  String toString() => detail == null
      ? 'AccountException(${failure.name})'
      : 'AccountException(${failure.name}: $detail)';
}
