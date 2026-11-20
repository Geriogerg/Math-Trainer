import 'dart:js_interop';
// `has`: feature detection without calling the API.
import 'dart:js_interop_unsafe';

import '../../core/effects/game_haptics.dart';

/// Haptics in the browser: `navigator.vibrate` (Phase 5 commit 5). Chrome
/// on Android has it; Safari on iPhone does not — then [supported] is
/// false and every call does nothing.
GameHaptics createGameHaptics() => _WebVibrationHaptics();

class _WebVibrationHaptics implements GameHaptics {
  @override
  late final bool supported = _detect();

  static bool _detect() {
    try {
      return _navigator.has('vibrate');
    } catch (_) {
      return false;
    }
  }

  void _vibrate(JSAny pattern) {
    if (!supported) return;
    try {
      _navigator.vibrate(pattern);
    } catch (_) {
      // Refused (no user gesture yet, a policy): nothing to do.
    }
  }

  /// A tap you feel, not hear: 8 ms.
  @override
  void key() => _vibrate(8.toJS);

  /// One short pulse.
  @override
  void success() => _vibrate(15.toJS);

  /// Two pulses: unmistakable from a success without looking.
  @override
  void warning() => _vibrate([30.toJS, 50.toJS, 30.toJS].toJS);
}

@JS('navigator')
external _Navigator get _navigator;

extension type _Navigator._(JSObject _) implements JSObject {
  external bool vibrate(JSAny pattern);
}
