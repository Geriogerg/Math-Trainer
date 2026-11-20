import 'package:math_core/models/input_device.dart';

import 'effect_settings.dart';
import 'game_sound.dart';
import 'session_effects.dart';

/// The session's effects as the app plays them: sound when the player's
/// switch is on, then haptics. Still fire and forget (`SessionEffects`).
///
/// The key tick is for the on-screen keypad only: on a physical keyboard
/// the player already hears their own keys.
class AppSessionEffects implements SessionEffects {
  AppSessionEffects({
    required this.sound,
    required this.haptics,
    required this.settings,
  });

  final GameSound sound;
  final SessionEffects haptics;
  final EffectSettings settings;

  @override
  void keyPressed(InputDevice device) {
    if (settings.sound && device == InputDevice.keypad) sound.keyTick();
    haptics.keyPressed(device);
  }

  @override
  void answered({required bool correct, required int streak}) {
    if (settings.sound) {
      if (correct) {
        sound.correct(streak);
      } else {
        sound.wrong();
      }
    }
    haptics.answered(correct: correct, streak: streak);
  }

  @override
  void timedOut() {
    if (settings.sound) sound.wrong();
    haptics.timedOut();
  }
}
