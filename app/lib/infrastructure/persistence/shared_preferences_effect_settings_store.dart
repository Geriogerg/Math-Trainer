import 'package:shared_preferences/shared_preferences.dart';

import '../../core/effects/effect_settings.dart';

/// The Profile's effect switches, in `SharedPreferences` (browser storage
/// on the web), per device.
class SharedPreferencesEffectSettingsStore implements EffectSettingsStore {
  const SharedPreferencesEffectSettingsStore();

  static const _soundKey = 'effects.sound';

  @override
  Future<bool?> readSound() async =>
      (await SharedPreferences.getInstance()).getBool(_soundKey);

  @override
  Future<void> writeSound(bool on) async =>
      (await SharedPreferences.getInstance()).setBool(_soundKey, on);
}
