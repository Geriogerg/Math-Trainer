/// What an email's link brought the player back with (Phase 6c commits 3
/// and 4): read from the page's address before Supabase's client consumes
/// it, so the app knows why the session changed.
enum AuthLink {
  /// "Forgot password?": signed in to set a new password.
  recovery,

  /// An address confirmed (sign-up or the email a guest linked).
  confirmed,

  /// A link that expired or was used already: nothing happened.
  failed,
}

/// The [AuthLink] in [address] (its fragment with Supabase's implicit
/// flow, or its query), `null` when it holds none.
AuthLink? authLinkFrom(Uri address) {
  final parts = <String, String>{};
  for (final source in [address.query, address.fragment]) {
    if (source.isEmpty) continue;
    try {
      parts.addAll(Uri.splitQueryString(source));
    } on FormatException catch (_) {
      // Not a query: no link.
    }
  }
  if (parts.containsKey('error_description') || parts.containsKey('error')) {
    return AuthLink.failed;
  }
  if (!parts.containsKey('access_token')) return null;
  return switch (parts['type']) {
    'recovery' => AuthLink.recovery,
    'signup' || 'email_change' || 'email' => AuthLink.confirmed,
    _ => null,
  };
}
