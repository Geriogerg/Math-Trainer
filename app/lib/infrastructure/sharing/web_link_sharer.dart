import 'dart:js_interop';
// `has`: feature detection without calling the API.
import 'dart:js_interop_unsafe';

import '../../core/sharing/link_sharer.dart';

/// The Web Share API (`navigator.share`): the phone's share sheet in Chrome
/// on Android and Safari on iPhone; absent on most desktop browsers — then
/// [share] answers `false` and the link is copied instead.
LinkSharer createLinkSharer() => const _WebLinkSharer();

class _WebLinkSharer implements LinkSharer {
  const _WebLinkSharer();

  @override
  Future<bool> share({required String title, required Uri link}) async {
    final _ShareData data = _ShareData(title: title, url: '$link');
    try {
      if (!_navigator.has('share')) return false;
      if (_navigator.has('canShare') && !_navigator.canShare(data)) {
        return false;
      }
      await _navigator.share(data).toDart;
      return true;
    } catch (error) {
      // The player closed the sheet (AbortError): shared enough, nothing
      // to copy. Anything else (no user gesture, a policy): copy instead.
      return '$error'.contains('AbortError');
    }
  }
}

@JS('navigator')
external _Navigator get _navigator;

extension type _Navigator._(JSObject _) implements JSObject {
  external JSPromise<JSAny?> share(_ShareData data);
  external bool canShare(_ShareData data);
}

extension type _ShareData._(JSObject _) implements JSObject {
  external factory _ShareData({String title, String url});
}
