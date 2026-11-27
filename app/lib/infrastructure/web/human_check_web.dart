import 'dart:async';
import 'dart:js_interop';

import '../../core/security/human_check.dart';

@JS('mtHumanCheck')
external JSPromise<JSString?>? _mtHumanCheck(JSString siteKey);

/// Cloudflare Turnstile through the page (`window.mtHumanCheck` in
/// web/index.html loads its script on first use, shows the widget only if
/// it needs the player, and answers its token).
HumanCheck createHumanCheck(String siteKey) => _Turnstile(siteKey);

class _Turnstile implements HumanCheck {
  const _Turnstile(this.siteKey);

  final String siteKey;

  /// The page gives up itself after a minute; a little more here.
  static const limit = Duration(seconds: 70);

  @override
  bool get enabled => true;

  @override
  Future<String?> token() async {
    try {
      final promise = _mtHumanCheck(siteKey.toJS);
      if (promise == null) return null;
      final token = (await promise.toDart.timeout(limit))?.toDart;
      return token == null || token.isEmpty ? null : token;
    } catch (_) {
      return null;
    }
  }
}
