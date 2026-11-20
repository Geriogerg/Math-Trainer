import 'package:flutter/services.dart';

import '../../core/effects/game_haptics.dart';

/// Haptics outside the browser (Android and iOS, Phase 8): Flutter's own
/// `HapticFeedback`, which both platforms implement.
GameHaptics createGameHaptics() => const _PlatformHaptics();

class _PlatformHaptics implements GameHaptics {
  const _PlatformHaptics();

  @override
  bool get supported => true;

  @override
  void key() => HapticFeedback.selectionClick();

  @override
  void success() => HapticFeedback.lightImpact();

  @override
  void warning() => HapticFeedback.heavyImpact();
}
