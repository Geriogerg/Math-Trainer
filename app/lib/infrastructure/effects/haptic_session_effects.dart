import 'package:flutter/services.dart';

import '../../core/effects/session_effects.dart';

/// The session's haptics as they were before Phase 5: a light tap on every
/// answer, a heavy one added on a wrong answer or a timeout. Flutter's
/// `HapticFeedback` works on Android and iOS, and on the web calls the
/// browser's vibration API (Chrome on Android; nothing in Safari on iPhone).
class HapticSessionEffects implements SessionEffects {
  const HapticSessionEffects();

  @override
  void keyPressed() {}

  @override
  void answered({required bool correct, required int streak}) {
    HapticFeedback.lightImpact();
    if (!correct) HapticFeedback.heavyImpact();
  }

  @override
  void timedOut() {
    HapticFeedback.lightImpact();
    HapticFeedback.heavyImpact();
  }
}
