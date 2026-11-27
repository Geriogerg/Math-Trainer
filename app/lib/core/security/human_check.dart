/// Proof that a person, not a script, is creating an account or signing in
/// (Phase 6c commit 3, plan v4.1; review B2): a Cloudflare Turnstile token
/// on the web when the build has a site key (`TURNSTILE_SITE_KEY`), given
/// with the request to Supabase, which checks it once its CAPTCHA
/// protection is on. Off (no key): no token is asked for.
abstract interface class HumanCheck {
  /// Whether this build asks for tokens at all.
  bool get enabled;

  /// A fresh, single-use token; `null` when the check could not finish
  /// (closed, failed, timed out).
  Future<String?> token();
}

/// No check: builds without a site key, tests, platforms without one yet.
class NoHumanCheck implements HumanCheck {
  const NoHumanCheck();

  @override
  bool get enabled => false;

  @override
  Future<String?> token() async => null;
}
