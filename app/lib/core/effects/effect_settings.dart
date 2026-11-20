import 'package:flutter/foundation.dart';

/// Where the player's effect switches are kept (`SharedPreferences` in
/// the app).
abstract interface class EffectSettingsStore {
  /// `null`: never set — the default applies (on).
  Future<bool?> readSound();
  Future<void> writeSound(bool on);

  /// `null`: never set — the default applies (on).
  Future<bool?> readHaptics();
  Future<void> writeHaptics(bool on);
}

/// The Profile's switches for the game's effects (Phase 5): sound and
/// vibration, both **on by default** (`doc/plan.md`; sound is an owner
/// decision to confirm), remembered per device. Read at each effect, so a
/// change applies to the next key.
class EffectSettings extends ChangeNotifier {
  EffectSettings({
    required this._store,
    this._sound = true,
    this._haptics = true,
    this.hapticsSupported = true,
  });

  /// Reads the stored switches; a failed read keeps the defaults.
  static Future<EffectSettings> load(
    EffectSettingsStore store, {
    required bool hapticsSupported,
  }) async {
    bool? sound;
    bool? haptics;
    try {
      sound = await store.readSound();
      haptics = await store.readHaptics();
    } on Exception catch (_) {
      // Defaults: a settings read must never stop the app.
    }
    return EffectSettings(
      store: store,
      sound: sound ?? true,
      haptics: haptics ?? true,
      hapticsSupported: hapticsSupported,
    );
  }

  final EffectSettingsStore _store;
  bool _sound;
  bool _haptics;

  /// The device cannot vibrate (Safari on iPhone): Profile disables the
  /// switch and says why.
  final bool hapticsSupported;

  bool get sound => _sound;

  /// On, and possible on this device.
  bool get haptics => _haptics && hapticsSupported;

  /// The player's choice, whatever the device can do.
  bool get hapticsChosen => _haptics;

  /// Applies at once; the write runs behind (a failed write only loses the
  /// choice at the next launch).
  void setSound(bool on) {
    if (on == _sound) return;
    _sound = on;
    notifyListeners();
    _store.writeSound(on).catchError((Object _) {});
  }

  void setHaptics(bool on) {
    if (on == _haptics) return;
    _haptics = on;
    notifyListeners();
    _store.writeHaptics(on).catchError((Object _) {});
  }
}
