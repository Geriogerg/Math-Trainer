import 'package:math_core/models/input_device.dart';

import 'effect_settings.dart';
import 'game_haptics.dart';
import 'game_sound.dart';
import 'session_effects.dart';

/// The session's effects as the app plays them, each behind the player's
/// switch: sound, then vibration. Still fire and forget
/// (`SessionEffects`).
///
/// A key ticks and vibrates for the on-screen keypad only: on a physical
/// keyboard the player already hears and feels their own keys.
class AppSessionEffects implements SessionEffects {
  AppSessionEffects({
    required this.sound,
    required this.haptics,
    required this.settings,
  });

  final GameSound sound;
  final GameHaptics haptics;
  final EffectSettings settings;

  @override
  void keyPressed(InputDevice device) {
    if (device != InputDevice.keypad) return;
    if (settings.sound) sound.keyTick();
    if (settings.haptics) haptics.key();
  }

  @override
  void answered({required bool correct, required int streak}) {
    if (correct) {
      if (settings.sound) sound.correct(streak);
      if (settings.haptics) haptics.success();
    } else {
      if (settings.sound) sound.wrong();
      if (settings.haptics) haptics.warning();
    }
  }

  @override
  void timedOut() {
    if (settings.sound) sound.wrong();
    if (settings.haptics) haptics.warning();
  }

  @override
  void levelUp() {
    if (settings.sound) sound.levelUp();
    if (settings.haptics) haptics.success();
  }
}
