import 'package:flutter/foundation.dart';

/// Where the player's effect switches are kept (`SharedPreferences` in
/// the app).
abstract interface class EffectSettingsStore {
  /// `null`: never set — the default applies (on).
  Future<bool?> readSound();
  Future<void> writeSound(bool on);
}

/// The Profile's switches for the game's effects (Phase 5): sound **on by
/// default** (`doc/plan.md` section 8, owner confirms), remembered.
/// Read at each effect, so a change applies to the next key.
class EffectSettings extends ChangeNotifier {
  EffectSettings({required this._store, this._sound = true});

  /// Reads the stored switches; a failed read keeps the defaults.
  static Future<EffectSettings> load(EffectSettingsStore store) async {
    bool? sound;
    try {
      sound = await store.readSound();
    } on Exception catch (_) {
      // Defaults: a settings read must never stop the app.
    }
    return EffectSettings(store: store, sound: sound ?? true);
  }

  final EffectSettingsStore _store;
  bool _sound;

  bool get sound => _sound;

  /// Applies at once; the write runs behind (a failed write only loses the
  /// choice at the next launch).
  void setSound(bool on) {
    if (on == _sound) return;
    _sound = on;
    notifyListeners();
    _store.writeSound(on).catchError((Object _) {});
  }
}
