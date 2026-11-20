import 'dart:async';
import 'dart:js_interop';

@JS('mtBootAuth')
external JSPromise<JSString>? get _bootAuth;

/// Waits for `window.mtBootAuth` (web/index.html): the session refreshed or
/// the anonymous player created while the files downloaded, stored where
/// supabase_flutter reads it. Must finish before `Supabase.initialize`, or
/// the app would start a second sign-in of its own beside it.
///
/// Answers what the page did ('fresh', 'refreshed', 'signed up', 'gate',
/// 'failed', 'none'). Never throws and never waits more than [limit]: the
/// page's own requests give up after 15 s, and whatever it did not finish,
/// the app does as before.
Future<String> waitForBootSignIn({
  Duration limit = const Duration(seconds: 16),
}) async {
  try {
    final promise = _bootAuth;
    if (promise == null) return 'none';
    return (await promise.toDart.timeout(limit)).toDart;
  } catch (_) {
    return 'unavailable';
  }
}
