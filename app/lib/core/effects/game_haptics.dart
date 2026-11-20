/// The game's vibrations (Phase 5 commit 5, `doc/plan.md`): light on a
/// key, a short "success" on a right answer, a "warning" on a wrong one or
/// a timeout. Fire and forget; never throws.
abstract interface class GameHaptics {
  /// Whether this device can vibrate at all (Chrome on Android: yes;
  /// Safari on iPhone: no). Profile disables its switch and says why.
  bool get supported;

  void key();
  void success();
  void warning();
}

/// No vibration: tests, and devices without it.
class NoGameHaptics implements GameHaptics {
  const NoGameHaptics();

  @override
  bool get supported => false;

  @override
  void key() {}

  @override
  void success() {}

  @override
  void warning() {}
}
